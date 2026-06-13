# Training Results History / 학습 결과 기록 / Training Natijalari Tarixi

> **Language / 언어 / Til**
> - [🇺🇸 English](#english)
> - [🇰🇷 한국어](#korean)
> - [🇺🇿 O'zbekcha](#uzbek)

---

<a name="english"></a>
# 🇺🇸 English

## Current best result (Subject 1+2, subject-dependent — highest F1 so far)

**Date:** 2026-06-13
**Dataset:** Subject 1+2 — X.npy shape (2210, 30, 17, 3)
**Split:** 70/15/15 stratified (train=1547, val=331, test=332)

| Model | Accuracy | Fall F1 | Precision | Recall | FP | FN |
|---|---|---|---|---|---|---|
| ST-GCN (Stage 1) | 97.9% | 0.931 | 0.87 | 1.00 | 7 | 0 |
| ST-GCN + Physics Rescue | 98.5% | **0.948** | 0.92 | 0.98 | 4 | 1 |

Confusion matrix (test set, 332 samples):
```
Two-stage:
              Pred NO-FALL  Pred FALL
True NO-FALL      281           4      (4 FP)
True FALL           1          46      (1 FN)
```

Tuned thresholds:
- `stage1_threshold = 0.90`
- `rescue_threshold = 0.85`
- `vel_threshold = 0.02038`
- `acc_threshold = 0.33960`

---

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

### Run 6 — 2026-06-14 (Subject 1+2+3, early stopping fixed)
What's new:
- Added early stopping (patience=15) to prevent overfitting
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
```

## Expected future results

| Scenario | Expected Fall F1 |
|---|---|
| Subject 1 (current) | 0.96 |
| Subjects 1-17, subject-dependent | ~0.95+ |
| Subjects 1-17, LOSO cross-subject | ~0.75-0.88 |

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

## 현재 최고 결과 (Subject 1+2, subject-dependent)

**날짜:** 2026-06-13
**데이터셋:** Subject 1+2 — X.npy shape (2210, 30, 17, 3)
**Split:** 70/15/15 stratified (train=1547, val=331, test=332)

| 모델 | Accuracy | Fall F1 | Precision | Recall | FP | FN |
|---|---|---|---|---|---|---|
| ST-GCN (Stage 1) | 97.9% | 0.931 | 0.87 | 1.00 | 7 | 0 |
| ST-GCN + Physics Rescue | 98.5% | **0.948** | 0.92 | 0.98 | 4 | 1 |

Confusion matrix (test set, 172 샘플):
```
              Pred NO-FALL  Pred FALL
True NO-FALL      146           1      (1 FP)
True FALL           1          24      (1 FN)
```

튜닝된 임계값:
- `stage1_threshold = 0.55`
- `rescue_threshold = 0.50`
- `vel_threshold = 0.0354`
- `acc_threshold = 0.3545`

## 결과 기록

### Run 3 — 2026-06-11 (Physics Rescue + Zero-frame 수정)
변경 사항:
- `conf=0.1` + forward-fill 보간으로 zero frame 14.5% → **0%**
- Physics "Rescue" 로직: `prob >= t1 → FALL`, `t_rescue <= prob < t1 → physics가 결정`
- 기존 AND 로직 대체: physics는 이제 추가만 하고, 제거하지 않음

| 모델 | Fall F1 |
|---|---|
| ST-GCN Stage 1 | **0.960** |
| ST-GCN + Physics Rescue | **0.960** |

비고: Rescue zone [0.50, 0.55) — Stage 1이 너무 좋아서 rescue가 필요 없었음.

### Run 2 — 2026-06-11 (Zero-frame 수정, 기존 physics)
변경 사항: `conf=0.1` + 보간으로 zero frame 수정

| 모델 | Fall F1 |
|---|---|
| ST-GCN Stage 1 | 0.913 |
| ST-GCN + Physics (AND) | **0.864** ← physics가 해로움! |

비고: Physics AND 로직이 Stage 1의 올바른 감지까지 삭제함 (Stage 1 precision=1.00이었음).

### Run 1 — 2026-06-10 (초기 결과)
데이터셋: zero frame 문제가 있던 상태 (낙상 시퀀스의 14.5%가 zero frame)

| 모델 | Accuracy | Fall F1 |
|---|---|---|
| ST-GCN Stage 1 | 93.6% | 0.718 |
| ST-GCN + Physics (AND) | 95.9% | **0.837** |

비고: Zero frame 때문에 recall이 낮음 (0.56). FP가 많았기 때문에 이 경우에는 physics AND 로직이 유용했음.

## 개선 분석

```
Run 1 → Run 2: Zero-frame 수정
  Fall F1: 0.718 → 0.913  (+0.195)  ← 가장 큰 효과
  원인: YOLO conf=0.1 + 보간

Run 2 → Run 3: Physics Rescue 로직
  Fall F1: 0.913 → 0.960  (+0.047)
  원인: physics가 더 이상 감지 결과를 제거하지 않음
```

## 향후 예상 결과

| 시나리오 | 예상 Fall F1 |
|---|---|
| Subject 1 (현재) | 0.96 |
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

## Hozirgi eng yaxshi natija (Subject 1+2, subject-dependent)

**Sana:** 2026-06-13
**Dataset:** Subject 1+2 — X.npy shape (2210, 30, 17, 3)
**Split:** 70/15/15 stratified (train=1547, val=331, test=332)

| Model | Accuracy | Fall F1 | Precision | Recall | FP | FN |
|---|---|---|---|---|---|---|
| ST-GCN (Stage 1) | 97.9% | 0.931 | 0.87 | 1.00 | 7 | 0 |
| ST-GCN + Physics Rescue | 98.5% | **0.948** | 0.92 | 0.98 | 4 | 1 |

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

## Natijalar tarixi

### Run 3 — 2026-06-11 (Physics Rescue + Zero-frame fix)
Yangiliklar:
- `conf=0.1` + forward-fill interpolation bilan zero frame 14.5% → **0%**
- Physics "Rescue" mantiq: `prob >= t1 → FALL`, `t_rescue <= prob < t1 → physics qaror`
- Avvalgi AND mantiq o'rniga: physics endi faqat QO'SHADI, o'chirmaydi

| Model | Fall F1 |
|---|---|
| ST-GCN Stage 1 | **0.960** |
| ST-GCN + Physics Rescue | **0.960** |

Izoh: Rescue zone [0.50, 0.55) — Stage 1 shunchalik yaxshi bo'lganki rescue kerak bo'lmadi.

### Run 2 — 2026-06-11 (Zero-frame fix, eski physics)
Yangiliklar: `conf=0.1` + interpolation bilan zero frame tuzatildi

| Model | Fall F1 |
|---|---|
| ST-GCN Stage 1 | 0.913 |
| ST-GCN + Physics (AND) | **0.864** ← physics zararli! |

Izoh: Physics AND mantiq Stage 1 ning to'g'ri topganlarini ham o'chirdi (Stage 1 precision=1.00 edi).

### Run 1 — 2026-06-10 (Boshlang'ich natija)
Dataset: zero frame muammosi bilan (fall sequencelarda 14.5% zero frame)

| Model | Accuracy | Fall F1 |
|---|---|---|
| ST-GCN Stage 1 | 93.6% | 0.718 |
| ST-GCN + Physics (AND) | 95.9% | **0.837** |

Izoh: Zero frame tufayli recall past (0.56). Physics AND mantiq bu holdada foydali bo'ldi chunki FP lar ko'p edi.

## Yaxshilanish tahlili

```
Run 1 → Run 2: Zero-frame fix
  Fall F1: 0.718 → 0.913  (+0.195)  ← eng katta ta'sir
  Sabab: YOLO conf=0.1 + interpolation

Run 2 → Run 3: Physics Rescue mantiq
  Fall F1: 0.913 → 0.960  (+0.047)
  Sabab: Physics endi topganlarni o'chirmaydi
```

## Keyingi kutilgan natijalar

| Scenario | Kutilgan Fall F1 |
|---|---|
| Subject 1 (hozirgi) | 0.96 |
| Subject 1-17, subject-dependent | ~0.95+ |
| Subject 1-17, LOSO cross-subject | ~0.75-0.88 |

> LOSO natijasi haqiqiy real-world performance ko'rsatkichi hisoblanadi va qog'oz uchun kerak.

## Baseline modellar (qog'oz uchun qo'shish kerak)

- [ ] LSTM baseline
- [ ] TCN baseline
- [ ] ST-GCN alone (without physics) — hozir mavjud
- [ ] ST-GCN + Physics AND (eski mantiq) — hozir mavjud
- [ ] **ST-GCN + Physics Rescue (yangi mantiq)** — hozir mavjud
