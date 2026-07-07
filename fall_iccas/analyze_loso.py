"""
Post-hoc LOSO analysis + precision-oriented improvement, reusing the saved
per-fold checkpoints from loso_eval.py (NO retraining).

For each fold it:
  1. Reconstructs the exact train/val/test split (same SEED logic as loso_eval).
  2. Loads experiments/.../loso/fold{N}_best.pth and runs inference on val+test.
  3. Breaks down Stage-1 false positives by ADL activity (which activities the
     model confuses with falls on unseen subjects).
  4. Tunes two FP-reduction levers on the VAL set only, then applies them to the
     held-out TEST subject and recomputes Fall F1:
        - prob threshold `thr`  (raise stage-1 decision threshold)
        - min run-length `r`    (a window counts as FALL only if it is part of
                                 >= r consecutive fall-windows within its trial;
                                 removes isolated single-window false alarms)

Usage:
  cd fall_iccas
  python analyze_loso.py \
      --data-dir  experiments/subject1_to_17/cv_dataset \
      --ckpt-dir  experiments/subject1_to_17/loso
"""

import os, argparse, json
import numpy as np
import pandas as pd
import torch
from sklearn.metrics import f1_score, confusion_matrix

# reuse the exact model + helpers + constants from the trainer
from loso_eval import (
    STGCN, FallDataset, evaluate, DEVICE, SEED, BATCH_SIZE,
)
from torch.utils.data import DataLoader
import torch.nn as nn

# UP-Fall activity names (1-11); 1-5 = FALL, 6-11 = ADL
ACT_NAMES = {
    1: "fall-forward-hands", 2: "fall-forward-knees", 3: "fall-backward",
    4: "fall-sideward", 5: "fall-sit-empty-chair",
    6: "walking", 7: "standing", 8: "sitting",
    9: "picking-object", 10: "jumping", 11: "laying",
}


def rebuild_split(subjects, test_subj):
    """Reproduce loso_eval.run_fold's train/val/test index split exactly."""
    te_mask = subjects == test_subj
    tr_pool_mask = ~te_mask
    pool_subjects = subjects[tr_pool_mask]
    pool_idx = np.where(tr_pool_mask)[0]
    tr_idx, val_idx = [], []
    for s in np.unique(pool_subjects):
        idx = pool_idx[pool_subjects == s]
        rng = np.random.default_rng(SEED)
        rng.shuffle(idx)
        n_val = max(1, int(len(idx) * 0.15))
        val_idx.extend(idx[:n_val])
        tr_idx.extend(idx[n_val:])
    return np.array(tr_idx), np.array(val_idx), np.where(te_mask)[0]


def probs_for(model, X, y):
    loader = DataLoader(FallDataset(X, y), BATCH_SIZE, shuffle=False)
    _, _, _, _, probs = evaluate(model, loader, nn.CrossEntropyLoss())
    return probs


def apply_levers(probs, meta_idx_df, thr, r):
    """
    Binary predictions after (thr, min-run-length r), applied per trial in
    temporal order.  meta_idx_df has columns subject/activity/trial/start_frame
    aligned row-for-row with `probs`.
    """
    pred = np.zeros(len(probs), dtype=int)
    raw = (probs >= thr).astype(int)
    df = meta_idx_df.reset_index(drop=True)
    for _, g in df.groupby(["subject", "activity", "trial"], sort=False):
        order = g.sort_values("start_frame").index.to_numpy()
        seq = raw[order]
        if r <= 1:
            pred[order] = seq
            continue
        # keep a fall-window only if inside a run of >= r consecutive ones
        out = np.zeros_like(seq)
        i = 0
        while i < len(seq):
            if seq[i] == 1:
                j = i
                while j < len(seq) and seq[j] == 1:
                    j += 1
                if (j - i) >= r:
                    out[i:j] = 1
                i = j
            else:
                i += 1
        pred[order] = out
    return pred


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", required=True)
    ap.add_argument("--ckpt-dir", required=True)
    args = ap.parse_args()

    X = np.load(os.path.join(args.data_dir, "X.npy"))
    y = np.load(os.path.join(args.data_dir, "y.npy"))
    meta = pd.read_csv(os.path.join(args.data_dir, "meta.csv"))
    subjects = meta["subject"].to_numpy()
    unique_subjects = np.unique(subjects)

    thr_grid = [0.50, 0.60, 0.70, 0.80, 0.90]
    r_grid = [1, 2, 3, 4, 5]

    # accumulate FP-by-activity and improved test predictions across folds
    fp_by_act = {a: 0 for a in ACT_NAMES}
    tot_by_act = {a: 0 for a in ACT_NAMES}
    base_rows, best_rows = [], []
    agg_true, agg_base, agg_best = [], [], []

    for fold_idx, test_subj in enumerate(unique_subjects, 1):
        ckpt = os.path.join(args.ckpt_dir, f"fold{fold_idx}_best.pth")
        if not os.path.exists(ckpt):
            print(f"[skip] fold {fold_idx}: {ckpt} not found")
            continue

        tr_idx, val_idx, te_idx = rebuild_split(subjects, test_subj)
        model = STGCN(in_channels=3, num_classes=2).to(DEVICE)
        model.load_state_dict(torch.load(ckpt, weights_only=True))
        model.eval()

        val_probs = probs_for(model, X[val_idx], y[val_idx])
        te_probs = probs_for(model, X[te_idx], y[te_idx])
        y_val, y_te = y[val_idx], y[te_idx]
        meta_val = meta.iloc[val_idx][["subject", "activity", "trial", "start_frame"]]
        meta_te = meta.iloc[te_idx][["subject", "activity", "trial", "start_frame"]]

        # baseline (thr=0.5, r=1)
        base_pred = (te_probs >= 0.5).astype(int)
        base_f1 = f1_score(y_te, base_pred, pos_label=1, zero_division=0)

        # per-activity FP breakdown at baseline
        te_acts = meta.iloc[te_idx]["activity"].to_numpy()
        for a in ACT_NAMES:
            m = te_acts == a
            tot_by_act[a] += int(m.sum())
            if a >= 6:  # ADL — any positive prediction here is a false positive
                fp_by_act[a] += int(base_pred[m].sum())

        # tune (thr, r) on VAL, apply to TEST
        best = (-1, 0.5, 1)
        for thr in thr_grid:
            for r in r_grid:
                vp = apply_levers(val_probs, meta_val, thr, r)
                vf1 = f1_score(y_val, vp, pos_label=1, zero_division=0)
                if vf1 > best[0]:
                    best = (vf1, thr, r)
        _, thr_star, r_star = best
        best_pred = apply_levers(te_probs, meta_te, thr_star, r_star)
        best_f1 = f1_score(y_te, best_pred, pos_label=1, zero_division=0)

        base_rows.append(base_f1)
        best_rows.append(best_f1)
        agg_true.extend(y_te); agg_base.extend(base_pred); agg_best.extend(best_pred)

        print(f"Fold {fold_idx:2d}  S{test_subj:<2}  "
              f"base F1={base_f1:.4f}   ->  (thr={thr_star:.2f}, r={r_star})  "
              f"F1={best_f1:.4f}   ({best_f1-base_f1:+.4f})")
        del model
        torch.cuda.empty_cache()

    print("\n" + "=" * 60)
    print("Stage-1 false positives by ADL activity (baseline thr=0.5):")
    for a in range(6, 12):
        n = tot_by_act[a]
        print(f"  A{a:<2} {ACT_NAMES[a]:<20} FP={fp_by_act[a]:5d} / {n:5d} windows "
              f"({100*fp_by_act[a]/max(n,1):.1f}%)")
    total_fp = sum(fp_by_act.values())
    print(f"  TOTAL ADL false positives: {total_fp}")

    print("\n" + "=" * 60)
    ct = confusion_matrix(agg_true, agg_base)
    cb = confusion_matrix(agg_true, agg_best)

    def prf(cm):
        tn, fp, fn, tp = cm.ravel()
        rec = tp / (tp + fn) if tp + fn else 0
        pre = tp / (tp + fp) if tp + fp else 0
        f1 = 2 * pre * rec / (pre + rec) if pre + rec else 0
        return rec, pre, f1, fp, fn

    rb, pb, fb, fpb, fnb = prf(ct)
    rk, pk, fk, fpk, fnk = prf(cb)
    print(f"Baseline   mean F1={np.mean(base_rows):.4f}   "
          f"agg: Recall={rb:.3f} Prec={pb:.3f} F1={fb:.3f}  FP={fpb} FN={fnb}")
    print(f"Improved   mean F1={np.mean(best_rows):.4f}   "
          f"agg: Recall={rk:.3f} Prec={pk:.3f} F1={fk:.3f}  FP={fpk} FN={fnk}")
    print(f"\nMean per-fold F1: {np.mean(base_rows):.4f} -> {np.mean(best_rows):.4f} "
          f"({np.mean(best_rows)-np.mean(base_rows):+.4f})")

    out = {
        "fp_by_activity": {ACT_NAMES[a]: fp_by_act[a] for a in range(6, 12)},
        "base_mean_f1": float(np.mean(base_rows)),
        "improved_mean_f1": float(np.mean(best_rows)),
        "base_per_fold": [float(v) for v in base_rows],
        "improved_per_fold": [float(v) for v in best_rows],
    }
    with open(os.path.join(args.ckpt_dir, "analyze_loso.json"), "w") as f:
        json.dump(out, f, indent=2)
    print(f"\nSaved: {os.path.join(args.ckpt_dir, 'analyze_loso.json')}")


if __name__ == "__main__":
    main()
