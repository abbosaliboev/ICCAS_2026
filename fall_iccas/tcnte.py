"""
Faithful re-implementation of TCNTE (Yu et al., 2025, Pervasive and Mobile
Computing 107:102016) — TCN + Transformer Encoder for skeleton fall detection.

Architecture from the paper (Table 2):
  TCN Block 1: 8 filters,  kernel 5, dilation 1
  TCN Block 2: 16 filters, kernel 5, dilation 2
  TCN Block 3: 32 filters, kernel 5, dilation 4
  each block = 2 stacked dilated *causal* convs (weight-norm, ReLU, dropout 0.2)
               + residual (1x1 conv for channel match)
  -> learnable positional encoding
  -> Transformer Encoder (multi-head attention, 4 heads, FF 32, dropout 0.1)
  -> mean over time
  -> Dense(32) + softmax (2 classes)

Also: weighted focal loss (Eq. 1-3), alpha = non-fall/fall ratio, gamma = 3.

We feed TCNTE the SAME windows as our ST-GCN (N, T, 17, 3) flattened to
(N, 17*3, T) so the comparison isolates the architecture, not the input.
"""

import torch
import torch.nn as nn
from torch.nn.utils import weight_norm


class _Chomp1d(nn.Module):
    """Trim the right-side padding so the conv stays causal."""
    def __init__(self, chomp): super().__init__(); self.chomp = chomp
    def forward(self, x): return x[:, :, :-self.chomp].contiguous() if self.chomp else x


class _TemporalBlock(nn.Module):
    def __init__(self, in_c, out_c, kernel=5, dilation=1, dropout=0.2):
        super().__init__()
        pad = (kernel - 1) * dilation
        self.net = nn.Sequential(
            weight_norm(nn.Conv1d(in_c, out_c, kernel, padding=pad, dilation=dilation)),
            _Chomp1d(pad), nn.ReLU(), nn.Dropout(dropout),
            weight_norm(nn.Conv1d(out_c, out_c, kernel, padding=pad, dilation=dilation)),
            _Chomp1d(pad), nn.ReLU(), nn.Dropout(dropout),
        )
        self.downsample = nn.Conv1d(in_c, out_c, 1) if in_c != out_c else None
        self.relu = nn.ReLU()

    def forward(self, x):
        out = self.net(x)
        res = x if self.downsample is None else self.downsample(x)
        return self.relu(out + res)


class TCNTE(nn.Module):
    def __init__(self, in_features=51, num_classes=2, window=30):
        super().__init__()
        self.tcn = nn.Sequential(
            _TemporalBlock(in_features, 8,  kernel=5, dilation=1),
            _TemporalBlock(8,          16, kernel=5, dilation=2),
            _TemporalBlock(16,         32, kernel=5, dilation=4),
        )
        self.pos = nn.Parameter(torch.zeros(1, window, 32))
        enc = nn.TransformerEncoderLayer(
            d_model=32, nhead=4, dim_feedforward=32, dropout=0.1, batch_first=True)
        self.transformer = nn.TransformerEncoder(enc, num_layers=1)
        self.fc = nn.Linear(32, num_classes)

    def forward(self, x):
        # x: (B, in_features, T)
        h = self.tcn(x)               # (B, 32, T)
        h = h.transpose(1, 2)         # (B, T, 32)
        h = h + self.pos[:, :h.size(1)]
        h = self.transformer(h)       # (B, T, 32)
        h = h.mean(dim=1)             # (B, 32)  — mean over sequence
        return self.fc(h)


class WeightedFocalLoss(nn.Module):
    """WFL (Lin et al. focal loss + class weight). alpha weights the fall class."""
    def __init__(self, alpha=30.0, gamma=3.0):
        super().__init__()
        self.alpha = alpha
        self.gamma = gamma

    def forward(self, logits, target):
        logp = torch.log_softmax(logits, dim=-1)
        logpt = logp.gather(1, target.unsqueeze(1)).squeeze(1)
        pt = logpt.exp()
        at = torch.where(target == 1,
                         torch.as_tensor(self.alpha, device=logits.device, dtype=logits.dtype),
                         torch.as_tensor(1.0, device=logits.device, dtype=logits.dtype))
        loss = -at * (1 - pt) ** self.gamma * logpt
        return loss.mean()
