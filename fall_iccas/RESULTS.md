# Training Results History / 학습 결과 기록

> **Language / 언어 / Til**
> - [🇺🇸 English](#english)
> - [🇰🇷 한국어](#korean)
> 
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

---

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

