"""
Two-camera score-level fusion for LOSO fall detection.

Camera1 (frontal) has high recall but low precision (A11 laying false positives).
Camera2 (second view) has higher precision on A11 but lower recall. The errors are
complementary (see RESULTS.md Run 13), so fusing the two per-window fall
probabilities should beat either camera alone.

Reuses the saved per-fold checkpoints of BOTH cameras' LOSO runs (NO retraining).
Both cv_datasets share identical window ordering (deterministic extraction), so
probabilities align row-for-row (asserted below).

Fusion rule is tuned on the VAL set only, then applied to the held-out TEST
subject. Three rules are searched (weighted-average threshold, AND, OR); the one
with the best val Fall-F1 is chosen per fold. Honest: test subject never seen.

Usage:
  cd fall_iccas
  python fuse_cameras.py \
      --cam1-data experiments/subject1_to_17/cv_dataset \
      --cam1-ckpt experiments/subject1_to_17/loso \
      --cam2-data experiments/subject1_to_17_cam2/cv_dataset \
      --cam2-ckpt experiments/subject1_to_17_cam2/loso
"""

import os, argparse, json
import numpy as np
import pandas as pd
import torch
from sklearn.metrics import f1_score, confusion_matrix

from loso_eval import STGCN, DEVICE
from analyze_loso import rebuild_split, probs_for


def metrics(cm):
    tn, fp, fn, tp = cm.ravel()
    rec = tp / (tp + fn) if tp + fn else 0.0
    pre = tp / (tp + fp) if tp + fp else 0.0
    f1 = 2 * pre * rec / (pre + rec) if pre + rec else 0.0
    spec = tn / (tn + fp) if tn + fp else 0.0
    acc = (tp + tn) / (tp + tn + fp + fn)
    return dict(recall=rec, precision=pre, f1=f1, specificity=spec,
               accuracy=acc, fp=int(fp), fn=int(fn))


def best_fusion_on_val(p1, p2, yv):
    """Search fusion rules on val, return (rule, param, threshold)."""
    best = (-1.0, "wavg", 0.5, 0.5)   # f1, rule, w, thr
    # weighted average with threshold
    for w in np.arange(0.0, 1.01, 0.1):
        pf = w * p1 + (1 - w) * p2
        for thr in np.arange(0.3, 0.91, 0.05):
            f1 = f1_score(yv, (pf >= thr).astype(int), pos_label=1, zero_division=0)
            if f1 > best[0]:
                best = (f1, "wavg", float(w), float(thr))
    # AND rule (both cameras fire) — precision-oriented
    for t1 in np.arange(0.3, 0.91, 0.1):
        for t2 in np.arange(0.3, 0.91, 0.1):
            pred = ((p1 >= t1) & (p2 >= t2)).astype(int)
            f1 = f1_score(yv, pred, pos_label=1, zero_division=0)
            if f1 > best[0]:
                best = (f1, "and", float(t1), float(t2))
    # OR rule (either camera fires) — recall-oriented
    for t1 in np.arange(0.3, 0.91, 0.1):
        for t2 in np.arange(0.3, 0.91, 0.1):
            pred = ((p1 >= t1) | (p2 >= t2)).astype(int)
            f1 = f1_score(yv, pred, pos_label=1, zero_division=0)
            if f1 > best[0]:
                best = (f1, "or", float(t1), float(t2))
    return best


def apply_fusion(p1, p2, rule, a, b):
    if rule == "wavg":
        return (a * p1 + (1 - a) * p2 >= b).astype(int)
    if rule == "and":
        return ((p1 >= a) & (p2 >= b)).astype(int)
    if rule == "or":
        return ((p1 >= a) | (p2 >= b)).astype(int)
    raise ValueError(rule)


def load_model(ckpt):
    m = STGCN(in_channels=3, num_classes=2).to(DEVICE)
    m.load_state_dict(torch.load(ckpt, weights_only=True))
    m.eval()
    return m


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cam1-data", required=True)
    ap.add_argument("--cam1-ckpt", required=True)
    ap.add_argument("--cam2-data", required=True)
    ap.add_argument("--cam2-ckpt", required=True)
    args = ap.parse_args()

    X1 = np.load(os.path.join(args.cam1_data, "X.npy"))
    X2 = np.load(os.path.join(args.cam2_data, "X.npy"))
    y = np.load(os.path.join(args.cam1_data, "y.npy"))
    m1 = pd.read_csv(os.path.join(args.cam1_data, "meta.csv"))
    m2 = pd.read_csv(os.path.join(args.cam2_data, "meta.csv"))

    # windows must align row-for-row for score fusion
    assert len(X1) == len(X2) == len(y), "window counts differ between cameras"
    assert (m1[["subject", "activity", "trial", "start_frame"]].values
            == m2[["subject", "activity", "trial", "start_frame"]].values).all(), \
        "meta ordering differs between cameras — cannot fuse row-for-row"

    subjects = m1["subject"].to_numpy()
    unique_subjects = np.unique(subjects)

    cam1_f1s, cam2_f1s, fus_f1s = [], [], []
    agg_true, agg_c1, agg_c2, agg_fus = [], [], [], []

    print(f"  {'Fold':<5}{'Subj':<6}{'cam1':>8}{'cam2':>8}{'fused':>8}   rule")
    for fold_idx, test_subj in enumerate(unique_subjects, 1):
        c1 = os.path.join(args.cam1_ckpt, f"fold{fold_idx}_best.pth")
        c2 = os.path.join(args.cam2_ckpt, f"fold{fold_idx}_best.pth")
        if not (os.path.exists(c1) and os.path.exists(c2)):
            print(f"  [skip] fold {fold_idx}: missing checkpoint(s)")
            continue

        _, val_idx, te_idx = rebuild_split(subjects, test_subj)
        y_val, y_te = y[val_idx], y[te_idx]

        mdl1 = load_model(c1)
        p1_val = probs_for(mdl1, X1[val_idx], y_val)
        p1_te = probs_for(mdl1, X1[te_idx], y_te)
        del mdl1; torch.cuda.empty_cache()

        mdl2 = load_model(c2)
        p2_val = probs_for(mdl2, X2[val_idx], y_val)
        p2_te = probs_for(mdl2, X2[te_idx], y_te)
        del mdl2; torch.cuda.empty_cache()

        _, rule, a, b = best_fusion_on_val(p1_val, p2_val, y_val)
        fus_te = apply_fusion(p1_te, p2_te, rule, a, b)

        c1_pred = (p1_te >= 0.5).astype(int)
        c2_pred = (p2_te >= 0.5).astype(int)
        c1_f1 = f1_score(y_te, c1_pred, pos_label=1, zero_division=0)
        c2_f1 = f1_score(y_te, c2_pred, pos_label=1, zero_division=0)
        fus_f1 = f1_score(y_te, fus_te, pos_label=1, zero_division=0)
        cam1_f1s.append(c1_f1); cam2_f1s.append(c2_f1); fus_f1s.append(fus_f1)
        agg_true.extend(y_te); agg_c1.extend(c1_pred); agg_c2.extend(c2_pred); agg_fus.extend(fus_te)

        print(f"  {fold_idx:<5}S{test_subj:<5}{c1_f1:>8.4f}{c2_f1:>8.4f}{fus_f1:>8.4f}"
              f"   {rule}({a:.2f},{b:.2f})")

    print("\n" + "=" * 60)
    for name, preds, f1s in [("Camera1", agg_c1, cam1_f1s),
                             ("Camera2", agg_c2, cam2_f1s),
                             ("Fusion ", agg_fus, fus_f1s)]:
        mt = metrics(confusion_matrix(agg_true, preds))
        print(f"{name}  meanF1={np.mean(f1s):.4f}   "
              f"Recall={mt['recall']:.3f} Prec={mt['precision']:.3f} "
              f"F1={mt['f1']:.3f} Spec={mt['specificity']:.3f} Acc={mt['accuracy']:.3f} "
              f"FP={mt['fp']} FN={mt['fn']}")

    out = {
        "cam1_mean_f1": float(np.mean(cam1_f1s)),
        "cam2_mean_f1": float(np.mean(cam2_f1s)),
        "fusion_mean_f1": float(np.mean(fus_f1s)),
        "fusion_agg": metrics(confusion_matrix(agg_true, agg_fus)),
        "fusion_per_fold": [float(v) for v in fus_f1s],
    }
    with open(os.path.join(args.cam2_ckpt, "fuse_cameras.json"), "w") as f:
        json.dump(out, f, indent=2)
    print(f"\nSaved: {os.path.join(args.cam2_ckpt, 'fuse_cameras.json')}")


if __name__ == "__main__":
    main()
