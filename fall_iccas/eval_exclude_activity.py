"""
Re-evaluate an existing LOSO run while EXCLUDING chosen ADL activities from the
test set (simulating a deployment-time safe-zone that suppresses those
activities spatially — e.g. A11 laying, handled by a bed/sofa safe zone).

Reuses the saved per-fold checkpoints (NO retraining). The model is still
trained on all activities; we only remove the excluded activities' windows from
the TEST evaluation, then recompute per-fold and aggregate Fall F1.

IMPORTANT (paper honesty): report this ALONGSIDE the full-protocol number, not
instead of it. Framing: "activities X are handled by the safe-zone module; the
pose detector is evaluated on the remaining activities."

Usage:
  cd fall_iccas
  python eval_exclude_activity.py \
      --data-dir experiments/subject1_to_17/cv_dataset \
      --ckpt-dir experiments/subject1_to_17/loso \
      --exclude 11
"""

import os, argparse, json
import numpy as np
import pandas as pd
import torch
from sklearn.metrics import f1_score, confusion_matrix

from loso_eval import STGCN, DEVICE
from analyze_loso import rebuild_split, probs_for


def prf(cm):
    tn, fp, fn, tp = cm.ravel()
    rec = tp / (tp + fn) if tp + fn else 0.0
    pre = tp / (tp + fp) if tp + fp else 0.0
    f1 = 2 * pre * rec / (pre + rec) if pre + rec else 0.0
    return rec, pre, f1, int(fp), int(fn)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", required=True)
    ap.add_argument("--ckpt-dir", required=True)
    ap.add_argument("--exclude", type=int, nargs="+", default=[11],
                    help="Activity IDs to exclude from the TEST set (default: 11).")
    args = ap.parse_args()

    X = np.load(os.path.join(args.data_dir, "X.npy"))
    y = np.load(os.path.join(args.data_dir, "y.npy"))
    meta = pd.read_csv(os.path.join(args.data_dir, "meta.csv"))
    subjects = meta["subject"].to_numpy()
    activity = meta["activity"].to_numpy()
    unique_subjects = np.unique(subjects)
    excl = set(args.exclude)

    full_f1s, kept_f1s = [], []
    agg_true_full, agg_pred_full = [], []
    agg_true_kept, agg_pred_kept = [], []

    print(f"Excluding activities {sorted(excl)} from TEST evaluation "
          f"(model unchanged; simulates safe-zone suppression).\n")
    print(f"  {'Fold':<5}{'Subj':<6}{'full F1':>9}{'kept F1':>9}")
    for fold_idx, test_subj in enumerate(unique_subjects, 1):
        ckpt = os.path.join(args.ckpt_dir, f"fold{fold_idx}_best.pth")
        if not os.path.exists(ckpt):
            continue
        _, _, te_idx = rebuild_split(subjects, test_subj)

        model = STGCN(in_channels=3, num_classes=2).to(DEVICE)
        model.load_state_dict(torch.load(ckpt, weights_only=True))
        model.eval()
        probs = probs_for(model, X[te_idx], y[te_idx])
        del model; torch.cuda.empty_cache()

        pred = (probs >= 0.5).astype(int)
        y_te = y[te_idx]
        act_te = activity[te_idx]
        keep = ~np.isin(act_te, list(excl))

        f1_full = f1_score(y_te, pred, pos_label=1, zero_division=0)
        f1_kept = f1_score(y_te[keep], pred[keep], pos_label=1, zero_division=0)
        full_f1s.append(f1_full); kept_f1s.append(f1_kept)
        agg_true_full.extend(y_te); agg_pred_full.extend(pred)
        agg_true_kept.extend(y_te[keep]); agg_pred_kept.extend(pred[keep])

        print(f"  {fold_idx:<5}S{test_subj:<5}{f1_full:>9.4f}{f1_kept:>9.4f}")

    rf, pf, ff, fpf, fnf = prf(confusion_matrix(agg_true_full, agg_pred_full))
    rk, pk, fk, fpk, fnk = prf(confusion_matrix(agg_true_kept, agg_pred_kept))
    print("\n" + "=" * 55)
    print(f"Full protocol (all activities):")
    print(f"  mean F1={np.mean(full_f1s):.4f}   "
          f"agg Recall={rf:.3f} Prec={pf:.3f} F1={ff:.3f}  FP={fpf} FN={fnf}")
    print(f"Safe-zone (excluding A{sorted(excl)} at test):")
    print(f"  mean F1={np.mean(kept_f1s):.4f}   "
          f"agg Recall={rk:.3f} Prec={pk:.3f} F1={fk:.3f}  FP={fpk} FN={fnk}")
    print(f"\nMean per-fold F1: {np.mean(full_f1s):.4f} -> {np.mean(kept_f1s):.4f} "
          f"({np.mean(kept_f1s)-np.mean(full_f1s):+.4f})")

    out = {
        "excluded": sorted(excl),
        "full_mean_f1": float(np.mean(full_f1s)),
        "kept_mean_f1": float(np.mean(kept_f1s)),
        "full_agg": {"recall": rf, "precision": pf, "f1": ff, "fp": fpf, "fn": fnf},
        "kept_agg": {"recall": rk, "precision": pk, "f1": fk, "fp": fpk, "fn": fnk},
    }
    with open(os.path.join(args.ckpt_dir, "eval_exclude_activity.json"), "w") as f:
        json.dump(out, f, indent=2)
    print(f"\nSaved: {os.path.join(args.ckpt_dir, 'eval_exclude_activity.json')}")


if __name__ == "__main__":
    main()
