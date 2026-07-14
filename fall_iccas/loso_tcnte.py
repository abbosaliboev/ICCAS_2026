"""
17-fold Leave-One-Subject-Out (LOSO) evaluation for TCNTE / TCN — the same
cross-subject protocol as loso_eval.py (our ST-GCN), so the three methods can be
put in one LOSO comparison table.

Each fold: hold out one whole subject as test; split the other 16 subjects 85/15
into train/val; train TCNTE (weighted focal loss); predict the held-out subject.
Aggregate predictions over all 17 folds -> overall Accuracy / F1 / Recall / FP / FN.

Usage:
  cd fall_iccas
  python loso_tcnte.py --model tcnte --data-dir experiments/subject1_to_17/cv_dataset
  python loso_tcnte.py --model tcn   --data-dir experiments/subject1_to_17/cv_dataset
"""

import os, argparse, json
os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")
import numpy as np
import pandas as pd
import torch
from torch.utils.data import TensorDataset, DataLoader
from sklearn.metrics import f1_score, confusion_matrix

from tcnte import TCNTE, TCN, WeightedFocalLoss

EPOCHS, BATCH, LR, GAMMA, SEED = 100, 64, 1e-4, 3.0, 42
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
torch.manual_seed(SEED); np.random.seed(SEED)


def to_tcn_input(X):
    N, T, V, C = X.shape
    return torch.from_numpy(X.reshape(N, T, V * C).transpose(0, 2, 1)).float()


def evaluate(model, loader):
    model.eval(); preds, labels = [], []
    with torch.no_grad():
        for xb, yb in loader:
            preds.extend(model(xb.to(DEVICE)).argmax(1).cpu().numpy())
            labels.extend(yb.numpy())
    return np.array(labels), np.array(preds)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", required=True)
    ap.add_argument("--model", choices=["tcnte", "tcn"], default="tcnte")
    ap.add_argument("--patience", type=int, default=15)
    ap.add_argument("--out-dir", default=None)
    args = ap.parse_args()
    out_dir = args.out_dir or os.path.join("experiments", f"loso_{args.model}")
    os.makedirs(out_dir, exist_ok=True)

    X = np.load(os.path.join(args.data_dir, "X.npy"))
    y = np.load(os.path.join(args.data_dir, "y.npy"))
    meta = pd.read_csv(os.path.join(args.data_dir, "meta.csv"))
    subjects = meta["subject"].to_numpy()
    Xn = to_tcn_input(X)
    yt = torch.from_numpy(y).long()
    in_feat = X.shape[2] * X.shape[3]

    all_true, all_pred, per_fold = [], [], []
    for test_subj in np.unique(subjects):
        te = np.where(subjects == test_subj)[0]
        pool = np.where(subjects != test_subj)[0]
        # 85/15 train/val per pool subject (deterministic)
        tr, va = [], []
        for s in np.unique(subjects[pool]):
            idx = pool[subjects[pool] == s]
            rng = np.random.default_rng(SEED); rng.shuffle(idx)
            nval = max(1, int(len(idx) * 0.15))
            va.extend(idx[:nval]); tr.extend(idx[nval:])
        tr, va = np.array(tr), np.array(va)

        dl = lambda idx, sh: DataLoader(TensorDataset(Xn[idx], yt[idx]), BATCH, shuffle=sh)
        model = (TCN(in_features=in_feat) if args.model == "tcn"
                 else TCNTE(in_features=in_feat, window=X.shape[1])).to(DEVICE)
        npos = int(y[tr].sum()); alpha = (len(tr) - npos) / max(npos, 1)
        crit = WeightedFocalLoss(alpha=alpha, gamma=GAMMA)
        opt = torch.optim.Adam(model.parameters(), lr=LR)

        best_f1, best_state, no_imp = -1, None, 0
        for ep in range(1, EPOCHS + 1):
            model.train()
            for xb, yb in dl(tr, True):
                opt.zero_grad(); crit(model(xb.to(DEVICE)), yb.to(DEVICE)).backward(); opt.step()
            yv, pv = evaluate(model, dl(va, False))
            f1v = f1_score(yv, pv, pos_label=1, zero_division=0)
            if f1v > best_f1: best_f1, best_state, no_imp = f1v, {k: v.cpu().clone() for k, v in model.state_dict().items()}, 0
            else: no_imp += 1
            if no_imp >= args.patience: break
        model.load_state_dict(best_state)

        yte, pte = evaluate(model, dl(te, False))
        f1 = f1_score(yte, pte, pos_label=1, zero_division=0)
        per_fold.append((int(test_subj), float(f1)))
        all_true.extend(yte); all_pred.extend(pte)
        print(f"  fold S{test_subj:<2} test={len(te):4d}  Fall F1={f1:.4f}")
        del model; torch.cuda.empty_cache()

    cm = confusion_matrix(all_true, all_pred); tn, fp, fn, tp = cm.ravel()
    acc = (tp + tn) / cm.sum()
    rec = tp / (tp + fn) if tp + fn else 0
    prec = tp / (tp + fp) if tp + fp else 0
    f1_agg = 2 * prec * rec / (prec + rec) if prec + rec else 0
    spec = tn / (tn + fp) if tn + fp else 0
    mean_f1 = float(np.mean([f for _, f in per_fold]))

    print("\n" + "=" * 55)
    print(f"  {args.model.upper()} — 17-fold LOSO (aggregate)")
    print("=" * 55)
    print(f"  Accuracy    : {acc:.4f}")
    print(f"  Fall F1     : {f1_agg:.4f}  (mean per-fold {mean_f1:.4f})")
    print(f"  Sensitivity : {rec:.4f}")
    print(f"  Specificity : {spec:.4f}")
    print(f"  Precision   : {prec:.4f}")
    print(f"  FP={fp}  FN={fn}  TP={tp}  TN={tn}")

    out = {"model": args.model.upper(), "protocol": "LOSO-17",
           "accuracy": float(acc), "fall_f1_agg": float(f1_agg), "fall_f1_mean": mean_f1,
           "sensitivity": float(rec), "specificity": float(spec), "precision": float(prec),
           "fp": int(fp), "fn": int(fn), "tp": int(tp), "tn": int(tn),
           "per_fold": per_fold}
    json.dump(out, open(os.path.join(out_dir, "loso_result.json"), "w"), indent=2)
    print(f"\nSaved: {os.path.join(out_dir, 'loso_result.json')}")


if __name__ == "__main__":
    main()
