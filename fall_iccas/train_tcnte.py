"""
Train the re-implemented TCNTE (Yu et al. 2025) on our cv_dataset, using the
SAME subject-stratified split (seed 42) as train_two_stage.py, so it can be
compared head-to-head with our ST-GCN + Physics on identical data.

Fair comparison: same windows, same train/test split, same subjects.
Only the model architecture differs (TCNTE = TCN+Transformer vs our ST-GCN).

Usage:
  cd fall_iccas
  python train_tcnte.py --data-dir experiments/subject1_to_17/cv_dataset --subjects 1 2 3 \
      --ckpt-dir experiments/tcnte/subj_1_to_3
"""

import os, argparse, json
os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")
import numpy as np
import pandas as pd
import torch
from torch.utils.data import TensorDataset, DataLoader
from sklearn.metrics import (f1_score, accuracy_score, precision_score,
                             recall_score, confusion_matrix, classification_report)

from tcnte import TCNTE, WeightedFocalLoss

EPOCHS = 100
BATCH  = 64
LR     = 1e-4
GAMMA  = 3.0
SEED   = 42
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
torch.manual_seed(SEED); np.random.seed(SEED)


def subject_stratified_split(y, subjects):
    """Identical logic to train_two_stage.py (seed 42, 70/15/15 per subject)."""
    tr, va, te = [], [], []
    for subj in np.unique(subjects):
        idx = np.where(subjects == subj)[0]
        np.random.seed(42)
        np.random.shuffle(idx)
        n = len(idx); n_tr = int(n * 0.70); n_val = int(n * 0.15)
        tr.extend(idx[:n_tr]); va.extend(idx[n_tr:n_tr + n_val]); te.extend(idx[n_tr + n_val:])
    return np.array(tr), np.array(va), np.array(te)


def to_tcn_input(X):
    """(N, T, V, C) -> (N, V*C, T) for the TCN (channels-first over time)."""
    N, T, V, C = X.shape
    return torch.from_numpy(X.reshape(N, T, V * C).transpose(0, 2, 1)).float()


def evaluate(model, loader):
    model.eval(); preds, labels = [], []
    with torch.no_grad():
        for xb, yb in loader:
            out = model(xb.to(DEVICE))
            preds.extend(out.argmax(1).cpu().numpy()); labels.extend(yb.numpy())
    return np.array(labels), np.array(preds)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", required=True)
    ap.add_argument("--subjects", type=int, nargs="+", default=None)
    ap.add_argument("--ckpt-dir", required=True)
    ap.add_argument("--patience", type=int, default=15)
    args = ap.parse_args()
    os.makedirs(args.ckpt_dir, exist_ok=True)

    X = np.load(os.path.join(args.data_dir, "X.npy"))
    y = np.load(os.path.join(args.data_dir, "y.npy"))
    meta = pd.read_csv(os.path.join(args.data_dir, "meta.csv"))

    if args.subjects:
        keep = meta["subject"].isin(set(args.subjects)).values
        X, y, meta = X[keep], y[keep], meta[keep].reset_index(drop=True)
    subjects = meta["subject"].values

    tr, va, te = subject_stratified_split(y, subjects)
    print(f"TCNTE — subjects {sorted(set(subjects.tolist()))}  "
          f"train={len(tr)} val={len(va)} test={len(te)}  "
          f"(fall test={int(y[te].sum())})")

    Xn = to_tcn_input(X)
    yt = torch.from_numpy(y).long()
    dl = lambda idx, sh: DataLoader(TensorDataset(Xn[idx], yt[idx]), BATCH, shuffle=sh)
    tr_loader, va_loader, te_loader = dl(tr, True), dl(va, False), dl(te, False)

    # weighted focal loss: alpha = non-fall / fall ratio (paper's initialization)
    npos = int(y[tr].sum()); nneg = len(tr) - npos
    alpha = nneg / max(npos, 1)
    print(f"WFL alpha (non-fall/fall ratio) = {alpha:.2f}, gamma = {GAMMA}")

    model = TCNTE(in_features=X.shape[2] * X.shape[3], window=X.shape[1]).to(DEVICE)
    crit  = WeightedFocalLoss(alpha=alpha, gamma=GAMMA)
    opt   = torch.optim.Adam(model.parameters(), lr=LR)

    best_f1, best_state, no_imp = -1, None, 0
    for ep in range(1, EPOCHS + 1):
        model.train()
        for xb, yb in tr_loader:
            opt.zero_grad()
            loss = crit(model(xb.to(DEVICE)), yb.to(DEVICE))
            loss.backward(); opt.step()
        yv, pv = evaluate(model, va_loader)
        f1 = f1_score(yv, pv, pos_label=1, zero_division=0)
        if f1 > best_f1:
            best_f1, best_state, no_imp = f1, {k: v.cpu().clone() for k, v in model.state_dict().items()}, 0
        else:
            no_imp += 1
        if ep % 10 == 0 or ep == 1:
            print(f"  epoch {ep:3d}  val_fall_F1={f1:.4f}  best={best_f1:.4f}")
        if no_imp >= args.patience:
            print(f"  early stop at epoch {ep}"); break

    model.load_state_dict(best_state)
    yte, pte = evaluate(model, te_loader)
    acc = accuracy_score(yte, pte)
    f1  = f1_score(yte, pte, pos_label=1, zero_division=0)
    prec = precision_score(yte, pte, pos_label=1, zero_division=0)
    rec  = recall_score(yte, pte, pos_label=1, zero_division=0)
    cm = confusion_matrix(yte, pte)
    tn, fp, fn, tp = cm.ravel()
    sens = tp / (tp + fn) if (tp + fn) else 0.0   # sensitivity = recall
    spec = tn / (tn + fp) if (tn + fp) else 0.0   # specificity

    print("\n" + "=" * 50)
    print("  TCNTE (TCN + Transformer) — test result")
    print("=" * 50)
    print(f"  Accuracy    : {acc:.4f}")
    print(f"  Sensitivity : {sens:.4f}")
    print(f"  Specificity : {spec:.4f}")
    print(f"  Fall F1     : {f1:.4f}")
    print(f"  Precision   : {prec:.4f}")
    print(f"  Recall      : {rec:.4f}")
    print(f"  FP={fp}  FN={fn}  TP={tp}  TN={tn}")
    print(f"\n{classification_report(yte, pte, target_names=['NO-FALL','FALL'], zero_division=0)}")
    print(f"Confusion:\n{cm}")

    out = {"model": "TCNTE", "subjects": sorted(set(subjects.tolist())),
           "n_test": int(len(te)), "accuracy": float(acc), "fall_f1": float(f1),
           "sensitivity": float(sens), "specificity": float(spec),
           "precision": float(prec), "recall": float(rec),
           "fp": int(fp), "fn": int(fn), "tp": int(tp), "tn": int(tn)}
    json.dump(out, open(os.path.join(args.ckpt_dir, "tcnte_result.json"), "w"), indent=2)
    with open(os.path.join(args.ckpt_dir, "results.txt"), "w") as f:
        f.write(json.dumps(out, indent=2))
    print(f"\nSaved: {os.path.join(args.ckpt_dir, 'tcnte_result.json')}")


if __name__ == "__main__":
    main()
