"""
Can ANY single kinematic feature separate true falls from Activity-11 (laying)?

Velocity failed (veto_experiment.py). This checks velocity, acceleration and
hip-drop with an oracle threshold: the BEST possible fall-vs-A11 separation each
feature could give (upper bound, tuned directly on the data). If even the oracle
is weak, no kinematic veto can fix the A11 confusion and we need the lateral
camera (Camera2).

Usage:
  cd fall_iccas
  python feature_separability.py --data-dir experiments/subject1_to_17/cv_dataset
"""

import os, argparse
import numpy as np
import pandas as pd
from sklearn.metrics import roc_auc_score
from veto_experiment import precompute_features


def oracle_split(feat, is_fall):
    """Best accuracy separating fall(1) vs A11(0) by a single threshold, plus AUC."""
    order = np.argsort(feat)
    f = feat[order]; lab = is_fall[order]
    n_fall = lab.sum(); n_a11 = len(lab) - n_fall
    # sweep threshold: predict fall if feat >= t
    best_acc, best_t = 0.0, 0.0
    # cumulative counts
    falls_below = np.cumsum(lab)              # falls with feat < t (misclassified)
    a11_below = np.cumsum(1 - lab)            # a11 with feat < t (correct)
    for i in range(len(f)):
        t = f[i]
        # predict fall if >= t : falls correct = n_fall - falls_below[i-1]
        fb = falls_below[i-1] if i > 0 else 0
        ab = a11_below[i-1] if i > 0 else 0
        correct = (n_fall - fb) + ab
        acc = correct / len(f)
        if acc > best_acc:
            best_acc, best_t = acc, t
    auc = roc_auc_score(is_fall, feat)
    return best_acc, best_t, auc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", required=True)
    args = ap.parse_args()

    X = np.load(os.path.join(args.data_dir, "X.npy"))
    y = np.load(os.path.join(args.data_dir, "y.npy"))
    meta = pd.read_csv(os.path.join(args.data_dir, "meta.csv"))
    activity = meta["activity"].to_numpy()

    print("Precomputing features ...")
    vel, acc, drop = precompute_features(X)

    fall_mask = y == 1
    a11_mask = activity == 11
    # binary problem: true fall (1) vs A11 laying (0)
    keep = fall_mask | a11_mask
    is_fall = fall_mask[keep].astype(int)

    print(f"\nTrue falls: {fall_mask.sum()}   A11 laying windows: {a11_mask.sum()}")
    print("=" * 60)
    print("Oracle single-feature separation (fall vs A11), upper bound:")
    print(f"  {'feature':<14}{'best-acc':>10}{'AUC':>8}   (AUC 0.5=useless, 1.0=perfect)")
    for name, feat in [("max_velocity", vel), ("max_abs_acc", acc), ("hip_drop", drop)]:
        f = feat[keep]
        acc_best, t, auc = oracle_split(f, is_fall)
        print(f"  {name:<14}{acc_best:>10.3f}{auc:>8.3f}   thr={t:.4f}")

    # baseline: fraction that is fall (majority-class accuracy)
    maj = max(is_fall.mean(), 1 - is_fall.mean())
    print(f"\n  majority-class baseline acc = {maj:.3f}")
    print("  (a feature is only useful if best-acc clearly beats this and AUC >> 0.5)")


if __name__ == "__main__":
    main()
