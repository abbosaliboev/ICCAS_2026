"""
Rule-based (Physics Filter) offline evaluation.

Usage:
  cd fall_iccas
  python eval_physics.py
  python eval_physics.py --exp experiments/subject1_2_3_4
  python eval_physics.py --percentile 30
  python eval_physics.py --split 0.8        # 80% train threshold fitting, 20% test
"""

import os, sys, argparse
import numpy as np
from sklearn.metrics import (classification_report, confusion_matrix,
                             f1_score, accuracy_score)

sys.path.insert(0, os.path.dirname(__file__))
from stgcn.physics import PhysicsFilter


def load_dataset(exp_dir: str):
    ds = os.path.join(exp_dir, "cv_dataset")
    X = np.load(os.path.join(ds, "X.npy"))   # (N, 30, 17, 3)
    y = np.load(os.path.join(ds, "y.npy"))   # (N,)
    print(f"Dataset: {X.shape[0]} samples  |  fall={y.sum()}  no-fall={(y==0).sum()}")
    return X, y


def grid_search(X_tr, y_tr, fps):
    """Find best (vel_threshold, acc_threshold) on training split."""
    pf = PhysicsFilter(fps=fps)
    feats = [pf.extract_features(X_tr[i]) for i in range(len(X_tr))]
    vel = np.array([f["max_velocity"] for f in feats])
    acc = np.array([f["max_abs_acc"]  for f in feats])

    fall_mask = y_tr == 1
    vel_cands = np.percentile(vel[fall_mask], np.arange(0, 100, 5))
    acc_cands = np.percentile(acc[fall_mask], np.arange(0, 100, 5))

    best_f1 = -1
    best_vt = best_at = 0.0
    for vt in vel_cands:
        for at in acc_cands:
            preds = ((vel > vt) & (acc > at)).astype(int)
            f1 = f1_score(y_tr, preds, pos_label=1, zero_division=0)
            if f1 > best_f1:
                best_f1, best_vt, best_at = f1, vt, at
    return best_vt, best_at, best_f1


def evaluate(X, y, vel_threshold, acc_threshold, fps, label=""):
    pf = PhysicsFilter(fps=fps,
                       vel_threshold=vel_threshold,
                       acc_threshold=acc_threshold)
    preds = np.array([pf.predict(X[i]) for i in range(len(X))])

    acc  = accuracy_score(y, preds)
    f1   = f1_score(y, preds, pos_label=1, zero_division=0)
    cm   = confusion_matrix(y, preds)

    tag = f"[{label}] " if label else ""
    print(f"\n{'='*55}")
    print(f"{tag}Physics Filter Evaluation")
    print(f"  vel_threshold = {vel_threshold:.5f}")
    print(f"  acc_threshold = {acc_threshold:.5f}")
    print(f"{'='*55}")
    print(f"  Accuracy : {acc:.4f}")
    print(f"  Fall F1  : {f1:.4f}")
    print()
    print(classification_report(y, preds,
                                target_names=["NO-FALL", "FALL"],
                                zero_division=0))
    tn, fp, fn, tp = cm.ravel()
    print("Confusion matrix:")
    print(f"           Pred NO-FALL  Pred FALL")
    print(f"  NO-FALL  {tn:>10d}  {fp:>9d}")
    print(f"  FALL     {fn:>10d}  {tp:>9d}")
    print(f"{'='*55}")
    return preds, acc, f1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exp",        default=None,
                    help="Experiment dir (default: experiments/subject1_2_3_4)")
    ap.add_argument("--fps",        type=float, default=19.0,
                    help="Skeleton FPS (default 19.0)")
    ap.add_argument("--percentile", type=float, default=20.0,
                    help="Percentile for threshold fitting (default 20)")
    ap.add_argument("--split",      type=float, default=0.8,
                    help="Train fraction for threshold fitting (default 0.8)")
    ap.add_argument("--no-split",   action="store_true",
                    help="Fit and evaluate on the full dataset (no train/test split)")
    ap.add_argument("--vel",        type=float, default=None,
                    help="Override vel_threshold manually")
    ap.add_argument("--acc",        type=float, default=None,
                    help="Override acc_threshold manually")
    args = ap.parse_args()

    base    = os.path.dirname(__file__)
    exp_dir = args.exp or os.path.join(base, "experiments", "subject1_2_3_4")
    X, y    = load_dataset(exp_dir)

    # ── manual thresholds ─────────────────────────────────────────────────────
    if args.vel is not None and args.acc is not None:
        evaluate(X, y, args.vel, args.acc, args.fps, label="manual")
        return

    # ── no split: fit on all, evaluate on all ─────────────────────────────────
    if args.no_split:
        pf = PhysicsFilter(fps=args.fps)
        pf.fit(X, y, percentile=args.percentile)
        evaluate(X, y, pf.vel_threshold, pf.acc_threshold, args.fps, label="full dataset")
        return

    # ── train/test split ──────────────────────────────────────────────────────
    N     = len(y)
    idx   = np.random.permutation(N)
    n_tr  = int(N * args.split)
    tr, te = idx[:n_tr], idx[n_tr:]

    X_tr, y_tr = X[tr], y[tr]
    X_te, y_te = X[te], y[te]

    print(f"\nSplit: train={len(tr)}  test={len(te)}  "
          f"(fall_tr={y_tr.sum()}  fall_te={y_te.sum()})")

    # fit thresholds on train
    print("\n--- Grid search on train split ---")
    vt, at, tr_f1 = grid_search(X_tr, y_tr, args.fps)
    print(f"  Best train F1 = {tr_f1:.4f}  "
          f"vel>{vt:.5f}  acc>{at:.5f}")

    # evaluate on test
    evaluate(X_te, y_te, vt, at, args.fps, label="test")

    # also show percentile-fitted thresholds for comparison
    pf = PhysicsFilter(fps=args.fps)
    pf.fit(X_tr, y_tr, percentile=args.percentile)
    evaluate(X_te, y_te, pf.vel_threshold, pf.acc_threshold,
             args.fps, label=f"percentile-{args.percentile}")


if __name__ == "__main__":
    main()
