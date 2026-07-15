"""
Fixed cross-subject split comparison: train on chosen subjects, validate on
another, test on a held-out subject — for TCNTE, ST-GCN, and ST-GCN + Physics,
all on the SAME split. Used for the poster's cross-subject tables:

  Full   : train S1-15, val S16, test S17
  Limited: train S1-3,  val S16, test S17

Both test on the SAME unseen subject (17); only the training-set size differs, so
the tables isolate the effect of training-data size on cross-subject performance.

Usage:
  cd fall_iccas
  python crosssub_compare.py --data-dir experiments/subject1_to_17/cv_dataset \
      --train-subjects 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 --val-subjects 16 --test-subjects 17 \
      --tag full
  python crosssub_compare.py --data-dir experiments/subject1_to_17/cv_dataset \
      --train-subjects 1 2 3 --val-subjects 16 --test-subjects 17 --tag limited
"""

import os, argparse, json
import numpy as np, pandas as pd, torch
import torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset
from sklearn.metrics import f1_score, confusion_matrix

from loso_eval import (STGCN, FallDataset, evaluate, train_epoch, make_sampler,
                       to_stgcn_tensor, PhysicsFilter, TwoStageDetector,
                       DEVICE, BATCH_SIZE, EPOCHS, LR, WEIGHT_DECAY, DROPOUT, FPS)
from tcnte import TCNTE, WeightedFocalLoss


def stats(y_true, y_pred):
    cm = confusion_matrix(y_true, y_pred, labels=[0, 1]); tn, fp, fn, tp = cm.ravel()
    rec = tp / (tp + fn) if tp + fn else 0
    prec = tp / (tp + fp) if tp + fp else 0
    return {"accuracy": (tp + tn) / cm.sum(),
            "fall_f1": 2 * prec * rec / (prec + rec) if prec + rec else 0,
            "sensitivity": rec, "specificity": tn / (tn + fp) if tn + fp else 0,
            "precision": prec, "fp": int(fp), "fn": int(fn), "tp": int(tp), "tn": int(tn)}


def train_stgcn(Xtr, ytr, Xva, yva, patience=15, width=64, loss="sampler"):
    """loss='sampler' -> WeightedRandomSampler + CrossEntropy (our original);
       loss='focal'   -> no sampler + weighted focal loss (TCNTE's technique)."""
    if loss == "focal":
        tr = DataLoader(FallDataset(Xtr, ytr, augment=True), BATCH_SIZE, shuffle=True)
        npos = int(ytr.sum()); alpha = (len(ytr) - npos) / max(npos, 1)
        crit = WeightedFocalLoss(alpha=alpha, gamma=3.0)
        print(f"  ST-GCN loss=focal (alpha={alpha:.2f}, gamma=3)")
    else:
        tr = DataLoader(FallDataset(Xtr, ytr, augment=True), BATCH_SIZE, sampler=make_sampler(ytr))
        crit = nn.CrossEntropyLoss()
    va = DataLoader(FallDataset(Xva, yva), BATCH_SIZE, shuffle=False)
    m = STGCN(in_channels=3, num_classes=2, dropout=DROPOUT, width=width).to(DEVICE)
    print(f"  ST-GCN width={width}  params={sum(p.numel() for p in m.parameters()):,}")
    opt = torch.optim.Adam(m.parameters(), lr=LR, weight_decay=WEIGHT_DECAY)
    sch = torch.optim.lr_scheduler.CosineAnnealingLR(opt, T_max=EPOCHS)
    best, state, no = -1, None, 0
    for _ in range(EPOCHS):
        train_epoch(m, tr, opt, crit)
        _, _, vp, vl, _ = evaluate(m, va, crit); f1 = f1_score(vl, vp, pos_label=1, zero_division=0)
        sch.step()
        if f1 > best: best, state, no = f1, {k: v.cpu().clone() for k, v in m.state_dict().items()}, 0
        else: no += 1
        if no >= patience: break
    m.load_state_dict(state); return m


def train_tcnte(Xtr, ytr, Xva, yva, patience=15):
    tin = lambda X: torch.from_numpy(X.reshape(len(X), X.shape[1], -1).transpose(0, 2, 1)).float()
    dl = lambda Xd, yd, sh: DataLoader(TensorDataset(tin(Xd), torch.from_numpy(yd).long()), 64, shuffle=sh)
    m = TCNTE(in_features=Xtr.shape[2] * Xtr.shape[3], window=Xtr.shape[1]).to(DEVICE)
    npos = int(ytr.sum()); alpha = (len(ytr) - npos) / max(npos, 1)
    crit = WeightedFocalLoss(alpha=alpha, gamma=3.0); opt = torch.optim.Adam(m.parameters(), lr=1e-4)
    best, state, no = -1, None, 0
    for _ in range(100):
        m.train()
        for xb, yb in dl(Xtr, ytr, True):
            opt.zero_grad(); crit(m(xb.to(DEVICE)), yb.to(DEVICE)).backward(); opt.step()
        m.eval(); vp = []
        with torch.no_grad():
            for xb, _ in dl(Xva, yva, False): vp.extend(m(xb.to(DEVICE)).argmax(1).cpu().numpy())
        f1 = f1_score(yva, vp, pos_label=1, zero_division=0)
        if f1 > best: best, state, no = f1, {k: v.cpu().clone() for k, v in m.state_dict().items()}, 0
        else: no += 1
        if no >= patience: break
    m.load_state_dict(state)
    def predict(Xte):
        m.eval(); p = []
        with torch.no_grad():
            for xb, _ in dl(Xte, np.zeros(len(Xte), int), False): p.extend(m(xb.to(DEVICE)).argmax(1).cpu().numpy())
        return np.array(p)
    return predict


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", required=True)
    ap.add_argument("--train-subjects", type=int, nargs="+", required=True)
    ap.add_argument("--val-subjects", type=int, nargs="+", required=True)
    ap.add_argument("--test-subjects", type=int, nargs="+", required=True)
    ap.add_argument("--tag", default="split")
    ap.add_argument("--stgcn-loss", choices=["sampler", "focal"], default="sampler",
                    help="sampler = WeightedRandomSampler+CE (original); focal = weighted focal loss (TCNTE's technique)")
    ap.add_argument("--stgcn-width", type=int, default=64,
                    help="ST-GCN base channels (64 = original ~3.1M params; "
                         "16 ~200k; 8 ~50k — smaller fits limited data better)")
    args = ap.parse_args()

    X = np.load(os.path.join(args.data_dir, "X.npy"))
    y = np.load(os.path.join(args.data_dir, "y.npy"))
    subj = pd.read_csv(os.path.join(args.data_dir, "meta.csv"))["subject"].to_numpy()
    tr = np.where(np.isin(subj, args.train_subjects))[0]
    va = np.where(np.isin(subj, args.val_subjects))[0]
    te = np.where(np.isin(subj, args.test_subjects))[0]
    print(f"[{args.tag}] train S{args.train_subjects} ({len(tr)})  "
          f"val S{args.val_subjects} ({len(va)})  test S{args.test_subjects} ({len(te)}, fall={int(y[te].sum())})")

    results = {}

    # TCNTE
    pred = train_tcnte(X[tr], y[tr], X[va], y[va])
    results["TCNTE"] = stats(y[te], pred(X[te]))

    # ST-GCN + Physics
    stgcn = train_stgcn(X[tr], y[tr], X[va], y[va], width=args.stgcn_width, loss=args.stgcn_loss)
    te_loader = DataLoader(FallDataset(X[te], y[te]), BATCH_SIZE, shuffle=False)
    _, _, s1_preds, y_te, _ = evaluate(stgcn, te_loader, nn.CrossEntropyLoss())
    results["ST-GCN"] = stats(y_te, s1_preds)

    physics = PhysicsFilter(fps=FPS)
    va_loader = DataLoader(FallDataset(X[va], y[va]), BATCH_SIZE, shuffle=False)
    _, _, s1_val, _, _ = evaluate(stgcn, va_loader, nn.CrossEntropyLoss())
    physics.search_thresholds(X[va], y[va], s1_val)
    det = TwoStageDetector(stgcn, physics, device=DEVICE)
    det.tune_thresholds(to_stgcn_tensor(X[va]), X[va], y[va])
    s2_preds = det.predict_batch(to_stgcn_tensor(X[te]), X[te])
    results["ST-GCN + Physics"] = stats(y_te, s2_preds)

    print(f"\n{'Model':<22}{'Acc':>7}{'F1':>8}{'Sens':>7}{'Spec':>7}{'FP':>5}{'FN':>5}")
    for name in ["TCNTE", "ST-GCN", "ST-GCN + Physics"]:
        r = results[name]
        print(f"{name:<22}{r['accuracy']:>7.3f}{r['fall_f1']:>8.4f}"
              f"{r['sensitivity']:>7.3f}{r['specificity']:>7.3f}{r['fp']:>5}{r['fn']:>5}")

    out_dir = os.path.join("experiments", f"crosssub_{args.tag}")
    os.makedirs(out_dir, exist_ok=True)
    json.dump({"tag": args.tag, "train": args.train_subjects, "val": args.val_subjects,
               "test": args.test_subjects, "results": results},
              open(os.path.join(out_dir, "result.json"), "w"), indent=2)
    print(f"\nSaved: {os.path.join(out_dir, 'result.json')}")


if __name__ == "__main__":
    main()
