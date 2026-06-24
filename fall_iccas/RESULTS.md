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
