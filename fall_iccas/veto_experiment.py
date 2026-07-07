"""
Velocity-veto experiment targeting the Activity-11 (laying) false positives that
dominate LOSO precision (96% of all FP; see RESULTS.md Run 12).

Hypothesis: a real fall has a high peak downward hip velocity, while lying down
is slow. So vetoing a Stage-1 fall prediction whose peak velocity is below a
threshold should remove A11 false alarms while keeping true falls.

Reuses the saved per-fold checkpoints (NO retraining).

Step 1 (diagnostic): compare peak-velocity distributions of true falls vs A11
        windows the model predicts as fall. If they separate, the veto can work.
Step 2 (experiment): per fold, tune the veto threshold on VAL only
        (final = stage1_fall AND peak_vel >= v_thr), apply to held-out TEST,
        recompute Fall F1. Honest: test subject never seen during tuning.

Usage:
  cd fall_iccas
  python veto_experiment.py \
      --data-dir experiments/subject1_to_17/cv_dataset \
      --ckpt-dir experiments/subject1_to_17/loso
"""

import os, argparse, json
import numpy as np
import pandas as pd
import torch
from sklearn.metrics import f1_score, confusion_matrix

from stgcn import PhysicsFilter
from loso_eval import STGCN, FallDataset, evaluate, DEVICE, SEED, BATCH_SIZE
from analyze_loso import rebuild_split, probs_for


def precompute_features(X):
    """Peak velocity / acceleration / hip-drop for every window, once."""
    pf = PhysicsFilter(fps=19.0)
    n = len(X)
    vel = np.zeros(n); acc = np.zeros(n); drop = np.zeros(n)
    for i in range(n):
        f = pf.extract_features(X[i])
        vel[i] = f["max_velocity"]; acc[i] = f["max_abs_acc"]; drop[i] = f["hip_drop"]
        if i % 3000 == 0:
            print(f"  features {i}/{n}")
    return vel, acc, drop


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
    args = ap.parse_args()

    X = np.load(os.path.join(args.data_dir, "X.npy"))
    y = np.load(os.path.join(args.data_dir, "y.npy"))
    meta = pd.read_csv(os.path.join(args.data_dir, "meta.csv"))
    subjects = meta["subject"].to_numpy()
    activity = meta["activity"].to_numpy()
    unique_subjects = np.unique(subjects)

    print("Precomputing physics features for all windows ...")
    vel, acc, drop = precompute_features(X)

    # ── Step 1: diagnostic — can velocity separate falls from A11? ──────────────
    fall_vel = vel[y == 1]
    a11_vel = vel[activity == 11]
    pct = [10, 25, 50, 75, 90]
    print("\n" + "=" * 60)
    print("Peak-velocity distribution (normalized units/s):")
    print(f"  {'pctile':>8}", *[f"{p:>7}%" for p in pct])
    print(f"  {'TRUE FALL':>8}", *[f"{np.percentile(fall_vel,p):7.3f}" for p in pct])
    print(f"  {'A11 LAYING':>8}", *[f"{np.percentile(a11_vel,p):7.3f}" for p in pct])
    print("  (if TRUE FALL sits well above A11 LAYING, the veto can work)")

    # ── Step 2: per-fold veto tuned on val, applied to test ─────────────────────
    base_f1s, veto_f1s = [], []
    agg_true, agg_base, agg_veto = [], [], []
    a11_fp_removed, falls_lost = 0, 0

    print("\n" + "=" * 60)
    for fold_idx, test_subj in enumerate(unique_subjects, 1):
        ckpt = os.path.join(args.ckpt_dir, f"fold{fold_idx}_best.pth")
        if not os.path.exists(ckpt):
            continue
        _, val_idx, te_idx = rebuild_split(subjects, test_subj)

        model = STGCN(in_channels=3, num_classes=2).to(DEVICE)
        model.load_state_dict(torch.load(ckpt, weights_only=True))
        model.eval()

        val_probs = probs_for(model, X[val_idx], y[val_idx])
        te_probs = probs_for(model, X[te_idx], y[te_idx])
        del model; torch.cuda.empty_cache()

        val_s1 = (val_probs >= 0.5).astype(int)
        te_s1 = (te_probs >= 0.5).astype(int)
        y_val, y_te = y[val_idx], y[te_idx]

        # tune veto threshold on VAL: candidates from val-fall velocity percentiles
        vf = vel[val_idx]
        cand = np.percentile(vel[val_idx][y_val == 1], np.arange(0, 95, 5))
        best = (-1, 0.0)
        for vt in cand:
            pred = np.where(val_s1 == 1, (vf >= vt).astype(int), 0)
            f1 = f1_score(y_val, pred, pos_label=1, zero_division=0)
            if f1 > best[0]:
                best = (f1, vt)
        v_thr = best[1]

        te_veto = np.where(te_s1 == 1, (vel[te_idx] >= v_thr).astype(int), 0)
        base_f1 = f1_score(y_te, te_s1, pos_label=1, zero_division=0)
        veto_f1 = f1_score(y_te, te_veto, pos_label=1, zero_division=0)
        base_f1s.append(base_f1); veto_f1s.append(veto_f1)
        agg_true.extend(y_te); agg_base.extend(te_s1); agg_veto.extend(te_veto)

        # how many A11 FP removed / true falls lost by the veto
        act_te = activity[te_idx]
        a11_mask = act_te == 11
        a11_fp_removed += int(((te_s1 == 1) & (te_veto == 0) & a11_mask).sum())
        falls_lost += int(((te_s1 == 1) & (te_veto == 0) & (y_te == 1)).sum())

        print(f"Fold {fold_idx:2d}  S{test_subj:<2}  base F1={base_f1:.4f}  "
              f"-> veto(v>={v_thr:.3f}) F1={veto_f1:.4f}  ({veto_f1-base_f1:+.4f})")

    print("\n" + "=" * 60)
    rb, pb, fb, fpb, fnb = prf(confusion_matrix(agg_true, agg_base))
    rv, pv, fv, fpv, fnv = prf(confusion_matrix(agg_true, agg_veto))
    print(f"Baseline  mean F1={np.mean(base_f1s):.4f}   "
          f"agg Recall={rb:.3f} Prec={pb:.3f} F1={fb:.3f}  FP={fpb} FN={fnb}")
    print(f"Veto      mean F1={np.mean(veto_f1s):.4f}   "
          f"agg Recall={rv:.3f} Prec={pv:.3f} F1={fv:.3f}  FP={fpv} FN={fnv}")
    print(f"\nA11 false positives removed: {a11_fp_removed}")
    print(f"True falls lost to veto     : {falls_lost}")
    print(f"Mean per-fold F1: {np.mean(base_f1s):.4f} -> {np.mean(veto_f1s):.4f} "
          f"({np.mean(veto_f1s)-np.mean(base_f1s):+.4f})")

    out = {
        "base_mean_f1": float(np.mean(base_f1s)),
        "veto_mean_f1": float(np.mean(veto_f1s)),
        "a11_fp_removed": a11_fp_removed,
        "falls_lost": falls_lost,
        "agg_veto": {"recall": rv, "precision": pv, "f1": fv, "fp": fpv, "fn": fnv},
        "base_per_fold": [float(v) for v in base_f1s],
        "veto_per_fold": [float(v) for v in veto_f1s],
    }
    with open(os.path.join(args.ckpt_dir, "veto_experiment.json"), "w") as f:
        json.dump(out, f, indent=2)
    print(f"\nSaved: {os.path.join(args.ckpt_dir, 'veto_experiment.json')}")


if __name__ == "__main__":
    main()
