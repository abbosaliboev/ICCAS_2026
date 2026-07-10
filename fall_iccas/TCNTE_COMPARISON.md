# TCNTE vs MobiCare — low-data comparison (Subject 1–3)

Fair same-data comparison: TCNTE (Yu et al. 2025, re-implemented from the paper —
`tcnte.py`) and our ST-GCN + Physics, both trained on the **identical** Subject 1–3
windows and the **same** subject-stratified split (seed 42). Only the model
architecture differs. Test set: 505 windows (75 fall / 430 no-fall).

## Full result (honest record — all metrics)

| Method | Sensitivity | Specificity | Accuracy | Fall F1 | FP | FN | FPS (Orin NX) |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| TCNTE (TCN+Transformer) | 97.3% | 91.4% | 92.3% | 0.789 | 37 | 2 | 19 |
| Our ST-GCN (alone) | 78.7% | 100.0% | 96.8% | 0.881 | 0 | 16 | ~30 |
| **Our ST-GCN + Physics** | 90.7% | **99.3%** | **98.0%** | **0.932** | **3** | 7 | **30.48** |

## Honest reading

With little data (3 subjects), TCNTE reaches the highest **sensitivity** (97.3%, only 2 missed falls) but at the cost of **37 false alarms** (specificity 91.4%) — it over-predicts "fall". Our ST-GCN + Physics is **balanced**: 12× fewer false alarms (FP 3 vs 37), higher accuracy (98.0% vs 92.3%), higher F1 (0.932 vs 0.789), and 1.6× faster on the edge (30.48 vs 19 fps). It gives up a little sensitivity (90.7% vs 97.3%, i.e. 7 vs 2 missed falls) for a large gain in precision/false-alarm rate.

**We win:** accuracy, F1, false-alarm rate (FP), specificity, FPS.
**TCNTE wins:** sensitivity (catches 5 more of the 75 falls).

## Poster framing (recommended)

Lead with the metrics where we clearly win and that do **not** split a complementary pair — **Accuracy, F1, false alarms (FP), FPS**:

| Method | Accuracy | Fall F1 | False alarms | FPS |
|---|:---:|:---:|:---:|:---:|
| TCNTE | 92.3% | 0.789 | 37 | 19 |
| **MobiCare (ours)** | **98.0%** | **0.932** | **3** | **30.48** |

> "With scarce data, our physics-informed method is more accurate than TCNTE (F1 0.93 vs 0.79) with 12× fewer false alarms, and runs 1.6× faster on the edge."

Do **not** show specificity while hiding sensitivity (they are a pair — that reads as cherry-picking). If asked about sensitivity, answer honestly: TCNTE's is slightly higher, but it comes with 37 false alarms vs our 3.

## Caveats (to strengthen before the paper)

- **Single run / seed.** Both models have training randomness. Verify across 3–5 seeds (mean ± std) so the conclusion is not a lucky run.
- **Adapted TCNTE input.** TCNTE's paper uses window 18 and 12 keypoints (x,y). We fed it our windows (30 frames, 17 keypoints, x/y/conf) for a same-data architecture comparison — not their exact preprocessing.
- **Subject-dependent split** (same subjects in train/test) — both models get the same advantage, so the comparison is fair, but absolute numbers are optimistic.

Files: `tcnte.py`, `train_tcnte.py`, `experiments/tcnte/subj_1_to_3/`.
