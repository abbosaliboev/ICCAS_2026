# Training Results History / 학습 결과 기록 / Training Natijalari Tarixi

> **Language / 언어 / Til**
> - [🇺🇸 English](#english)
> - [🇰🇷 한국어](#korean)
> - [🇺🇿 O'zbekcha](#uzbek)

---

<a name="english"></a>
# 🇺🇸 English

## Current best result (Subject 1+2+3+4, subject-stratified split)

**Date:** 2026-06-14
**Dataset:** Subject 1+2+3+4 — X.npy shape (4479, 30, 17, 3)
**Split:** Subject-stratified 70/15/15 (train=3134, val=670, test=675)
**Each subject:** ~800 train / ~170 val / ~170 test

| Model | Accuracy | Fall F1 | Precision | Recall | FP | FN |
|---|---|---|---|---|---|---|
| ST-GCN (Stage 1) | 98.5% | 0.950 | 0.95 | 0.95 | 5 | 5 |
| ST-GCN + Physics Rescue | 98.7% | **0.955** | 0.95 | 0.96 | 5 | 4 |

Confusion matrix (test set, 675 samples):
```
              Pred NO-FALL  Pred FALL
True NO-FALL      571           5      (5 FP)
True FALL           4          95      (4 FN)
```

Tuned thresholds:
- `stage1_threshold = 0.50`
- `rescue_threshold = 0.45`
- `vel_threshold = 0.0237`
- `acc_threshold = 0.0`

Saved to: `experiments/subject1_2_3_4/`

## Previous best result (Subject 1 only, subject-dependent)

**Date:** 2026-06-11
**Dataset:** Subject 1 only — X.npy shape (1145, 30, 17, 3)
**Split:** 70/15/15 stratified (train=801, val=172, test=172)

| Model | Accuracy | Fall F1 | Precision | Recall | FP | FN |
|---|---|---|---|---|---|---|
| ST-GCN (Stage 1) | 98.8% | **0.960** | 0.96 | 0.96 | 1 | 1 |
| ST-GCN + Physics Rescue | 98.8% | **0.960** | 0.96 | 0.96 | 1 | 1 |

Confusion matrix (test set, 172 samples):
```
              Pred NO-FALL  Pred FALL
True NO-FALL      146           1      (1 FP)
True FALL           1          24      (1 FN)
```

Tuned thresholds:
- `stage1_threshold = 0.55`
- `rescue_threshold = 0.50`
- `vel_threshold = 0.0354`
- `acc_threshold = 0.3545`

## Ablation study (Subject 1+2+3+4, test set n=675)

What each component contributes:

| Configuration | Fall F1 | Precision | Recall | FP | FN | Notes |
|---|:---:|:---:|:---:|:---:|:---:|---|
| ST-GCN alone (Stage 1) | 0.950 | 0.95 | 0.95 | 5 | 5 | Baseline |
| Physics filter alone | — | — | — | — | — | Not standalone (needs Stage 1 score) |
| ST-GCN + Physics AND (old) | ~0.864* | — | — | — | — | Physics vetoes correct detections |
| **ST-GCN + Physics Rescue (new)** | **0.955** | **0.95** | **0.96** | **5** | **4** | Physics only adds, never removes |

> *AND logic result from Run 2 (Subject 1 only). Cross-subject AND result not measured.
> Physics Rescue contribution: rescued 1 FN → FN 5→4 (+1 recall, same precision).

## Comparison with expected baselines (TODO)

| Model | Expected Fall F1 | Status |
|---|:---:|---|
| LSTM (flat keypoints) | ~0.80–0.88 | ⬜ not yet implemented |
| TCN (flat keypoints) | ~0.85–0.90 | ⬜ not yet implemented |
| ST-GCN alone | **0.950** | ✅ done |
| **ST-GCN + Physics Rescue** | **0.955** | ✅ done |

## Run history

### Run 7 — 2026-06-14 (Subject 1+2+3+4, subject-stratified split)
What's new:
- Added Subject 4 (1.62m, 71kg — between Subject 2 and Subject 3)
- Fixed split: subject-stratified 70/15/15 (each subject equally in all splits)
- F1 improved vs 3 subjects: 0.943 → 0.955 (more data helps!)
- Physics Rescue caught 1 additional fall (FN 5→4)
- Early stopping at epoch 48 (best val F1=0.970 at epoch ~33)

| Model | Fall F1 |
|---|---|
| ST-GCN Stage 1 | 0.950 |
| ST-GCN + Physics Rescue | **0.955** |

Saved to: `experiments/subject1_2_3_4/`

### Run 6 — 2026-06-14 (Subject 1+2+3, early stopping fixed)
What's new:
- Early stopping (patience=15) added to prevent overfitting
- Training stopped at epoch 50 (best val F1=0.993 at epoch ~35)
- F1 recovered from 0.686 → 0.943

| Model | Fall F1 |
|---|---|
| ST-GCN Stage 1 | **0.943** |
| ST-GCN + Physics Rescue | **0.943** |

Confusion matrix (test, 503 samples):
```
              Pred NO-FALL  Pred FALL
True NO-FALL      429           3    (3 FP)
True FALL           5          66    (5 FN)
```

Note: Physics Rescue didn't add further improvement — Stage 1 already well-calibrated.
Saved to: `experiments/subject1_2_3/`

### Run 5 — 2026-06-13 (Subject 1+2+3, no early stopping — FAILED RUN)
- Overfitting: val F1 peaked at epoch 20 (0.640) then collapsed to 0.278
- F1 = 0.686 (two-stage) — result of overfitting, not true generalization
- Lesson: early stopping is mandatory for cross-subject training

### Run 4 — 2026-06-13 (Subject 1+2, 2 subjects)
What's new:
- Added Subject 2 to training data (2210 sequences total, was 1145)
- Physics Rescue now actively helps: FP 7→4 (unlike Subject1-only where rescue was never triggered)
- Stage 1 recall = 1.00 (zero missed falls)

| Model | Fall F1 |
|---|---|
| ST-GCN Stage 1 | 0.931 |
| ST-GCN + Physics Rescue | **0.948** |

Note: F1 slightly lower than Subject1-only (0.960) — expected since cross-subject generalization is harder.
Saved to: `experiments/subject1_2/`

### Run 3 — 2026-06-11 (Physics Rescue + Zero-frame fix)
What's new:
- `conf=0.1` + forward-fill interpolation: zero frames 14.5% → **0%**
- Physics "Rescue" logic: `prob >= t1 → FALL`, `t_rescue <= prob < t1 → physics decides`
- Replaces the old AND logic: physics now only ADDS, never removes

| Model | Fall F1 |
|---|---|
| ST-GCN Stage 1 | **0.960** |
| ST-GCN + Physics Rescue | **0.960** |

Note: Rescue zone [0.50, 0.55) — Stage 1 was so good that rescue was never needed.

### Run 2 — 2026-06-11 (Zero-frame fix, old physics)
What's new: zero frames fixed with `conf=0.1` + interpolation

| Model | Fall F1 |
|---|---|
| ST-GCN Stage 1 | 0.913 |
| ST-GCN + Physics (AND) | **0.864** ← physics is harmful! |

Note: The physics AND logic deleted even correct Stage 1 detections (Stage 1 precision was 1.00).

### Run 1 — 2026-06-10 (Initial result)
Dataset: with the zero-frame problem (14.5% zero frames in fall sequences)

| Model | Accuracy | Fall F1 |
|---|---|---|
| ST-GCN Stage 1 | 93.6% | 0.718 |
| ST-GCN + Physics (AND) | 95.9% | **0.837** |

Note: Recall was low (0.56) due to zero frames. The physics AND logic helped here because there were many FPs.

## Improvement analysis

```
Run 1 → Run 2: Zero-frame fix
  Fall F1: 0.718 → 0.913  (+0.195)  ← biggest impact
  Reason: YOLO conf=0.1 + interpolation

Run 2 → Run 3: Physics Rescue logic
  Fall F1: 0.913 → 0.960  (+0.047)
  Reason: physics no longer removes detections

Run 3 → Run 4: Cross-subject generalization (Subject 1+2)
  Fall F1: 0.960 → 0.948  (-0.012)
  Reason: expected drop, harder task; physics helps with FP

Run 4 → Run 5: FAILED — overfitting without early stopping
  Fall F1: 0.948 → 0.686  (lesson: early stopping required)

Run 5 → Run 6: Early stopping fixed (Subject 1+2+3)
  Fall F1: 0.686 → 0.943  (+0.257)
  Reason: early stopping prevents collapse

Run 6 → Run 7: More data (Subject 1+2+3+4)
  Fall F1: 0.943 → 0.955  (+0.012)
  Reason: more training subjects improve generalization
```

## Expected future results

| Scenario | Expected Fall F1 |
|---|---|
| Subject 1-4 (current, subject-dependent) | 0.955 |
| Subject 1-17, subject-dependent | ~0.95+ |
| Subject 1-17, LOSO cross-subject | ~0.75-0.88 |

> The LOSO result represents real-world performance and is required for the paper.

## Baseline models (needed for the paper)

- [ ] LSTM baseline
- [ ] TCN baseline
- [ ] ST-GCN alone (without physics) — already available
- [ ] ST-GCN + Physics AND (old logic) — already available
- [ ] **ST-GCN + Physics Rescue (new logic)** — already available

---

### Run 8 — 2026-07-04 (Subject 1+2+3+4+5, subject-stratified split)

What's new:
- Added Subject 5 (5 subjects total, 5647 sequences)
- Fixed random seed (SEED=42) for reproducibility
- Flash/MemEfficient SDPA disabled for CUDA stability on Windows WDDM
- Physics Rescue: no additional effect — Stage 1 already well-calibrated (rescue zone [0.50, 0.55) not triggered)
- Early stopping at epoch 32 (best val Fall F1=0.9484)

| Model | Fall F1 |
|---|---|
| ST-GCN Stage 1 | 0.9278 |
| ST-GCN + Physics Rescue | **0.9278** |

Confusion matrix (test, 851 samples):
```
              Pred NO-FALL  Pred FALL
True NO-FALL      710          16      (16 FP)
True FALL           3         122      ( 3 FN)
```
Saved to: `experiments/subject1_2_3_4_5/`



---

### Run 9 — 2026-07-04 (LOSO, Subject 1–5, cross-subject)

**Evaluation:** Leave-One-Subject-Out (5 folds)
**Data:** Same cv_dataset as Run 8 (5647 sequences, subjects 1–5)

Per-fold Fall F1:

| Fold | Test Subject | ST-GCN F1 | Two-stage F1 |
|---|---|---|---|
| 1 | Subject 1 | 0.6080 | 0.6031 |
| 2 | Subject 2 | 0.4733 | 0.4879 |
| 3 | Subject 3 | 0.6893 | 0.6634 |
| 4 | Subject 4 | 0.5507 | 0.5775 |
| 5 | Subject 5 | 0.5479 | 0.5447 |
| **Mean** | | **0.5738 ± 0.072** | **0.5753 ± 0.059** |

Aggregated confusion matrix (Two-stage, all folds):
```
              Pred NO-FALL  Pred FALL
True NO-FALL     4061         792      (792 FP)
True FALL         158         636      (158 FN)
```

Key observations:
- Physics Rescue catches 10 additional falls vs Stage 1 alone (FN 168→158) with virtually no extra FP (791→792)
- This matches real-world observation: physics filter helps even when ST-GCN struggles
- LOSO F1 (0.575) vs subject-dependent F1 (0.928) gap shows cross-subject generalization challenge
- Consistent with UP-Fall literature: LOSO is significantly harder than subject-dependent evaluation

Saved to: `experiments/subject1_2_3_4_5/loso/`



---

### Run 10 — 2026-07-06 (Subject 1–10, subject-dependent)

**Dataset:** Subject 1–10 — X.npy shape (10992, 30, 17, 3)
**Split:** Subject-stratified ~70/15/15 (train=7693, val=1657, test=1658)
**Seed:** 42

| Model | Accuracy | Fall F1 | Precision | Recall | FP | FN |
|---|---|---|---|---|---|---|
| ST-GCN (Stage 1) | 98.5% | 0.9507 | 0.91 | 0.99 | 23 | 2 |
| ST-GCN + Physics Rescue | 99.0% | **0.9675** | 0.96 | 0.98 | 11 | 5 |

Physics Rescue cut FP from 23 → 11 (−52%) at cost of only 3 extra FN. Strongest rescue effect seen so far.

Saved to: `experiments/subject1_to_10/`

---

### Run 11 — 2026-07-06 (LOSO, Subject 1–10, cross-subject)

**Evaluation:** Leave-One-Subject-Out (10 folds)

Per-fold Fall F1:

| Fold | Test Subj | ST-GCN F1 | Two-stage F1 |
|---|---|---|---|
| 1 | Subject 1 | 0.7629 | 0.7453 |
| 2 | Subject 2 | 0.6161 | 0.6164 |
| 3 | Subject 3 | 0.5703 | 0.5885 |
| 4 | Subject 4 | 0.6667 | 0.6269 |
| 5 | Subject 5 | 0.5265 | 0.5378 |
| 6 | Subject 6 | 0.4604 | 0.4615 |
| 7 | Subject 7 | 0.6332 | 0.6213 |
| 8 | Subject 8 | 0.7604 | 0.7579 |
| 9 | Subject 9 | 0.5709 | 0.5891 |
| 10 | Subject 10 | 0.6604 | 0.6603 |
| **Mean** | | **0.6228 ± 0.091** | **0.6205 ± 0.084** |

Aggregated confusion matrix (Stage 1, all 10 folds):
```
              Pred NO-FALL  Pred FALL
True NO-FALL     7972        1455      (1455 FP)
True FALL         216        1349      ( 216 FN)
Recall = 86.2%   Accuracy = 84.8%
```

Key observations:
- 5→10 subjects improves LOSO F1: 0.574 → 0.623 (+0.049) — more training data helps
- Physics Rescue shows mixed results in LOSO (helps folds 3,5,9; hurts 1,4,7) — physics thresholds tuned per-fold on val subjects do not always generalise
- In subject-dependent setting, Rescue cuts FP by 52% (23→11); in cross-subject it is less reliable
- LOSO Recall=86.2%: model detects ~6 out of 7 falls even for completely unseen subjects

Saved to: `experiments/subject1_to_10/loso/`

---

### Run 12 — 2026-07-07 (LOSO, Subject 1–17, cross-subject) — FULL DATASET

**Evaluation:** Leave-One-Subject-Out (17 folds). Full UP-Fall dataset (18,823 windows, FALL=2,688 / NO-FALL=16,135). This is the primary paper result.

Per-fold Fall F1:

| Fold | Test Subj | ST-GCN F1 | Two-stage F1 |
|---|---|---|---|
| 1 | Subject 1 | 0.6810 | 0.6777 |
| 2 | Subject 2 | 0.5619 | 0.5720 |
| 3 | Subject 3 | 0.5905 | 0.5905 |
| 4 | Subject 4 | 0.7397 | 0.7055 |
| 5 | Subject 5 | 0.5866 | 0.5962 |
| 6 | Subject 6 | 0.5674 | 0.5481 |
| 7 | Subject 7 | 0.6323 | 0.7404 |
| 8 | Subject 8 | 0.7493 | 0.6986 |
| 9 | Subject 9 | 0.6012 | 0.6073 |
| 10 | Subject 10 | 0.6286 | 0.6368 |
| 11 | Subject 11 | 0.5641 | 0.5685 |
| 12 | Subject 12 | 0.6469 | 0.7665 |
| 13 | Subject 13 | 0.6009 | 0.5982 |
| 14 | Subject 14 | 0.4786 | 0.4556 |
| 15 | Subject 15 | 0.6667 | 0.6667 |
| 16 | Subject 16 | 0.6195 | 0.6195 |
| 17 | Subject 17 | 0.5652 | 0.5786 |
| **Mean** | | **0.6165 ± 0.0654** | **0.6251 ± 0.0750** |

Aggregated confusion matrices (all 17 folds):
```
Stage 1 (ST-GCN)                Two-stage (Physics Rescue)
              Pred NF   Pred F                 Pred NF   Pred F
True NO-FALL  13470     2665     True NO-FALL  13793     2342
True FALL       327     2361     True FALL       428     2260
Recall=87.8% Prec=47.0%          Recall=84.1% Prec=49.1%
Acc=84.1%                        Acc=85.3%
```

Key observations:
- **Precision is the bottleneck, not recall.** Stage 1 misses only 327/2688 falls (recall 87.8%) but raises 2665 false positives (precision 47.0%). F1 is dragged down almost entirely by FP on unseen subjects.
- 10→17 subjects did **not** improve LOSO F1 (0.623→0.617 Stage 1) — performance has plateaued; the ceiling is precision/generalization, not training-data volume.
- **Heavy-interpolation hypothesis rejected:** S12/S15 (Activity 11 mostly zero-frame on Camera1) were among the *best* folds (0.77 / 0.67), so YOLO detection dropout on lying poses is not the main F1 driver.
- Worst folds: S14 (0.48), S6 (0.55), S2/S11/S17 (~0.56–0.57) — all dominated by false positives, not missed falls.
- Physics Rescue is mixed: strongly helps S7 (0.63→0.74) and S12 (0.65→0.77), hurts S8 (0.75→0.70) and S14 (0.48→0.46). Net +0.009 F1 — marginal, because per-fold physics thresholds tuned on val subjects don't always transfer.

Per-activity FP breakdown (analyze_loso.py, baseline thr=0.5, aggregated over 17 folds):

| ADL activity | FP | windows | FP rate |
|---|---|---|---|
| A6 walking | 89 | 3559 | 2.5% |
| A7 standing | 26 | 3529 | 0.7% |
| A8 sitting | 0 | 3506 | 0.0% |
| A9 picking-object | 2 | 515 | 0.4% |
| A10 jumping | 0 | 1704 | 0.0% |
| **A11 laying** | **2548** | **3322** | **76.7%** |

**Decisive finding: 2548 of 2665 false positives (96%) come from Activity 11 (laying down).** The vertical→horizontal transition of voluntarily lying on a bed is nearly indistinguishable from a fall in pose space, so ST-GCN flags it. This is the entire precision problem.

Post-processing levers do NOT fix it (analyze_loso.py, thr + min-run-length tuned on val, applied to test): mean F1 0.6165 → 0.6236 (+0.007 only). Temporal voting selected r=1 on every fold because A11 false alarms are *sustained runs* (the whole lay-down segment), not isolated spikes — run-length filtering cannot remove them. Threshold tuning was noisy (helped S7 +0.12/S12 +0.10, hurt S8 −0.07/S4 −0.03), a val-overfit wash.

**Kinematic veto tested and rejected (veto_experiment.py, feature_separability.py).** Peak-velocity distributions of true falls and A11 laying overlap completely (fall P50=0.138 vs A11 P50=0.087; at P90 A11=1.72 *exceeds* fall=1.22). An oracle single-feature threshold (tuned directly on data — an upper bound) separates fall-vs-A11 only weakly:

| feature | oracle acc | AUC |
|---|---|---|
| max_velocity | 0.604 | 0.589 |
| max_abs_acc | 0.577 | 0.572 |
| hip_drop | 0.614 | 0.608 |
| (majority baseline) | 0.553 | — |

All near-random (AUC≈0.5). A val-tuned velocity veto removed only 18 FP / lost 5 falls (F1 +0.001). **Conclusion: no kinematic feature on the frontal Camera1 view can distinguish controlled laying from falling** — the information is not present in a single frontal viewpoint. This empirically confirms CLAUDE.md's warning against physics veto and, more importantly, explains it.

Next steps:
- **Second camera (Camera2) — the principled fix.** A second viewpoint provides the vertical-descent information the frontal view lacks, which should disambiguate laying from falling (the source of 96% of FP). All Camera2 data is downloaded. Plan: extract Camera2 keypoints, run LOSO on Camera2 alone first (cheapest test of whether the second view helps), then two-camera fusion (concatenate/two-stream) for the final model. Hypothesis, to be verified — not guaranteed.
- Add LSTM/TCN baselines for the paper comparison table.

Saved to: `experiments/subject1_to_17/loso/` (loso_results.txt, loso_summary.json)

---

### Run 13 — 2026-07-07 (Camera2 pilot, 3 folds) — motivates two-camera fusion

Camera2 (second viewpoint) keypoints extracted for all 17 subjects (18,823 windows, identical to Camera1). Notably, Camera2 had almost no zero-frame interpolation on A11 laying (Camera1 lost 600–1000+ frames/trial there) — the second view sees lying people far better.

Kinematic separability on Camera2 is still near-random (velocity AUC 0.537, accel 0.528, drop 0.570) — a kinematic veto cannot work on either view. But the ST-GCN itself uses full skeleton geometry, so a pilot LOSO on the 3 worst Camera1 folds (S11, S14, S17) was run on Camera2:

| Test subj | Camera1 S1 F1 | Camera2 S1 F1 | Δ |
|---|---|---|---|
| S11 | 0.564 | 0.494 | −0.070 |
| S14 | 0.479 | 0.614 | +0.135 |
| S17 | 0.565 | 0.687 | +0.122 |
| mean | 0.536 | 0.598 | +0.062 |

Aggregate over the 3 folds: false positives **603 → 365 (−39%)**, precision **39.8% → 49.4%**, recall 82.9% → 74.2%. Camera2 attacks the precision problem but loses some recall.

**Complementary errors across views (the key finding):**
- Camera1 FP: A11 laying = 76.7% rate (96% of all FP); walking/jumping ≈ 0.
- Camera2 FP: A11 laying rate drops to 33.9%, but new FP appear on A6 walking (13%), A10 jumping (11%), A7 standing (5.8%).

The two views fail on *different* activities, so score-level fusion (Camera1's recall + Camera2's precision, combined per-window and tuned on val) is expected to beat either camera alone. This is the planned primary contribution.

Next: full 17-fold Camera2 LOSO, then two-camera score-level fusion (both datasets share identical window ordering, so per-window probabilities can be fused directly).

Saved to: `experiments/subject1_to_17_cam2/loso_pilot/`

---

### Run 14 — 2026-07-07 (Two-camera score-level fusion, 17-fold LOSO) — MAIN RESULT

Full Camera2 LOSO (all 17 folds) then score-level fusion of Camera1 + Camera2 per-window fall probabilities. Fusion rule (weighted-avg / AND / OR) tuned on val per fold, applied to held-out test subject. `fuse_cameras.py`.

| Metric | Camera1 (front) | Camera2 (side) | **Fusion** |
|---|---|---|---|
| mean Fall F1 | 0.6165 | 0.5178 | **0.6772** |
| aggregate F1 | 0.612 | 0.502 | **0.671** |
| Precision | 0.470 | 0.395 | **0.592** |
| Recall | 0.878 | 0.689 | 0.775 |
| Specificity | 0.835 | 0.825 | **0.911** |
| Accuracy | 0.841 | 0.805 | **0.892** |
| FP | 2665 | 2831 | **1438** |
| FN | 327 | 837 | 604 |

**Key result: two-camera fusion cuts false positives by 46% (2665→1438) and raises precision 0.47→0.59, specificity 0.84→0.91, accuracy 0.84→0.89, and Fall F1 0.62→0.68 — all under strict 17-fold LOSO.** The A11 laying false positives (96% of Camera1 FP) are largely removed because a fall must now be plausible from *both* viewpoints.

Notes:
- Camera2 (side view) ALONE is worse than Camera1 (front): F1 0.52 vs 0.62, consistent with UP-Fall literature (front view has fewer occlusions). Its value is purely complementary — fusion, not replacement.
- Tradeoff: recall drops 87.8%→77.5% (FN 327→604). Fusion trades some sensitivity for large precision/false-alarm gains — appropriate for deployment (alarm fatigue), but the missed-fall rate should be reported honestly.
- Fusion beats both cameras on ~11/17 folds; loses to Camera1 on S1/S4/S8 (where Camera1 was already strong and the weak Camera2 dragged the average down).
- Weighted-average was the winning rule on 16/17 folds (AND on S16 only).

Saved to: `experiments/subject1_to_17_cam2/loso/fuse_cameras.json`

---

### Run 15 — 2026-07-07 (Subject 1–17, subject-stratified split) — POSTER HEADLINE

Full 17-subject dataset, subject-stratified 70/15/15 (each subject proportionally in train/val/test — subject-DEPENDENT, the protocol most UP-Fall papers use; NOT LOSO). `train_two_stage.py`. Test n=2837 (414 fall).

| Model | Accuracy | Fall F1 | Precision | Recall | FP | FN |
|---|---|---|---|---|---|---|
| ST-GCN (Stage 1) | 0.9873 | 0.9578 | 0.93 | 0.99 | 31 | 5 |
| **ST-GCN + Physics (2-Stage)** | **0.9919** | **0.9723** | 0.97 | 0.97 | 12 | 11 |

Two-stage confusion: `[[2411 12] [11 403]]` → Sensitivity 97.3%, Specificity 99.5%.

Notes:
- **This is the poster/benchmark-table number** — comparable protocol to most UP-Fall papers (subject-mixed). Competitive with the field: Ramirez 99.3% acc, TCNTE 99.58%, Inturi 98.59%; our Sensitivity 97.3% exceeds TCNTE's 95.4%.
- Physics rescue helped here: F1 0.9578→0.9723, false alarms 31→12 (−61%), at the cost of a few more FN (5→11). Net precision 0.93→0.97.
- Model size: ST-GCN ~3.1M params (larger than TCNTE's 14.7k) — but still real-time on Jetson Orin NX (see FPS_BENCHMARK.md).
- Honest caveat vs Run 14: this subject-DEPENDENT 0.97 is easier than the subject-INDEPENDENT LOSO (fusion 0.68). Both recorded; poster leads with this, LOSO kept for a future rigorous paper.

Saved to: `experiments/subject1_to_17/two_stage/`

<a name="korean"></a>
# 🇰🇷 한국어

## 현재 최고 결과 (Subject 1+2+3+4, subject-stratified split)

**날짜:** 2026-06-14
**데이터셋:** Subject 1+2+3+4 — X.npy shape (4479, 30, 17, 3)
**Split:** Subject-stratified 70/15/15 (train=3134, val=670, test=675)
**각 피험자:** ~800 train / ~170 val / ~170 test

| 모델 | Accuracy | Fall F1 | Precision | Recall | FP | FN |
|---|---|---|---|---|---|---|
| ST-GCN (Stage 1) | 98.5% | 0.950 | 0.95 | 0.95 | 5 | 5 |
| ST-GCN + Physics Rescue | 98.7% | **0.955** | 0.95 | 0.96 | 5 | 4 |

Confusion matrix (test set, 675 샘플):
```
              Pred NO-FALL  Pred FALL
True NO-FALL      571           5      (5 FP)
True FALL           4          95      (4 FN)
```

튜닝된 임계값:
- `stage1_threshold = 0.50`
- `rescue_threshold = 0.45`
- `vel_threshold = 0.0237`
- `acc_threshold = 0.0`

저장 위치: `experiments/subject1_2_3_4/`

## 이전 최고 결과 (Subject 1, subject-dependent)

**날짜:** 2026-06-11
**Fall F1:** ST-GCN 0.960 → ST-GCN + Physics Rescue **0.960**

## Ablation study (Subject 1+2+3+4, 테스트셋 n=675)

각 구성 요소의 기여도:

| 구성 | Fall F1 | Precision | Recall | FP | FN | 비고 |
|---|:---:|:---:|:---:|:---:|:---:|---|
| ST-GCN 단독 (Stage 1) | 0.950 | 0.95 | 0.95 | 5 | 5 | Baseline |
| ST-GCN + Physics AND (구형) | ~0.864* | — | — | — | — | physics가 올바른 감지를 삭제 |
| **ST-GCN + Physics Rescue (신형)** | **0.955** | **0.95** | **0.96** | **5** | **4** | physics가 추가만 함 |

> *AND 로직 결과는 Run 2 (Subject 1 only) 기준.
> Physics Rescue 기여: FN 1개 추가 감지 (5→4), precision 유지.

## 기대 Baseline 비교 (TODO)

| 모델 | 기대 Fall F1 | 상태 |
|---|:---:|---|
| LSTM (flat keypoints) | ~0.80–0.88 | ⬜ 미구현 |
| TCN (flat keypoints) | ~0.85–0.90 | ⬜ 미구현 |
| ST-GCN 단독 | **0.950** | ✅ 완료 |
| **ST-GCN + Physics Rescue** | **0.955** | ✅ 완료 |

## 결과 기록

### Run 7 — 2026-06-14 (Subject 1+2+3+4, subject-stratified split)
변경 사항:
- Subject 4 추가 (1.62m, 71kg)
- Subject-stratified 분할 적용: 각 피험자가 train/val/test에 균등 포함
- Physics Rescue가 FN 1개 추가 감지 (5→4)
- Early stopping: epoch 48에서 종료 (best val F1=0.970, epoch ~33)

| 모델 | Fall F1 |
|---|---|
| ST-GCN Stage 1 | 0.950 |
| ST-GCN + Physics Rescue | **0.955** |

### Run 6 — 2026-06-14 (Subject 1+2+3, early stopping 추가)
변경 사항:
- Early stopping (patience=15) 추가로 과적합 방지
- Training: epoch 50에서 종료 (best val F1=0.993, epoch ~35)
- F1 회복: 0.686 → 0.943

| 모델 | Fall F1 |
|---|---|
| ST-GCN Stage 1 | **0.943** |
| ST-GCN + Physics Rescue | **0.943** |

비고: Physics Rescue가 추가 개선 없음 — Stage 1이 이미 잘 보정됨.

### Run 5 — 2026-06-13 (Subject 1+2+3, early stopping 없음 — 실패 실험)
- 과적합: val F1이 epoch 20 (0.640)에서 최고, 이후 0.278로 붕괴
- F1 = 0.686 — 교차 피험자 학습 시 early stopping 필수

### Run 4 — 2026-06-13 (Subject 1+2, 2명)
변경 사항:
- Subject 2 추가 (2210 시퀀스, 기존 1145에서 증가)
- Physics Rescue 효과 확인: FP 7→4

| 모델 | Fall F1 |
|---|---|
| ST-GCN Stage 1 | 0.931 |
| ST-GCN + Physics Rescue | **0.948** |

### Run 3 — 2026-06-11 (Physics Rescue + Zero-frame 수정)
변경 사항:
- `conf=0.1` + forward-fill 보간으로 zero frame 14.5% → **0%**
- Physics "Rescue" 로직: physics는 이제 추가만 하고, 제거하지 않음

| 모델 | Fall F1 |
|---|---|
| ST-GCN Stage 1 | **0.960** |
| ST-GCN + Physics Rescue | **0.960** |

### Run 2 — 2026-06-11 (Zero-frame 수정)

| 모델 | Fall F1 |
|---|---|
| ST-GCN Stage 1 | 0.913 |
| ST-GCN + Physics (AND) | **0.864** ← physics가 해로움! |

### Run 1 — 2026-06-10 (초기 결과)

| 모델 | Accuracy | Fall F1 |
|---|---|---|
| ST-GCN Stage 1 | 93.6% | 0.718 |
| ST-GCN + Physics (AND) | 95.9% | **0.837** |

### 실행 8 — 2026-07-04 (Subject 1+2+3+4+5, subject-stratified split)

변경 사항:
- Subject 5 추가 (총 5명, 5647 시퀀스)
- 랜덤 시드 고정 (SEED=42)
- Flash/MemEfficient SDPA 비활성화 (Windows WDDM CUDA 안정성)
- Physics Rescue: Stage 1이 이미 충분히 정확하여 추가 효과 없음
- Early stopping: epoch 32에서 종료 (best val Fall F1=0.9484)

| 모델 | Fall F1 |
|---|---|
| ST-GCN Stage 1 | 0.9278 |
| ST-GCN + Physics Rescue | **0.9278** |

혼동 행렬 (테스트, 851 샘플):
```
              Pred NO-FALL  Pred FALL
True NO-FALL      710          16      (16 FP)
True FALL           3         122      ( 3 FN)
```
저장 위치: `experiments/subject1_2_3_4_5/`

### 실행 9 — 2026-07-04 (LOSO, Subject 1–5, 교차 피험자)

**평가 방식:** Leave-One-Subject-Out (5-fold)

| 폴드 | 테스트 피험자 | ST-GCN F1 | 2단계 F1 |
|---|---|---|---|
| 1 | Subject 1 | 0.6080 | 0.6031 |
| 2 | Subject 2 | 0.4733 | 0.4879 |
| 3 | Subject 3 | 0.6893 | 0.6634 |
| 4 | Subject 4 | 0.5507 | 0.5775 |
| 5 | Subject 5 | 0.5479 | 0.5447 |
| **평균** | | **0.5738 ± 0.072** | **0.5753 ± 0.059** |

주요 관찰:
- Physics Rescue가 LOSO에서도 효과적: FN 168→158 (낙상 10개 추가 감지), FP 거의 동일 (791→792)
- 실사용(Jetson) 환경에서의 physics 필터 효과를 정량적으로 확인
- subject-dependent(0.928) vs LOSO(0.575) 차이: 교차 피험자 일반화의 어려움 반영

저장 위치: `experiments/subject1_2_3_4_5/loso/`

### 실행 10 — 2026-07-06 (Subject 1–10, subject-dependent)

**데이터셋:** Subject 1–10 — 총 10992 시퀀스

| 모델 | Accuracy | Fall F1 | FP | FN |
|---|---|---|---|---|
| ST-GCN (Stage 1) | 98.5% | 0.9507 | 23 | 2 |
| ST-GCN + Physics Rescue | 99.0% | **0.9675** | 11 | 5 |

Physics Rescue가 FP를 52% 감소 (23→11). 역대 가장 큰 효과.

### 실행 11 — 2026-07-06 (LOSO, Subject 1–10, 교차 피험자)

| 폴드 | 테스트 | ST-GCN F1 | 2단계 F1 |
|---|---|---|---|
| 평균 | | **0.6228 ± 0.091** | **0.6205 ± 0.084** |

주요 관찰:
- 5→10 피험자로 LOSO F1 개선: 0.574 → 0.623
- Physics Rescue: subject-dependent에서는 FP 52% 감소, LOSO에서는 혼재된 결과
- LOSO Recall=86.2%: 미확인 피험자에서도 7번 중 6번 낙상 감지

## 향후 예상 결과

| 시나리오 | 예상 Fall F1 |
|---|---|
| Subject 1-4 (현재, subject-dependent) | 0.955 |
| Subject 1-17, subject-dependent | ~0.95+ |
| Subject 1-17, LOSO cross-subject | ~0.75-0.88 |

> LOSO 결과가 실제 real-world 성능 지표이며 논문에 필요합니다.

## Baseline 모델 (논문에 추가 필요)

- [ ] LSTM baseline
- [ ] TCN baseline
- [ ] ST-GCN alone (physics 없이) — 이미 보유
- [ ] ST-GCN + Physics AND (기존 로직) — 이미 보유
- [ ] **ST-GCN + Physics Rescue (신규 로직)** — 이미 보유

---

<a name="uzbek"></a>
# 🇺🇿 O'zbekcha

## Hozirgi eng yaxshi natija (Subject 1+2+3+4, subject-stratified split)

**Sana:** 2026-06-14
**Dataset:** Subject 1+2+3+4 — X.npy shape (4479, 30, 17, 3)
**Split:** Subject-stratified 70/15/15 (train=3134, val=670, test=675)
**Har bir subject:** ~800 train / ~170 val / ~170 test

| Model | Accuracy | Fall F1 | Precision | Recall | FP | FN |
|---|---|---|---|---|---|---|
| ST-GCN (Stage 1) | 98.5% | 0.950 | 0.95 | 0.95 | 5 | 5 |
| ST-GCN + Physics Rescue | 98.7% | **0.955** | 0.95 | 0.96 | 5 | 4 |

Confusion matrix (test set, 675 samples):
```
              Pred NO-FALL  Pred FALL
True NO-FALL      571           5      (5 FP)
True FALL           4          95      (4 FN)
```

Tuned thresholds:
- `stage1_threshold = 0.50`
- `rescue_threshold = 0.45`
- `vel_threshold = 0.0237`
- `acc_threshold = 0.0`

Saqlangan joy: `experiments/subject1_2_3_4/`

## Oldingi eng yaxshi natija (Subject 1 only, subject-dependent)

**Sana:** 2026-06-11
**Fall F1:** ST-GCN 0.960 → ST-GCN + Physics Rescue **0.960**

## Ablation study (Subject 1+2+3+4, test set n=675)

Har bir komponent qo'shgan hissa:

| Konfiguratsiya | Fall F1 | Precision | Recall | FP | FN | Izoh |
|---|:---:|:---:|:---:|:---:|:---:|---|
| ST-GCN yolg'iz (Stage 1) | 0.950 | 0.95 | 0.95 | 5 | 5 | Baseline |
| ST-GCN + Physics AND (eski) | ~0.864* | — | — | — | — | Physics to'g'ri topganlarni o'chiradi |
| **ST-GCN + Physics Rescue (yangi)** | **0.955** | **0.95** | **0.96** | **5** | **4** | Physics faqat qo'shadi |

> *AND mantiq natijasi Run 2 (Subject 1 only) dan.
> Physics Rescue hissasi: 1 ta FN qo'shimcha aniqladi (5→4), precision o'zgarmasdan.

## Kutilgan Baseline taqqosi (TODO)

| Model | Kutilgan Fall F1 | Holat |
|---|:---:|---|
| LSTM (flat keypoints) | ~0.80–0.88 | ⬜ amalga oshirilmagan |
| TCN (flat keypoints) | ~0.85–0.90 | ⬜ amalga oshirilmagan |
| ST-GCN yolg'iz | **0.950** | ✅ bajarilgan |
| **ST-GCN + Physics Rescue** | **0.955** | ✅ bajarilgan |

## Natijalar tarixi

### Run 7 — 2026-06-14 (Subject 1+2+3+4, subject-stratified split)
Yangiliklar:
- Subject 4 qo'shildi (1.62m, 71kg)
- Subject-stratified bo'linish: har bir subject train/val/test ga teng tushadi
- Physics Rescue FN ni 1 ta qo'shimcha aniqladi (5→4)
- Early stopping: epoch 48 da to'xtadi (best val F1=0.970, epoch ~33)

| Model | Fall F1 |
|---|---|
| ST-GCN Stage 1 | 0.950 |
| ST-GCN + Physics Rescue | **0.955** |

### Run 6 — 2026-06-14 (Subject 1+2+3, early stopping qo'shildi)
Yangiliklar:
- Early stopping (patience=15) overfitting ni oldini olish uchun
- Training: epoch 50 da to'xtadi (best val F1=0.993, epoch ~35)
- F1 tiklandi: 0.686 → 0.943

| Model | Fall F1 |
|---|---|
| ST-GCN Stage 1 | **0.943** |
| ST-GCN + Physics Rescue | **0.943** |

Izoh: Physics Rescue qo'shimcha yaxshilanish bermadi — Stage 1 yaxshi kalibratsiya qilingan.

### Run 5 — 2026-06-13 (Subject 1+2+3, early stopping yo'q — MUVAFFAQIYATSIZ)
- Overfitting: val F1 epoch 20 (0.640) da eng yuqori, keyin 0.278 ga tushdi
- F1 = 0.686 — cross-subject training da early stopping majburiy

### Run 4 — 2026-06-13 (Subject 1+2, 2 ta subject)
Yangiliklar:
- Subject 2 qo'shildi (2210 sequence, avval 1145 edi)
- Physics Rescue samarali: FP 7→4

| Model | Fall F1 |
|---|---|
| ST-GCN Stage 1 | 0.931 |
| ST-GCN + Physics Rescue | **0.948** |

### Run 3 — 2026-06-11 (Physics Rescue + Zero-frame fix)
Yangiliklar:
- `conf=0.1` + forward-fill: zero frame 14.5% → **0%**
- Rescue mantiq: physics endi faqat QO'SHADI, o'chirmaydi

| Model | Fall F1 |
|---|---|
| ST-GCN Stage 1 | **0.960** |
| ST-GCN + Physics Rescue | **0.960** |

### Run 2 — 2026-06-11 (Zero-frame fix, eski physics)

| Model | Fall F1 |
|---|---|
| ST-GCN Stage 1 | 0.913 |
| ST-GCN + Physics (AND) | **0.864** ← physics zararli! |

### Run 1 — 2026-06-10 (Boshlang'ich natija)

| Model | Accuracy | Fall F1 |
|---|---|---|
| ST-GCN Stage 1 | 93.6% | 0.718 |
| ST-GCN + Physics (AND) | 95.9% | **0.837** |

## Yaxshilanish tahlili

```
Run 1 → Run 2: Zero-frame fix
  Fall F1: 0.718 → 0.913  (+0.195)  ← eng katta ta'sir

Run 2 → Run 3: Physics Rescue mantiq
  Fall F1: 0.913 → 0.960  (+0.047)

Run 3 → Run 4: Cross-subject (Subject 1+2)
  Fall F1: 0.960 → 0.948  (-0.012)  ← kutilgan, qiyin vazifa

Run 4 → Run 5: MUVAFFAQIYATSIZ — early stopping yo'q
  Fall F1: 0.948 → 0.686  (sabab: overfitting)

Run 5 → Run 6: Early stopping tuzatildi (Subject 1+2+3)
  Fall F1: 0.686 → 0.943  (+0.257)

Run 6 → Run 7: Ko'proq ma'lumot (Subject 1+2+3+4)
  Fall F1: 0.943 → 0.955  (+0.012)
```

## Keyingi kutilgan natijalar

| Scenario | Kutilgan Fall F1 |
|---|---|
| Subject 1-4 (hozirgi, subject-dependent) | 0.955 |
| Subject 1-17, subject-dependent | ~0.95+ |
| Subject 1-17, LOSO cross-subject | ~0.75-0.88 |

> LOSO natijasi haqiqiy real-world performance ko'rsatkichi hisoblanadi va qog'oz uchun kerak.

## Baseline modellar (qog'oz uchun qo'shish kerak)

- [ ] LSTM baseline
- [ ] TCN baseline
- [ ] ST-GCN alone (without physics) — hozir mavjud
- [ ] ST-GCN + Physics AND (eski mantiq) — hozir mavjud
- [ ] **ST-GCN + Physics Rescue (yangi mantiq)** — hozir mavjud
