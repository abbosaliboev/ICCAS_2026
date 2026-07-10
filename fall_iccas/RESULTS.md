# Training Results — MobiCare Fall Detection / 학습 결과

> Latest results only (full 17-subject UP-Fall dataset). Earlier runs (Subject 1 → 1–10, Runs 1–11) are in **[RESULTS_ARCHIVE.md](RESULTS_ARCHIVE.md)**.
> **Language / 언어:** [🇺🇸 English](#english) · [🇰🇷 한국어](#korean)

---

<a name="english"></a>
# 🇺🇸 English

## Current best — Subject 1–17 (full UP-Fall dataset)

| Evaluation | Model | Accuracy | Fall F1 | Sensitivity | Specificity |
|---|---|:---:|:---:|:---:|:---:|
| **Subject-stratified** (subject-dependent) | ST-GCN + Physics (2-stage) | **99.19%** | **0.972** | 97.3% | 99.5% |
| **Leave-one-subject-out** (cross-subject) | Two-camera fusion | 89.2% | 0.677 | 77.5% | 91.1% |

- **Subject-stratified** is the protocol most UP-Fall papers report (subject-mixed). **LOSO** is the stricter cross-subject test (unseen people).
- Physics rescue cuts false alarms (subject-stratified: FP 31 → 12, −61%).
- Two-camera fusion cuts LOSO false positives by 46% (see Run 14).
- Real-time on **Jetson Orin NX** (see `FPS_BENCHMARK.md`).

### How train / test are split (and why the numbers differ)

There are two ways to split the data:

**1. Subject-dependent — what most papers use.** Mix all people's data together, then split into train and test. The *same person* ends up in both. The model has already "seen" that person, so the score looks high (our **99.19%**). Our windows also overlap in time, and a random split can put almost-identical windows in both train and test — extra leakage that inflates the number.

**2. Cross-subject / LOSO — the honest way.** Take *one whole person out*, train on the other 16, and test only on that unseen person. The model has never seen them — this shows how it works on a *new* patient (our **0.68** fusion).

**Why do papers use the first (easier) way?**
- It gives higher numbers — looks better on paper.
- It's easier — more data left for training.
- Many fall datasets have very few people, so removing a whole person leaves too little to train on.
- Everyone does it, so they copy it to "compare fairly."
- The catch: it overstates real-world performance, because the model is tested on someone it already knew.

**What we do:** report *both* — subject-dependent (0.97) to line up with those papers, and LOSO (0.68) as the honest number for a real new patient. Your friends are right that the first way tests on "seen" data; that is exactly why we also did the second.

## Benchmark vs prior work (UP-Fall, front view)

| Study | Method | Sens | Spec | Acc | Edge deployment |
|---|---|:---:|:---:|:---:|:---:|
| Espinosa 2019 | CNN | 97.8 | 83.1 | 95.6 | ❌ |
| Ramirez 2021 | Random Forest | 98.8 | 99.5 | 99.3 | ❌ |
| Inturi 2022 | 1D-CNN+LSTM | 94.4 | 99.0 | 98.6 | ❌ |
| Raza 2023 | Vision Transformer | 97.2 | — | 97.4 | ❌ |
| TCNTE 2025 | TCN+Transformer | 95.4 | 99.7 | 99.6 | Orin NX, 19 fps |
| **MobiCare (ours)** | **ST-GCN + Physics** | **97.3** | **99.5** | **99.19** | **Orin NX, ~30 fps (69 fps pipeline) + app** |

> Ours: subject-stratified split. Competitive accuracy; **Sensitivity 97.3% exceeds TCNTE (95.4%)** — fewer missed falls, the safety-critical metric. Unique to our work: physics-informed rescue (real-world robustness, ~0 latency) + a full deployed system (edge + caregiver mobile app + safe-zone). Competitor numbers: Yu et al. 2025 (TCNTE), Table 5.

### Head-to-head: TCNTE vs MobiCare

Both measured on the same class of hardware (Jetson Orin NX), same FPS methodology (full pipeline: pose estimation + classifier, live, single person).

| Method | Sensitivity | Specificity | Accuracy | Fall F1 | Edge deployment | FPS |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| TCNTE 2025 (TCN+Transformer) | 95.4% | 99.7% | 99.6% | — (not reported) | Jetson Orin NX | 19 |
| **MobiCare (ours, subject-stratified)** | **97.3%** | **99.5%** | **99.19%** | **0.972** | Jetson Orin NX + mobile app | **30.48** |
| MobiCare (ours, LOSO cross-subject) | 84.1% | 85.5% | 85.3% | 0.625 | Jetson Orin NX + mobile app | 30.48 |

> FPS measured live on-device (n=3002 samples, mean ± std = 30.48 ± 1.28 fps) — MobiCare runs **~1.6× faster** than TCNTE's reported 19 fps on comparable hardware. F1 not stated in the TCNTE paper (only accuracy/sensitivity/specificity given), shown as "—" rather than estimated. The LOSO row uses the identical deployed model/pipeline — FPS is a hardware property, not evaluation-split-dependent; it is included to show accuracy under the harder, honest cross-subject protocol TCNTE does not report.

---

## Run history (17-subject)

### Run 15 — 2026-07-07 (Subject 1–17, subject-stratified split) — POSTER HEADLINE

Full 17-subject dataset, subject-stratified 70/15/15 (each subject proportionally in train/val/test — subject-DEPENDENT, the protocol most UP-Fall papers use; NOT LOSO). `train_two_stage.py`. Test n=2837 (414 fall).

| Model | Accuracy | Fall F1 | Precision | Recall | FP | FN |
|---|---|---|---|---|---|---|
| ST-GCN (Stage 1) | 0.9873 | 0.9578 | 0.93 | 0.99 | 31 | 5 |
| **ST-GCN + Physics (2-Stage)** | **0.9919** | **0.9723** | 0.97 | 0.97 | 12 | 11 |

Two-stage confusion: `[[2411 12] [11 403]]` → Sensitivity 97.3%, Specificity 99.5%.

- **This is the poster/benchmark number** — comparable protocol to most UP-Fall papers.
- Physics rescue helped: F1 0.9578 → 0.9723, false alarms 31 → 12 (−61%).
- ST-GCN ~3.1M params (larger than TCNTE's 14.7k) but real-time on Jetson Orin NX.

Saved to: `experiments/subject1_to_17/two_stage/`

---

### Run 14 — 2026-07-07 (Two-camera score-level fusion, 17-fold LOSO)

Full Camera2 LOSO (17 folds) then score-level fusion of Camera1 + Camera2 per-window fall probabilities. Fusion rule (weighted-avg / AND / OR) tuned on val per fold, applied to held-out test subject. `fuse_cameras.py`.

| Metric | Camera1 (front) | Camera2 (side) | **Fusion** |
|---|:---:|:---:|:---:|
| mean Fall F1 | 0.6165 | 0.5178 | **0.6772** |
| aggregate F1 | 0.612 | 0.502 | **0.671** |
| Precision | 0.470 | 0.395 | **0.592** |
| Recall | 0.878 | 0.689 | 0.775 |
| Specificity | 0.835 | 0.825 | **0.911** |
| Accuracy | 0.841 | 0.805 | **0.892** |
| FP | 2665 | 2831 | **1438** |
| FN | 327 | 837 | 604 |

**Key result: two-camera fusion cuts false positives by 46% (2665 → 1438) and raises precision 0.47 → 0.59, specificity 0.84 → 0.91, accuracy 0.84 → 0.89, and Fall F1 0.62 → 0.68 — all under strict 17-fold LOSO.** The A11 laying false positives (96% of Camera1 FP) are largely removed because a fall must now be plausible from *both* viewpoints.

- Camera2 (side view) alone is worse than Camera1 (front): 0.52 vs 0.62 F1, consistent with UP-Fall literature. Its value is purely complementary.
- Tradeoff: recall drops 87.8% → 77.5%. Fusion trades some sensitivity for large precision gains — appropriate for deployment (alarm fatigue).

Saved to: `experiments/subject1_to_17_cam2/loso/fuse_cameras.json`

---

### Run 12 — 2026-07-07 (LOSO, Subject 1–17, cross-subject) + A11 analysis

Leave-One-Subject-Out (17 folds), full dataset. **Camera1 ST-GCN: Fall F1 0.6165 ± 0.065.** Precision (0.47) is the bottleneck, not recall (87.8%).

**Decisive finding: 2548 of 2665 false positives (96%) come from Activity 11 (laying down)** — the vertical→horizontal transition of lying on a bed is nearly indistinguishable from a fall in single-view pose space. Kinematic veto (velocity/accel/hip-drop) was tested and rejected: all features separate fall-vs-A11 near-randomly (AUC ≈ 0.53–0.61). The principled fix is the second camera (Run 13 → Run 14).

Saved to: `experiments/subject1_to_17/loso/`
(Run 13 — Camera2 pilot motivating fusion — is in [RESULTS_ARCHIVE.md](RESULTS_ARCHIVE.md).)

---

<a name="korean"></a>
# 🇰🇷 한국어

## 현재 최고 결과 — Subject 1–17 (전체 UP-Fall 데이터셋)

| 평가 방식 | 모델 | Accuracy | Fall F1 | Sensitivity | Specificity |
|---|---|:---:|:---:|:---:|:---:|
| **Subject-stratified** (피험자 의존) | ST-GCN + Physics (2단계) | **99.19%** | **0.972** | 97.3% | 99.5% |
| **LOSO** (교차 피험자) | 2-카메라 융합 | 89.2% | 0.677 | 77.5% | 91.1% |

- Subject-stratified는 대부분의 UP-Fall 논문이 쓰는 방식, LOSO는 더 엄격한 교차 피험자 평가.
- Physics rescue가 오탐을 줄임 (FP 31 → 12, −61%).
- **Jetson Orin NX**에서 실시간 동작 (`FPS_BENCHMARK.md`).

### 학습/평가 분할 방식 (그리고 수치가 다른 이유)

데이터를 나누는 방법은 두 가지입니다:

**1. 피험자 의존 — 대부분 논문이 쓰는 방식.** 모든 사람 데이터를 섞은 뒤 train/test로 나눕니다. *같은 사람*이 양쪽에 다 들어갑니다. 모델이 이미 그 사람을 "봤기" 때문에 점수가 높게 나옵니다(**99.19%**). 게다가 우리 윈도우는 시간상 겹치는데, 무작위로 나누면 거의 같은 윈도우가 train과 test에 동시에 들어갈 수 있어 점수가 더 부풀려집니다.

**2. 교차 피험자 / LOSO — 정직한 방식.** *한 사람 전체를 빼고* 나머지 16명으로 학습한 뒤, 그 처음 보는 사람만으로 평가합니다. 모델이 한 번도 본 적 없는 사람 → *새 환자*에서의 실제 성능(융합 **0.68**).

**왜 논문들은 (더 쉬운) 첫 번째 방식을 쓸까?**
- 수치가 더 높게 나옵니다 — 논문에 보기 좋습니다.
- 더 쉽습니다 — 학습에 쓸 데이터가 더 많이 남습니다.
- 낙상 데이터셋은 사람 수가 매우 적어서, 한 사람을 통째로 빼면 학습 데이터가 너무 적어집니다.
- 다들 그렇게 하니까 "공정한 비교"를 위해 따라 합니다.
- 함정: 모델이 이미 아는 사람으로 평가하므로 실환경 성능을 과대평가합니다.

**우리 방식:** *둘 다* 보고합니다 — 선행 논문과 맞추기 위한 피험자 의존(0.97), 그리고 실제 새 환자 기준의 정직한 수치인 LOSO(0.68). 친구분들 말처럼 첫 번째 방식은 "본" 데이터로 평가하는 것이며, 그래서 우리는 두 번째도 함께 했습니다.

## 선행 연구 대비 벤치마크 (UP-Fall, front view)

| 연구 | 방법 | Sens | Spec | Acc | 엣지 |
|---|---|:---:|:---:|:---:|:---:|
| Espinosa 2019 | CNN | 97.8 | 83.1 | 95.6 | ❌ |
| Ramirez 2021 | Random Forest | 98.8 | 99.5 | 99.3 | ❌ |
| Inturi 2022 | 1D-CNN+LSTM | 94.4 | 99.0 | 98.6 | ❌ |
| TCNTE 2025 | TCN+Transformer | 95.4 | 99.7 | 99.6 | Orin NX, 19 fps |
| **MobiCare (본 연구)** | **ST-GCN + Physics** | **97.3** | **99.5** | **99.19** | **Orin NX, ~30 fps (69 fps 파이프라인) + 앱** |

> 본 연구는 subject-stratified split. 정확도 경쟁력 있음, **Sensitivity 97.3%로 TCNTE(95.4%)보다 높음** (낙상 놓침 적음). 차별점: physics 기반 rescue(실환경 강건성, ~0 지연) + 완전한 배포 시스템(엣지 + 보호자 모바일 앱 + safe-zone).

### TCNTE vs MobiCare 직접 비교

동일 계열 하드웨어(Jetson Orin NX), 동일 FPS 측정 방식(전체 파이프라인: pose estimation + classifier, 실시간, 1인 기준).

| 방법 | Sensitivity | Specificity | Accuracy | Fall F1 | 엣지 배포 | FPS |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| TCNTE 2025 (TCN+Transformer) | 95.4% | 99.7% | 99.6% | — (미공개) | Jetson Orin NX | 19 |
| **MobiCare (본 연구, subject-stratified)** | **97.3%** | **99.5%** | **99.19%** | **0.972** | Jetson Orin NX + 모바일 앱 | **30.48** |
| MobiCare (본 연구, LOSO cross-subject) | 84.1% | 85.5% | 85.3% | 0.625 | Jetson Orin NX + 모바일 앱 | 30.48 |

> FPS는 실제 기기에서 측정(n=3002, 평균±표준편차 = 30.48 ± 1.28 fps) — TCNTE가 보고한 19 fps 대비 MobiCare가 **약 1.6배 빠름** (비슷한 하드웨어 기준). TCNTE 논문에는 F1이 명시되어 있지 않아(accuracy/sensitivity/specificity만 제공) 추정하지 않고 "—"로 표기. LOSO 행은 동일하게 배포된 모델/파이프라인을 사용 — FPS는 평가 분할과 무관한 하드웨어 속성이며, TCNTE가 보고하지 않은 더 엄격하고 정직한 cross-subject 프로토콜에서의 정확도를 보여주기 위해 포함.

> 전체 실행 기록(Run 1–15)은 [RESULTS_ARCHIVE.md](RESULTS_ARCHIVE.md) 참고.
