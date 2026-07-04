"""
Leave-One-Subject-Out (LOSO) cross-subject evaluation.

For each fold one subject is held out as the test set;
the remaining subjects are split 85/15 into train/val.
Reports per-fold Fall F1 and the macro average across all folds.

Usage:
  cd fall_iccas
  python loso_eval.py
  python loso_eval.py --data-dir experiments/subject1_2_3_4_5/cv_dataset
  python loso_eval.py --data-dir experiments/subject1_2_3_4_5/cv_dataset \
                      --out-dir   experiments/subject1_2_3_4_5/loso
"""

import os, sys, argparse, json
os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")
import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader, WeightedRandomSampler
from sklearn.metrics import (
    f1_score, accuracy_score, classification_report, confusion_matrix
)

from stgcn import STGCN, PhysicsFilter, TwoStageDetector

# ── config ────────────────────────────────────────────────────────────────────
EPOCHS      = 60
BATCH_SIZE  = 32
LR          = 1e-3
WEIGHT_DECAY= 1e-4
DROPOUT     = 0.5
FPS         = 19.0
SEED        = 42
DEVICE      = "cuda" if torch.cuda.is_available() else "cpu"

torch.manual_seed(SEED)
np.random.seed(SEED)
if torch.cuda.is_available():
    torch.cuda.manual_seed_all(SEED)
    torch.backends.cuda.enable_flash_sdp(False)
    torch.backends.cuda.enable_mem_efficient_sdp(False)
    torch.backends.cuda.enable_math_sdp(True)


# ── dataset ───────────────────────────────────────────────────────────────────

class FallDataset(Dataset):
    def __init__(self, X, y, augment=False):
        self.X = torch.from_numpy(X.transpose(0, 3, 1, 2)).float()
        self.y = torch.from_numpy(y).long()
        self.augment = augment

    def __len__(self):
        return len(self.y)

    def __getitem__(self, idx):
        x = self.X[idx]
        if self.augment:
            if torch.rand(1) < 0.5:
                x = x.flip(-1)
            x = x + torch.randn_like(x) * 0.01
        return x.unsqueeze(-1), self.y[idx]


def make_sampler(y):
    _, counts = np.unique(y, return_counts=True)
    weights = 1.0 / counts
    sw = torch.tensor([weights[c] for c in y], dtype=torch.float)
    return WeightedRandomSampler(sw, len(sw))


def to_stgcn_tensor(X_np):
    t = torch.from_numpy(X_np.transpose(0, 3, 1, 2)).float()
    return t.unsqueeze(-1)


# ── train / eval helpers ──────────────────────────────────────────────────────

def train_epoch(model, loader, optimizer, criterion):
    model.train()
    loss_sum, correct, total = 0.0, 0, 0
    for x, y in loader:
        x, y = x.to(DEVICE), y.to(DEVICE)
        logits = model(x)
        loss = criterion(logits, y)
        optimizer.zero_grad(); loss.backward(); optimizer.step()
        loss_sum += loss.item() * len(y)
        correct  += (logits.argmax(1) == y).sum().item()
        total    += len(y)
    return loss_sum / total, correct / total


@torch.no_grad()
def evaluate(model, loader, criterion):
    model.eval()
    loss_sum, correct, total = 0.0, 0, 0
    all_preds, all_labels, all_probs = [], [], []
    for x, y in loader:
        x, y = x.to(DEVICE), y.to(DEVICE)
        logits = model(x)
        loss   = criterion(logits, y)
        probs  = torch.softmax(logits, dim=-1)[:, 1]
        preds  = logits.argmax(1)
        loss_sum += loss.item() * len(y)
        correct  += (preds == y).sum().item()
        total    += len(y)
        all_preds.extend(preds.cpu().numpy())
        all_labels.extend(y.cpu().numpy())
        all_probs.extend(probs.cpu().numpy())
    return (loss_sum / total, correct / total,
            np.array(all_preds), np.array(all_labels), np.array(all_probs))


# ── one LOSO fold ─────────────────────────────────────────────────────────────

def run_fold(fold_idx, test_subj, X, y, subjects, patience, ckpt_dir):
    print(f"\n{'='*55}")
    print(f"  Fold {fold_idx}  —  Test subject: {test_subj}")
    print(f"{'='*55}")

    te_mask = subjects == test_subj
    tr_pool_mask = ~te_mask

    X_te, y_te = X[te_mask], y[te_mask]

    # split training pool 85/15 → train / val (each subject proportionally)
    pool_subjects = subjects[tr_pool_mask]
    pool_idx      = np.where(tr_pool_mask)[0]
    tr_idx, val_idx = [], []
    for s in np.unique(pool_subjects):
        idx = pool_idx[pool_subjects == s]
        rng = np.random.default_rng(SEED)
        rng.shuffle(idx)
        n_val = max(1, int(len(idx) * 0.15))
        val_idx.extend(idx[:n_val])
        tr_idx.extend(idx[n_val:])
    tr_idx  = np.array(tr_idx)
    val_idx = np.array(val_idx)

    X_tr,  y_tr  = X[tr_idx],  y[tr_idx]
    X_val, y_val = X[val_idx], y[val_idx]

    print(f"  Train: {len(y_tr)} (fall={y_tr.sum()})  "
          f"Val: {len(y_val)} (fall={y_val.sum()})  "
          f"Test: {len(y_te)} (fall={y_te.sum()})")

    train_loader = DataLoader(FallDataset(X_tr, y_tr, augment=True),
                              BATCH_SIZE, sampler=make_sampler(y_tr))
    val_loader   = DataLoader(FallDataset(X_val, y_val), BATCH_SIZE, shuffle=False)
    test_loader  = DataLoader(FallDataset(X_te,  y_te),  BATCH_SIZE, shuffle=False)

    # ── Stage 1: train ST-GCN ─────────────────────────────────────────────────
    model     = STGCN(in_channels=3, num_classes=2, dropout=DROPOUT).to(DEVICE)
    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.Adam(model.parameters(), lr=LR, weight_decay=WEIGHT_DECAY)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=EPOCHS)

    best_val_f1 = -1.0
    no_improve  = 0
    ckpt_path   = os.path.join(ckpt_dir, f"fold{fold_idx}_best.pth")

    for epoch in range(1, EPOCHS + 1):
        tr_loss, tr_acc = train_epoch(model, train_loader, optimizer, criterion)
        _, va_acc, va_preds, va_labels, _ = evaluate(model, val_loader, criterion)
        va_f1 = f1_score(va_labels, va_preds, pos_label=1, zero_division=0)
        scheduler.step()

        if va_f1 > best_val_f1:
            best_val_f1 = va_f1
            no_improve  = 0
            torch.save(model.state_dict(), ckpt_path)
        else:
            no_improve += 1

        if epoch % 10 == 0 or epoch == 1:
            print(f"    Epoch {epoch:3d}/{EPOCHS}  "
                  f"tr_loss={tr_loss:.4f} tr_acc={tr_acc:.3f}  "
                  f"val_acc={va_acc:.3f} val_f1={va_f1:.3f}  "
                  f"best={best_val_f1:.3f}  no_improve={no_improve}")

        if no_improve >= patience:
            print(f"    Early stopping at epoch {epoch}")
            break

    model.load_state_dict(torch.load(ckpt_path, weights_only=True))
    print(f"  Loaded best (val fall F1={best_val_f1:.4f})")

    # ── Stage 1 test ──────────────────────────────────────────────────────────
    _, _, s1_preds, y_te_true, s1_probs = evaluate(model, test_loader, criterion)
    s1_f1  = f1_score(y_te_true, s1_preds, pos_label=1, zero_division=0)
    s1_acc = accuracy_score(y_te_true, s1_preds)
    cm1    = confusion_matrix(y_te_true, s1_preds)
    print(f"\n  [Stage 1]  Acc={s1_acc:.4f}  Fall F1={s1_f1:.4f}")
    print(f"  Confusion:\n{cm1}")

    # ── Stage 2: physics filter ───────────────────────────────────────────────
    physics = PhysicsFilter(fps=FPS)
    _, _, s1_val_preds, _, _ = evaluate(model, val_loader, criterion)
    physics.search_thresholds(X_val, y_val, s1_val_preds)

    detector = TwoStageDetector(model, physics, device=DEVICE)
    X_val_t  = to_stgcn_tensor(X_val)
    detector.tune_thresholds(X_val_t, X_val, y_val)

    X_te_t     = to_stgcn_tensor(X_te)
    s2_preds   = detector.predict_batch(X_te_t, X_te)
    s2_f1      = f1_score(y_te_true, s2_preds, pos_label=1, zero_division=0)
    s2_acc     = accuracy_score(y_te_true, s2_preds)
    cm2        = confusion_matrix(y_te_true, s2_preds)
    print(f"\n  [Two-stage] Acc={s2_acc:.4f}  Fall F1={s2_f1:.4f}")
    print(f"  Confusion:\n{cm2}")

    del model, optimizer, scheduler, detector, physics
    torch.cuda.empty_cache()

    return {
        "fold":       fold_idx,
        "test_subj":  int(test_subj),
        "n_test":     int(len(y_te)),
        "fall_test":  int(y_te.sum()),
        "s1_acc":     float(s1_acc),
        "s1_f1":      float(s1_f1),
        "s1_cm":      cm1.tolist(),
        "s2_acc":     float(s2_acc),
        "s2_f1":      float(s2_f1),
        "s2_cm":      cm2.tolist(),
    }


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default=None,
                    help="Directory with X.npy / y.npy / meta.csv")
    ap.add_argument("--out-dir", default=None,
                    help="Output directory for per-fold checkpoints + summary")
    ap.add_argument("--patience", type=int, default=15)
    args = ap.parse_args()

    base     = os.path.dirname(__file__)
    data_dir = args.data_dir or os.path.join(base, "cv_dataset")
    out_dir  = args.out_dir  or os.path.join(base, "loso_results")
    os.makedirs(out_dir, exist_ok=True)

    X = np.load(os.path.join(data_dir, "X.npy"))
    y = np.load(os.path.join(data_dir, "y.npy"))
    meta = pd.read_csv(os.path.join(data_dir, "meta.csv"))
    subjects = meta["subject"].values

    unique_subjects = np.unique(subjects)
    print(f"LOSO Evaluation")
    print(f"Data dir : {data_dir}")
    print(f"Subjects : {unique_subjects.tolist()}  ({len(unique_subjects)} folds)")
    print(f"Dataset  : {X.shape}  FALL={y.sum()}  NO-FALL={(y==0).sum()}")
    print(f"Device   : {DEVICE}")

    # tee stdout to file
    log_path    = os.path.join(out_dir, "loso_results.txt")
    tee_file    = open(log_path, "w", encoding="utf-8")
    _orig_out   = sys.stdout
    class Tee:
        def write(self, s): _orig_out.write(s); tee_file.write(s)
        def flush(self):    _orig_out.flush();  tee_file.flush()
    sys.stdout = Tee()

    fold_results = []
    for i, test_subj in enumerate(unique_subjects, 1):
        torch.cuda.empty_cache()
        result = run_fold(i, test_subj, X, y, subjects, args.patience, out_dir)
        fold_results.append(result)

    # ── summary ───────────────────────────────────────────────────────────────
    s1_f1s = [r["s1_f1"] for r in fold_results]
    s2_f1s = [r["s2_f1"] for r in fold_results]
    s1_acc_list = [r["s1_acc"] for r in fold_results]
    s2_acc_list = [r["s2_acc"] for r in fold_results]

    print(f"\n{'='*55}")
    print(f"  LOSO SUMMARY  ({len(unique_subjects)} folds)")
    print(f"{'='*55}")
    print(f"  {'Fold':<6} {'Test Subj':<12} {'S1 F1':>8} {'S2 F1':>8}")
    print(f"  {'-'*38}")
    for r in fold_results:
        print(f"  {r['fold']:<6} Subject{r['test_subj']:<5}    {r['s1_f1']:>8.4f} {r['s2_f1']:>8.4f}")
    print(f"  {'-'*38}")
    print(f"  {'Mean':<18}    {np.mean(s1_f1s):>8.4f} {np.mean(s2_f1s):>8.4f}")
    print(f"  {'Std':<18}    {np.std(s1_f1s):>8.4f} {np.std(s2_f1s):>8.4f}")
    print(f"\n  ST-GCN (Stage 1)         : {np.mean(s1_f1s):.4f} ± {np.std(s1_f1s):.4f}")
    print(f"  ST-GCN + Physics (Rescue): {np.mean(s2_f1s):.4f} ± {np.std(s2_f1s):.4f}")

    # aggregate confusion matrix
    agg_cm1 = np.sum([np.array(r["s1_cm"]) for r in fold_results], axis=0)
    agg_cm2 = np.sum([np.array(r["s2_cm"]) for r in fold_results], axis=0)
    print(f"\n  Aggregated confusion matrix (Stage 1):\n{agg_cm1}")
    print(f"\n  Aggregated confusion matrix (Two-stage):\n{agg_cm2}")

    with open(os.path.join(out_dir, "loso_summary.json"), "w") as f:
        json.dump({
            "folds": fold_results,
            "mean_s1_f1": float(np.mean(s1_f1s)),
            "std_s1_f1":  float(np.std(s1_f1s)),
            "mean_s2_f1": float(np.mean(s2_f1s)),
            "std_s2_f1":  float(np.std(s2_f1s)),
            "agg_cm_s1":  agg_cm1.tolist(),
            "agg_cm_s2":  agg_cm2.tolist(),
        }, f, indent=2)
    print(f"\n  Saved: {os.path.join(out_dir, 'loso_summary.json')}")
    print(f"  Log  : {log_path}")

    tee_file.close()
    sys.stdout = sys.__stdout__


if __name__ == "__main__":
    main()
