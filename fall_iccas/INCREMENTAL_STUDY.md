# Incremental data-size study — does physics help more with less data?

Two-stage detector trained on growing subject sets (subject-stratified split).
ΔF1 = Two-stage Fall F1 − Stage-1 Fall F1 = what the physics rescue adds.

| #Subj | Subjects | N test | S1 Acc | S1 F1 | 2S Acc | 2S F1 | ΔF1 (physics) | Rescue zone | Vel thr | Acc thr |
|:---:|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 1 | Subject 1 | 173 | 1.0000 | 1.0000 | 0.9884 | 0.9643 | -0.0357 | 0.15–0.30 | 0.02058 | 0.33960 |
| 2 | Subject 1–2 | 334 | 0.9820 | 0.9444 | 0.9820 | 0.9444 | +0.0000 | 0.45–0.50 | 0.02058 | 0.31373 |
| 3 | Subject 1–3 | 505 | 0.9683 | 0.8806 | 0.9802 | 0.9315 | +0.0509 | 0.10–0.30 | 0.02058 | 0.31373 |
| 4 | Subject 1–4 | 676 | 0.9689 | 0.8966 | 0.9689 | 0.8966 | +0.0000 | 0.50–0.55 | 0.00000 | 0.00000 |
| 5 | Subject 1–5 | 852 | 0.9800 | 0.9344 | 0.9800 | 0.9344 | +0.0000 | 0.50–0.55 | 0.00000 | 0.00000 |
| 6 | Subject 1–6 | 992 | 0.9849 | 0.9502 | 0.9899 | 0.9662 | +0.0160 | 0.75–0.80 | 0.00000 | 0.00000 |
| 7 | Subject 1–7 | 1167 | 0.9820 | 0.9408 | 0.9820 | 0.9405 | -0.0003 | 0.55–0.60 | 0.00000 | 0.00000 |
| 8 | Subject 1–8 | 1317 | 0.9924 | 0.9745 | 0.9901 | 0.9673 | -0.0072 | 0.40–0.45 | 0.00000 | 0.00000 |
| 9 | Subject 1–9 | 1489 | 0.9866 | 0.9558 | 0.9866 | 0.9556 | -0.0002 | 0.60–0.65 | 0.00000 | 0.00000 |
| 10 | Subject 1–10 | 1659 | 0.9885 | 0.9598 | 0.9867 | 0.9558 | -0.0040 | 0.05–0.30 | 0.00000 | 0.00000 |
| 11 | Subject 1–11 | 1833 | 0.9913 | 0.9711 | 0.9940 | 0.9799 | +0.0088 | 0.85–0.90 | 0.00000 | 0.00000 |
| 12 | Subject 1–12 | 2012 | 0.9836 | 0.9463 | 0.9906 | 0.9679 | +0.0216 | 0.85–0.90 | 0.00000 | 0.00000 |
| 13 | Subject 1–13 | 2180 | 0.9890 | 0.9635 | 0.9904 | 0.9673 | +0.0038 | 0.80–0.85 | 0.00000 | 0.00000 |
| 14 | Subject 1–14 | 2346 | 0.9847 | 0.9493 | 0.9855 | 0.9516 | +0.0023 | 0.65–0.70 | 0.00000 | 0.00000 |
| 15 | Subject 1–15 | 2514 | 0.9916 | 0.9712 | 0.9924 | 0.9739 | +0.0027 | 0.55–0.60 | 0.00000 | 0.00000 |
| 16 | Subject 1–16 | 2669 | 0.9846 | 0.9480 | 0.9843 | 0.9453 | -0.0027 | 0.65–0.70 | 0.00000 | 0.00000 |
| 17 | Subject 1–17 | 2837 | 0.9859 | 0.9532 | 0.9908 | 0.9686 | +0.0154 | 0.85–0.90 | 0.00000 | 0.00000 |

## What the data actually shows (honest reading)

This subject-stratified (subject-dependent) study does **not** cleanly support "physics helps more with less data":

1. **The velocity/acceleration physics goes inactive from 4 subjects onward.** For #Subj ≥ 4 the tuned Vel and Acc thresholds are both `0.00000` — meaning the physics check passes everything, so it does nothing. The ΔF1 gains that still appear at larger sizes (e.g. #Subj 11, 12, 17) come from the **rescue-zone probability threshold tuning**, not from velocity/acceleration.
2. **At small data (1–3 subjects) physics is active but noisy/inconsistent:** it *hurt* at #Subj 1 (−0.036), did nothing at 2, helped at 3 (+0.051). No clean trend.
3. **The subject-dependent ST-GCN is already saturated** (Fall F1 ≈ 0.94–1.0 even at 1 subject, on a tiny easy test set) — a ceiling that leaves almost no room for physics to add value.

**Takeaway.** On this clean, staged UP-Fall benchmark the velocity/acceleration filter does not measurably help once the model has data. Its likely real value is **deployment robustness** (live Jetson, unseen conditions/people) — which a clean offline benchmark cannot capture. To test the low-data thesis more fairly, evaluate in the **cross-subject (LOSO)** setting, where the base model is genuinely weaker, rather than subject-dependent where it is already near-perfect. This is an honest negative result and should shape how physics is framed in the paper (robustness / interpretability, not offline accuracy gains).

## Best case where physics helped: Subject 1–3

Where the velocity/acceleration physics is active (subjects 1–3), the clearest win is the 3-subject set. Test: 505 windows (75 fall / 430 no-fall).

| Model | Accuracy | Fall F1 | Precision | Recall | FP | FN |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| ST-GCN (model alone) | 0.9683 | 0.8806 | 1.000 | 0.787 | 0 | 16 |
| ST-GCN + Physics (2-stage) | 0.9802 | 0.9315 | 0.958 | 0.907 | 3 | 7 |

Physics rescue recovered **9 missed falls (FN 16 → 7)**, raising recall 0.79 → 0.91 and Fall F1 0.88 → 0.93, at the cost of only 3 false alarms (FP 0 → 3). In the low-data regime the data-starved ST-GCN misses falls; the physics filter catches them — the clearest illustration of the "physics helps when data is scarce" idea.

*Caveat: single run. In the same run, physics did not help at 1 subject (hurt, +2 FP) or 1–2 subjects (no change). Verify across multiple seeds before presenting this as a general claim.*
