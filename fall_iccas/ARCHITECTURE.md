# Model Architecture / 모델 아키텍처 / Model Arxitekturasi

> **Language / 언어 / Til**
> - [🇺🇸 English](#english)
> - [🇰🇷 한국어](#korean)
> - [🇺🇿 O'zbekcha](#uzbek)

---

<a name="english"></a>
# 🇺🇸 English

## Overview

```
Input: camera frames (Camera1, ~19 FPS)
         │
         ▼
  ┌─────────────────┐
  │  YOLO11n-pose   │  conf=0.1, batch_size=8
  │  (keypoint det) │
  └────────┬────────┘
           │  (F, 17, 3) — frame, joint, [x, y, conf]
           ▼
  ┌─────────────────┐
  │ Zero-frame fill │  forward-fill → backward-fill
  │ (interpolation) │
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │ Sliding window  │  T=30, stride=15
  └────────┬────────┘
           │  (N, 30, 17, 3)
           ▼
  ┌─────────────────┐
  │   ST-GCN        │  Stage 1
  │   (9 blocks)    │
  └────────┬────────┘
           │  fall probability p
           ▼
  ┌───────────────────────────────────┐
  │        Physics Rescue             │  Stage 2
  │  p >= 0.55  → FALL               │
  │  0.50 <= p < 0.55 → physics?     │
  │  p < 0.50   → NO-FALL            │
  └───────────────────────────────────┘
```

## ST-GCN (Spatial Temporal Graph Convolutional Network)

**Primary source:** Yan et al., "Spatial Temporal Graph Convolutional Networks for Skeleton-Based Action Recognition", AAAI 2018.

### Skeleton graph

17 COCO keypoints (YOLO11n-pose output):

```
0: nose          5: left_shoulder    11: left_hip
1: left_eye      6: right_shoulder   12: right_hip
2: right_eye     7: left_elbow       13: left_knee
3: left_ear      8: right_elbow      14: right_knee
4: right_ear     9: left_wrist       15: left_ankle
                10: right_wrist      16: right_ankle
```

**Adjacency matrix A** — shape (3, 17, 17), 3 subsets:
- `A[0]` — self-link (each joint with itself)
- `A[1]` — centripetal (shoulders, hips → toward center)
- `A[2]` — centrifugal (from center → hand/foot extremities)

Center node: `11` (left_hip, BFS root)

### Architecture

```
Input: (N, C=3, T=30, V=17, M=1)

Block 1-3:   SpatialGCN(3→64)  + TemporalConv(64, stride=1)
Block 4-6:   SpatialGCN(64→128) + TemporalConv(128, stride=2 block4)
Block 7-9:   SpatialGCN(128→256) + TemporalConv(256, stride=2 block7)

GlobalAvgPool → Dropout(0.5) → Linear(256→2)

Output: (N, 2) logits  →  softmax  →  fall probability
```

Each STGCNBlock:
```
SpatialGCN:
  x → einsum(A, x) → BatchNorm → ReLU
  + learnable attention mask on A

TemporalConv:
  Conv2d(C, C, kernel=(9,1), padding=(4,0)) → BatchNorm → ReLU
  + residual connection (1x1 conv if channels change)
```

### Training settings

| Parameter | Value |
|---|---|
| Epochs | 60 |
| Batch size | 32 |
| Optimizer | Adam (lr=1e-3, weight_decay=1e-4) |
| Scheduler | CosineAnnealingLR (T_max=60) |
| Dropout | 0.5 |
| Class imbalance | WeightedRandomSampler (FALL:NO-FALL = 1:~6) |
| Augmentation | Horizontal flip (p=0.5) + Gaussian noise (σ=0.01) |
| Best model | saved based on val fall F1 |

## Physics Filter (Stage 2)

### Computation

```python
# 1. Get mid-hip Y coordinate (COCO indices 11, 12)
hip_y = (seq[:, 11, 1] + seq[:, 12, 1]) / 2.0   # 0=top, 1=bottom

# 2. Position filter (4 Hz Butterworth lowpass)
hip_y_filtered = lowpass(hip_y, fc=4.0)

# 3. Velocity (downward = positive)
velocity = gradient(hip_y_filtered, dt=1/fps)
velocity_f = lowpass(velocity, fc=8.0)

# 4. Acceleration
acceleration = gradient(velocity_f, dt=1/fps)
acceleration_f = lowpass(acceleration, fc=6.0)

# 5. Features
max_velocity = velocity_f.max()
max_abs_acc  = abs(acceleration_f).max()
hip_drop     = hip_y_filtered.max() - hip_y_filtered.min()
```

### Thresholds

Found via grid search on the validation set:
- `vel_threshold = 0.0354` (normalized units/s)
- `acc_threshold = 0.3545` (normalized units/s²)

Decision: `max_velocity > vel_threshold AND max_abs_acc > acc_threshold` → physics confirms fall

### Rescue logic

```
Stage 1 prob:
  ≥ 0.55  → FALL   (Stage 1 confident, physics not consulted)
  [0.50, 0.55)  → physics decides  ← Rescue zone
  < 0.50  → NO-FALL
```

**Key difference from the old AND logic:**
- **Old (AND):** `Stage1=1 AND physics=1` — physics could delete Stage 1 detections
- **New (Rescue):** physics can only rescue what Stage 1 MISSED

## Dataset preparation

### YOLO keypoint extraction

```python
MODEL = YOLO("yolo11n-pose.pt")
# conf=0.1 — low threshold for fall poses
results = MODEL(batch, conf=0.1)

# take the most confident person
person_idx = keypoints.conf.sum(dim=1).argmax()

# normalization
xy_norm = xy_pixels / [image_width, image_height]  # in [0, 1] range
```

### Zero-frame interpolation

```python
def interpolate_zero_frames(kps):
    # Forward fill: use the last detected frame
    for i in range(len(kps)):
        if frame_is_zero(kps[i]):
            kps[i] = last_valid_frame
    # Backward fill: fill zeros at the beginning
    ...
```

**Result:** zero frames in fall sequences 14.5% → **0%**

### Sliding window

```
Trial (F frames) → windows:
  [0:30], [15:45], [30:60], ...

Window size T=30 (~1.58 seconds at 19 FPS)
Stride     S=15 (~0.79 seconds)
```

## Real-time Webcam Demo (`demo_webcam.py`)

### Pipeline

```
Webcam frame
    │
    ▼  YOLO11n-pose (conf=0.1)
    │  normalized (17, 3) keypoints
    ▼
  Ring buffer (deque, maxlen=30)
    │  every 15 frames:
    ▼  ffill → (30, 17, 3) window
  ┌──────────────────────────────────────┐
  │  PHYSICS-ONLY mode (recommended)     │
  │                                      │
  │  1. Personal baseline (EMA hip Y     │
  │     while standing upright)          │
  │                                      │
  │  2. Slow fall:                       │
  │     drop_from_base > slow_drop       │
  │     AND is_lying() (shoulder ≈ hip)  │
  │     for lying_confirm windows        │
  │                                      │
  │  3. Fast fall (--fast-fall):         │
  │     max_velocity + max_acc + net_drop│
  └──────────────────────────────────────┘
    │  pred ∈ {0, 1}
    ▼
  State machine:
    fall_streak >= confirm_needed → FALL DETECTED
    is_standing() for stand_streak → auto-reset
```

### Key design decisions

| Decision | Reason |
|---|---|
| Baseline hip Y (EMA) | Camera-angle/distance independent — person's own reference |
| `is_lying()` condition | Distinguishes floor-sitting (upright torso) from lying (horizontal) |
| `--fast-fall` OFF by default | Slow falls are the priority for elderly; fast-fall causes FP when running |
| `--use-model` display-only | ST-GCN trained on UP-Fall lab data — distribution shift on webcam; physics is reliable |
| 5s min-lock after alert | Prevents flashing alerts; lying person still triggers while motionless |

### State machine

```
Idle → fall_streak++ (per window) → [streak ≥ confirm] → FALL ACTIVE
                                                              │ min_lock (5s)
FALL ACTIVE → [lock expired] → is_standing() × stand_streak → Idle
```

### Posture detectors

```python
is_standing(kp, delta=0.12):  hip_y - shoulder_y > delta
is_lying(kp, delta=0.10):     hip_y - shoulder_y < delta  (horizontal body)
```

### Run command

```bash
python demo_webcam.py --physics-only --confirm 2 --slow-drop 0.12 --lying-confirm 2

# with ST-GCN display overlay (model shown but doesn't gate detection):
python demo_webcam.py --physics-only --use-model --confirm 2 --slow-drop 0.12 --lying-confirm 2
```

## File sources

| File | Description |
|---|---|
| `stgcn/graph.py` | 17-joint COCO skeleton, adjacency matrix A(3,17,17) |
| `stgcn/model.py` | ST-GCN 9 blocks, learnable attention |
| `stgcn/physics.py` | Butterworth filter, threshold fitting, grid search |
| `stgcn/two_stage.py` | TwoStageDetector, Rescue logic, tune_thresholds() |
| `prepare_cv_dataset.py` | YOLO extraction + interpolation + windowing |
| `train_two_stage.py` | Full pipeline: split → train → physics fit → evaluate |
| `demo_webcam.py` | Real-time webcam demo: physics-based detection + optional ST-GCN overlay |

---

<a name="korean"></a>
# 🇰🇷 한국어

## 전체 구조

```
입력: 카메라 프레임 (Camera1, ~19 FPS)
         │
         ▼
  ┌─────────────────┐
  │  YOLO11n-pose   │  conf=0.1, batch_size=8
  │  (키포인트 검출) │
  └────────┬────────┘
           │  (F, 17, 3) — frame, joint, [x, y, conf]
           ▼
  ┌─────────────────┐
  │ Zero-frame fill │  forward-fill → backward-fill
  │ (보간)          │
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │ Sliding window  │  T=30, stride=15
  └────────┬────────┘
           │  (N, 30, 17, 3)
           ▼
  ┌─────────────────┐
  │   ST-GCN        │  Stage 1
  │   (9 blocks)    │
  └────────┬────────┘
           │  낙상 확률 p
           ▼
  ┌───────────────────────────────────┐
  │        Physics Rescue             │  Stage 2
  │  p >= 0.55  → FALL               │
  │  0.50 <= p < 0.55 → physics?     │
  │  p < 0.50   → NO-FALL            │
  └───────────────────────────────────┘
```

## ST-GCN (Spatial Temporal Graph Convolutional Network)

**주요 출처:** Yan et al., "Spatial Temporal Graph Convolutional Networks for Skeleton-Based Action Recognition", AAAI 2018.

### 스켈레톤 그래프

17개 COCO 키포인트 (YOLO11n-pose 출력):

```
0: nose          5: left_shoulder    11: left_hip
1: left_eye      6: right_shoulder   12: right_hip
2: right_eye     7: left_elbow       13: left_knee
3: left_ear      8: right_elbow      14: right_knee
4: right_ear     9: left_wrist       15: left_ankle
                10: right_wrist      16: right_ankle
```

**인접 행렬 A** — shape (3, 17, 17), 3개 subset:
- `A[0]` — self-link (각 관절이 자기 자신과 연결)
- `A[1]` — centripetal (어깨, 엉덩이 → 중심 방향)
- `A[2]` — centrifugal (중심 → 손/발 끝 방향)

Center node: `11` (left_hip, BFS root)

### 아키텍처

```
입력: (N, C=3, T=30, V=17, M=1)

Block 1-3:   SpatialGCN(3→64)  + TemporalConv(64, stride=1)
Block 4-6:   SpatialGCN(64→128) + TemporalConv(128, stride=2 block4)
Block 7-9:   SpatialGCN(128→256) + TemporalConv(256, stride=2 block7)

GlobalAvgPool → Dropout(0.5) → Linear(256→2)

출력: (N, 2) logits  →  softmax  →  낙상 확률
```

각 STGCNBlock:
```
SpatialGCN:
  x → einsum(A, x) → BatchNorm → ReLU
  + A에 대한 learnable attention mask

TemporalConv:
  Conv2d(C, C, kernel=(9,1), padding=(4,0)) → BatchNorm → ReLU
  + residual connection (채널이 바뀌면 1x1 conv)
```

### 학습 설정

| 파라미터 | 값 |
|---|---|
| Epochs | 60 |
| Batch size | 32 |
| Optimizer | Adam (lr=1e-3, weight_decay=1e-4) |
| Scheduler | CosineAnnealingLR (T_max=60) |
| Dropout | 0.5 |
| 클래스 불균형 | WeightedRandomSampler (FALL:NO-FALL = 1:~6) |
| Augmentation | 좌우 반전 (p=0.5) + 가우시안 노이즈 (σ=0.01) |
| Best model | val fall F1 기준으로 저장 |

## Physics Filter (Stage 2)

### 계산

```python
# 1. mid-hip Y 좌표 추출 (COCO index 11, 12)
hip_y = (seq[:, 11, 1] + seq[:, 12, 1]) / 2.0   # 0=위, 1=아래

# 2. 위치 필터 (4 Hz Butterworth lowpass)
hip_y_filtered = lowpass(hip_y, fc=4.0)

# 3. 속도 (아래 방향 = 양수)
velocity = gradient(hip_y_filtered, dt=1/fps)
velocity_f = lowpass(velocity, fc=8.0)

# 4. 가속도
acceleration = gradient(velocity_f, dt=1/fps)
acceleration_f = lowpass(acceleration, fc=6.0)

# 5. 특징량
max_velocity = velocity_f.max()
max_abs_acc  = abs(acceleration_f).max()
hip_drop     = hip_y_filtered.max() - hip_y_filtered.min()
```

### 임계값

Validation set에서 grid search로 결정:
- `vel_threshold = 0.0354` (normalized units/s)
- `acc_threshold = 0.3545` (normalized units/s²)

판정: `max_velocity > vel_threshold AND max_abs_acc > acc_threshold` → physics가 낙상으로 확인

### Rescue 로직

```
Stage 1 확률:
  ≥ 0.55  → FALL   (Stage 1 확신, physics 미사용)
  [0.50, 0.55)  → physics가 결정  ← Rescue zone
  < 0.50  → NO-FALL
```

**기존 AND 로직과의 중요한 차이:**
- **기존 (AND):** `Stage1=1 AND physics=1` — physics가 Stage 1의 감지를 삭제할 수 있음
- **신규 (Rescue):** physics는 Stage 1이 놓친(MISS) 것만 구제할 수 있음

## 데이터셋 준비

### YOLO 키포인트 추출

```python
MODEL = YOLO("yolo11n-pose.pt")
# conf=0.1 — 낙상 자세를 위한 낮은 임계값
results = MODEL(batch, conf=0.1)

# 가장 확신도 높은 사람 선택
person_idx = keypoints.conf.sum(dim=1).argmax()

# 정규화
xy_norm = xy_pixels / [image_width, image_height]  # [0, 1] 범위
```

### Zero-frame 보간

```python
def interpolate_zero_frames(kps):
    # Forward fill: 마지막으로 검출된 프레임 사용
    for i in range(len(kps)):
        if frame_is_zero(kps[i]):
            kps[i] = last_valid_frame
    # Backward fill: 시작 부분의 zero 채우기
    ...
```

**결과:** 낙상 시퀀스의 zero frame 14.5% → **0%**

### 슬라이딩 윈도우

```
Trial (F 프레임) → 윈도우:
  [0:30], [15:45], [30:60], ...

윈도우 크기 T=30 (19 FPS 기준 ~1.58초)
Stride      S=15 (~0.79초)
```

## 실시간 웹캠 데모 (`demo_webcam.py`)

### 핵심 설계 결정

| 결정 | 이유 |
|---|---|
| 개인 기준선 hip Y (EMA) | 카메라 각도/거리에 무관 — 본인 기준으로 측정 |
| `is_lying()` 조건 | 바닥 앉기(상체 직립)와 눕기(수평)를 구분 |
| `--fast-fall` 기본 OFF | 노인 낙상은 주로 느린 낙상; 빠른 낙상은 달리기에서 FP 발생 |
| `--use-model` 표시 전용 | ST-GCN이 UP-Fall 실험실 데이터로 학습됨 — 웹캠 도메인 차이; physics가 신뢰도 높음 |
| 5초 최소 잠금 | 낙상 후 정적인 상태에서도 알림 유지 |

### 실행 명령어

```bash
python demo_webcam.py --physics-only --confirm 2 --slow-drop 0.12 --lying-confirm 2

# ST-GCN 확률 오버레이 포함 (표시 전용, 감지는 physics 담당):
python demo_webcam.py --physics-only --use-model --confirm 2 --slow-drop 0.12 --lying-confirm 2
```

## 파일별 역할

| 파일 | 설명 |
|---|---|
| `stgcn/graph.py` | 17관절 COCO 스켈레톤, 인접 행렬 A(3,17,17) |
| `stgcn/model.py` | ST-GCN 9 blocks, learnable attention |
| `stgcn/physics.py` | Butterworth 필터, 임계값 fitting, grid search |
| `stgcn/two_stage.py` | TwoStageDetector, Rescue 로직, tune_thresholds() |
| `prepare_cv_dataset.py` | YOLO 추출 + 보간 + 윈도잉 |
| `train_two_stage.py` | 전체 파이프라인: split → train → physics fit → evaluate |
| `demo_webcam.py` | 실시간 웹캠 데모: physics 기반 감지 + ST-GCN 오버레이 |

---

<a name="uzbek"></a>
# 🇺🇿 O'zbekcha

## Umumiy ko'rinish

```
Input: kamera kadrlari (Camera1, ~19 FPS)
         │
         ▼
  ┌─────────────────┐
  │  YOLO11n-pose   │  conf=0.1, batch_size=8
  │  (keypoint det) │
  └────────┬────────┘
           │  (F, 17, 3) — frame, joint, [x, y, conf]
           ▼
  ┌─────────────────┐
  │ Zero-frame fill │  forward-fill → backward-fill
  │ (interpolation) │
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │ Sliding window  │  T=30, stride=15
  └────────┬────────┘
           │  (N, 30, 17, 3)
           ▼
  ┌─────────────────┐
  │   ST-GCN        │  Stage 1
  │   (9 blocks)    │
  └────────┬────────┘
           │  fall probability p
           ▼
  ┌───────────────────────────────────┐
  │        Physics Rescue             │  Stage 2
  │  p >= 0.55  → FALL               │
  │  0.50 <= p < 0.55 → physics?     │
  │  p < 0.50   → NO-FALL            │
  └───────────────────────────────────┘
```

## ST-GCN (Spatial Temporal Graph Convolutional Network)

**Asosiy manba:** Yan et al., "Spatial Temporal Graph Convolutional Networks for Skeleton-Based Action Recognition", AAAI 2018.

### Skeleton grafik

17 ta COCO keypoint (YOLO11n-pose chiqishi):

```
0: nose          5: left_shoulder    11: left_hip
1: left_eye      6: right_shoulder   12: right_hip
2: right_eye     7: left_elbow       13: left_knee
3: left_ear      8: right_elbow      14: right_knee
4: right_ear     9: left_wrist       15: left_ankle
                10: right_wrist      16: right_ankle
```

**Adjacency matrix A** — shape (3, 17, 17), 3 ta subset:
- `A[0]` — self-link (har joint o'zi bilan)
- `A[1]` — centripetal (yelkalar, sonlar → markazga)
- `A[2]` — centrifugal (markazdan → qo'l, oyoq uchlari)

Center node: `11` (left_hip, BFS root)

### Arxitektura

```
Input: (N, C=3, T=30, V=17, M=1)

Block 1-3:   SpatialGCN(3→64)  + TemporalConv(64, stride=1)
Block 4-6:   SpatialGCN(64→128) + TemporalConv(128, stride=2 block4)
Block 7-9:   SpatialGCN(128→256) + TemporalConv(256, stride=2 block7)

GlobalAvgPool → Dropout(0.5) → Linear(256→2)

Output: (N, 2) logits  →  softmax  →  fall probability
```

Har bir STGCNBlock:
```
SpatialGCN:
  x → einsum(A, x) → BatchNorm → ReLU
  + learnable attention mask on A

TemporalConv:
  Conv2d(C, C, kernel=(9,1), padding=(4,0)) → BatchNorm → ReLU
  + residual connection (1x1 conv if channels change)
```

### Training sozlamalari

| Parametr | Qiymat |
|---|---|
| Epochs | 60 |
| Batch size | 32 |
| Optimizer | Adam (lr=1e-3, weight_decay=1e-4) |
| Scheduler | CosineAnnealingLR (T_max=60) |
| Dropout | 0.5 |
| Class imbalance | WeightedRandomSampler (FALL:NO-FALL = 1:~6) |
| Augmentation | Horizontal flip (p=0.5) + Gaussian noise (σ=0.01) |
| Best model | val fall F1 asosida saqlanadi |

## Physics Filter (Stage 2)

### Hisoblash

```python
# 1. Mid-hip Y koordinatini olish (COCO index 11, 12)
hip_y = (seq[:, 11, 1] + seq[:, 12, 1]) / 2.0   # 0=top, 1=bottom

# 2. Position filter (4 Hz Butterworth lowpass)
hip_y_filtered = lowpass(hip_y, fc=4.0)

# 3. Velocity (downward = positive)
velocity = gradient(hip_y_filtered, dt=1/fps)
velocity_f = lowpass(velocity, fc=8.0)

# 4. Acceleration
acceleration = gradient(velocity_f, dt=1/fps)
acceleration_f = lowpass(acceleration, fc=6.0)

# 5. Features
max_velocity = velocity_f.max()
max_abs_acc  = abs(acceleration_f).max()
hip_drop     = hip_y_filtered.max() - hip_y_filtered.min()
```

### Thresholdlar

Validation setida grid-search orqali topiladi:
- `vel_threshold = 0.0354` (normalized units/s)
- `acc_threshold = 0.3545` (normalized units/s²)

Qaror: `max_velocity > vel_threshold AND max_abs_acc > acc_threshold` → physics confirms fall

### Rescue mantiq

```
Stage 1 prob:
  ≥ 0.55  → FALL   (Stage 1 ishonchli, physics tekmaydi)
  [0.50, 0.55)  → physics qaror beradi  ← Rescue zone
  < 0.50  → NO-FALL
```

**Muhim farq eski AND mantiqdan:**
- **Eski (AND):** `Stage1=1 AND physics=1` — physics Stage 1 topganlarni o'chirishi mumkin
- **Yangi (Rescue):** physics faqat Stage 1 MISS qilganlarni qutqarishi mumkin

## Dataset tayyorlash

### YOLO keypoint extraction

```python
MODEL = YOLO("yolo11n-pose.pt")
# conf=0.1 — yiqilish posalari uchun past threshold
results = MODEL(batch, conf=0.1)

# eng ishonchli odamni olish
person_idx = keypoints.conf.sum(dim=1).argmax()

# normalizatsiya
xy_norm = xy_pixels / [image_width, image_height]  # [0, 1] oralig'ida
```

### Zero-frame interpolation

```python
def interpolate_zero_frames(kps):
    # Forward fill: oxirgi aniqlanganidan foydalanish
    for i in range(len(kps)):
        if frame_is_zero(kps[i]):
            kps[i] = last_valid_frame
    # Backward fill: boshidagi zero larni to'ldirish
    ...
```

**Natija:** Fall sequencelarda zero frame 14.5% → **0%**

### Sliding window

```
Trial (F frames) → windows:
  [0:30], [15:45], [30:60], ...

Window size T=30 (~1.58 sekund at 19 FPS)
Stride     S=15 (~0.79 sekund)
```

## Real-time Webcam Demo (`demo_webcam.py`)

### Asosiy dizayn qarorlari

| Qaror | Sabab |
|---|---|
| Shaxsiy bazaviy hip Y (EMA) | Kamera burchagi/masofasidan mustaqil — o'z baseline si |
| `is_lying()` sharti | Polda o'tirish (tik tana) va yotish (gorizontal) ni ajratadi |
| `--fast-fall` default OFF | Qariyalar asosan sekin yiqiladi; tez yiqilish yugurishda FP beradi |
| `--use-model` faqat ko'rsatish | ST-GCN UP-Fall lab datada train — webcam da domain shift; physics ishonchli |
| 5 soniya minimal qulf | Yiqilgandan so'ng harakatsiz holatda ham ogohlantirish saqlanadi |

### Ishga tushirish

```bash
python demo_webcam.py --physics-only --confirm 2 --slow-drop 0.12 --lying-confirm 2

# ST-GCN ehtimollik overlay bilan (faqat ko'rsatish, aniqlash physics da):
python demo_webcam.py --physics-only --use-model --confirm 2 --slow-drop 0.12 --lying-confirm 2
```

## Fayl manbalar

| Fayl | Tavsif |
|---|---|
| `stgcn/graph.py` | 17-joint COCO skeleton, adjacency matrix A(3,17,17) |
| `stgcn/model.py` | ST-GCN 9 block, learnable attention |
| `stgcn/physics.py` | Butterworth filter, threshold fitting, grid-search |
| `stgcn/two_stage.py` | TwoStageDetector, Rescue mantiq, tune_thresholds() |
| `prepare_cv_dataset.py` | YOLO extraction + interpolation + windowing |
| `train_two_stage.py` | To'liq pipeline: split → train → physics fit → evaluate |
| `demo_webcam.py` | Real-time webcam demo: physics aniqlash + ST-GCN overlay |
