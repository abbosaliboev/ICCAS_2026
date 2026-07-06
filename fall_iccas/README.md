# Fall Detection — ST-GCN + Physics Rescue
**ICCAS 2026 paper project**

> **Language / 언어**
> - [🇺🇸 English](#english)
> - [🇰🇷 한국어](#korean)

---

<a name="english"></a>
# 🇺🇸 English

Camera-based fall detection: ST-GCN skeleton model + physics rule filter (2-stage).

## Architecture

```
Camera frames
      │
      ▼
YOLO11n-pose  →  17 COCO keypoints (x, y, conf)
      │
      ▼
Sliding window (T=30, stride=15, ~19 FPS)
      │
      ▼
ST-GCN (Stage 1)  →  fall probability p
      │
      ├── p >= 0.55  →  FALL  (confident)
      ├── 0.50 <= p < 0.55  →  Physics Filter decides (Rescue zone)
      └── p < 0.50  →  NO-FALL
```

**Physics Filter** (Stage 2 — Rescue mode):
- Butterworth low-pass filter on the hip Y coordinate
- Computes velocity and acceleration thresholds
- Only activates when Stage 1 is uncertain (it never removes Stage 1 detections)

## Dataset

**UP-Fall Detection Dataset** (Martínez-Villaseñor et al., Sensors 2019)
- 17 subjects, 11 activities, 3 trials
- Camera1 images used
- Activities 1–5 = FALL, Activities 6–11 = NO-FALL

| Activity | Name | Label |
|---|---|---|
| 1 | Falling forward (hands) | FALL |
| 2 | Falling forward (knees) | FALL |
| 3 | Falling sideways | FALL |
| 4 | Falling backward | FALL |
| 5 | Hitting obstacle | FALL |
| 6 | Sitting abruptly | NO-FALL |
| 7 | Walking | NO-FALL |
| 8 | Standing | NO-FALL |
| 9 | Sitting | NO-FALL |
| 10 | Picking up object | NO-FALL |
| 11 | Jumping | NO-FALL |

## Files

```
fall_iccas/
├── dataset/                    # UP-Fall images (Subject1-17)
├── cv_dataset/
│   ├── X.npy                   # (N, 30, 17, 3) — keypoint sequences
│   ├── y.npy                   # (N,) — 0/1 labels
│   └── meta.csv                # subject/activity/trial info
├── checkpoints/
│   ├── best_stgcn.pth          # best ST-GCN model
│   └── two_stage_config.json   # thresholds
├── stgcn/
│   ├── model.py                # ST-GCN architecture
│   ├── graph.py                # 17-joint COCO skeleton graph
│   ├── physics.py              # PhysicsFilter
│   └── two_stage.py            # TwoStageDetector (Rescue mode)
├── prepare_cv_dataset.py       # YOLO keypoint extraction
├── train_two_stage.py          # Full training pipeline
└── label_dataset.py            # Sensor CSV labeling (optional)
```

## Usage

### 1. Prepare the dataset
```bash
python prepare_cv_dataset.py
```
Produces `cv_dataset/X.npy`, `y.npy`, `meta.csv`.

### 2. Train
```bash
python train_two_stage.py
```
Results are printed to the terminal; the model is saved to `checkpoints/`.

### 3. Run the edge server

**With USB/webcam (camera index 0):**
```bash
python edge_server.py
```

**With RTSP IP camera:**
```bash
python edge_server.py --source "rtsp://admin:PASSWORD@CAMERA_IP:554/stream1"
```

**With RTSP + TensorRT (recommended on Jetson — faster YOLO):**
```bash
python edge_server.py \
  --source "rtsp://admin:PASSWORD@CAMERA_IP:554/stream1" \
  --backend "http://PC_IP:8000" \
  --tensorrt
```

| What | URL |
|---|---|
| MJPEG stream | `http://JETSON_IP:8081/video` |
| Web app | `http://PC_IP:8000/app` |

> Password special characters must be URL-encoded: `$` → `%24`
> Full argument list: see [HOW_TO_RUN.md](HOW_TO_RUN.md)

## Current results (Subject 1–4, subject-stratified split)

| Model | Accuracy | Fall F1 | Precision | Recall |
|---|---|---|---|---|
| ST-GCN (Stage 1) | 98.5% | 0.950 | 0.95 | 0.95 |
| ST-GCN + Physics Rescue | 98.7% | **0.955** | 0.95 | 0.96 |

> **Important:** Results are subject-dependent (trained/tested on Subjects 1–4 with stratified split).
> For publication, LOSO (Leave-One-Subject-Out) across all 17 subjects is required.
> See [RESULTS.md](RESULTS.md) for full run history and ablation.

## Model size & complexity

| Component | Params | Size |
|---|---|---|
| ST-GCN | 3.1 M | 12.5 MB (.pth) |
| YOLO11n-pose | ~2.9 M | 6.3 MB (.pt) / 8.8 MB (.engine) |

## Key technical settings

| Parameter | Value |
|---|---|
| YOLO model | yolo11n-pose.pt |
| YOLO conf threshold | 0.1 (low, to detect fall poses) |
| Window size | 30 frames (~1.6 s at 19 fps) |
| Stride | 15 frames (~0.8 s) |
| FPS | ~19 Hz |
| ST-GCN channels | 64→64→64→128→128→128→256→256→256 |
| ST-GCN blocks | 9 |
| Optimizer | Adam lr=1e-3, weight_decay=1e-4 |
| Scheduler | CosineAnnealingLR |
| Training GPU | NVIDIA TITAN RTX 24GB |
| Inference device | Jetson Orin Nano Super (TRT+CPU) |

## Problems solved

1. **Zero-frame problem** — During falls, YOLO failed to detect the person and output zeros (14.5% of fall frames). Solution: `conf=0.1` + forward-fill interpolation → 0% zero frames.
2. **Camera folder naming error** — Every trial folder was named `Activity2`. Fixed with a PowerShell script (54 folders).
3. **Physics filter being harmful** — The old AND logic deleted Stage 1 detections. Solved with the new "Rescue" logic (physics only acts on uncertain cases).

---

<a name="korean"></a>
# 🇰🇷 한국어

카메라 영상 기반 낙상 감지: ST-GCN 스켈레톤 모델 + 물리 규칙 필터 (2단계).

## 아키텍처

```
카메라 프레임
      │
      ▼
YOLO11n-pose  →  17개 COCO 키포인트 (x, y, conf)
      │
      ▼
슬라이딩 윈도우 (T=30, stride=15, ~19 FPS)
      │
      ▼
ST-GCN (Stage 1)  →  낙상 확률 p
      │
      ├── p >= 0.55  →  FALL  (확신)
      ├── 0.50 <= p < 0.55  →  Physics Filter가 결정 (Rescue zone)
      └── p < 0.50  →  NO-FALL
```

**Physics Filter** (Stage 2 — Rescue 모드):
- 엉덩이(Hip) Y 좌표에 Butterworth 저역통과 필터 적용
- 속도와 가속도 임계값 계산
- Stage 1이 불확실할 때만 작동 (Stage 1이 감지한 것을 절대 제거하지 않음)

## 데이터셋

**UP-Fall Detection Dataset** (Martínez-Villaseñor et al., Sensors 2019)
- 피험자 17명, 활동 11종, 시행 3회
- Camera1 이미지 사용
- Activity 1–5 = FALL, Activity 6–11 = NO-FALL

| Activity | 이름 | 라벨 |
|---|---|---|
| 1 | 앞으로 넘어짐 (손) | FALL |
| 2 | 앞으로 넘어짐 (무릎) | FALL |
| 3 | 옆으로 넘어짐 | FALL |
| 4 | 뒤로 넘어짐 | FALL |
| 5 | 장애물에 부딪힘 | FALL |
| 6 | 갑자기 앉기 | NO-FALL |
| 7 | 걷기 | NO-FALL |
| 8 | 서 있기 | NO-FALL |
| 9 | 앉아 있기 | NO-FALL |
| 10 | 물건 줍기 | NO-FALL |
| 11 | 점프 | NO-FALL |

## 파일 구조

```
fall_iccas/
├── dataset/                    # UP-Fall 이미지 (Subject1-17)
├── cv_dataset/
│   ├── X.npy                   # (N, 30, 17, 3) — 키포인트 시퀀스
│   ├── y.npy                   # (N,) — 0/1 라벨
│   └── meta.csv                # subject/activity/trial 정보
├── checkpoints/
│   ├── best_stgcn.pth          # 최고 성능 ST-GCN 모델
│   └── two_stage_config.json   # 임계값
├── stgcn/
│   ├── model.py                # ST-GCN 아키텍처
│   ├── graph.py                # 17관절 COCO 스켈레톤 그래프
│   ├── physics.py              # PhysicsFilter
│   └── two_stage.py            # TwoStageDetector (Rescue 모드)
├── prepare_cv_dataset.py       # YOLO 키포인트 추출
├── train_two_stage.py          # 전체 학습 파이프라인
└── label_dataset.py            # 센서 CSV 라벨링 (선택)
```

## 사용 방법

### 1. 데이터셋 준비
```bash
python prepare_cv_dataset.py
```
`cv_dataset/X.npy`, `y.npy`, `meta.csv`가 생성됩니다.

### 2. 학습
```bash
python train_two_stage.py
```
결과는 터미널에 출력되고, 모델은 `checkpoints/`에 저장됩니다.

### 3. 엣지 서버 실행

**USB/웹캠으로 (카메라 인덱스 0):**
```bash
python edge_server.py
```

**RTSP IP 카메라로:**
```bash
python edge_server.py --source "rtsp://admin:PASSWORD@CAMERA_IP:554/stream1"
```

**RTSP + TensorRT (Jetson 권장):**
```bash
python edge_server.py \
  --source "rtsp://admin:PASSWORD@CAMERA_IP:554/stream1" \
  --backend "http://PC_IP:8000" \
  --tensorrt
```

| 내용 | URL |
|---|---|
| MJPEG 스트림 | `http://JETSON_IP:8081/video` |
| 웹앱 | `http://PC_IP:8000/app` |

> 비밀번호 특수문자 URL 인코딩 필요: `$` → `%24`
> 전체 인자 목록: [HOW_TO_RUN.md](HOW_TO_RUN.md) 참조

## 현재 결과 (Subject 1–4, subject-stratified split)

| 모델 | Accuracy | Fall F1 | Precision | Recall |
|---|---|---|---|---|
| ST-GCN (Stage 1) | 98.5% | 0.950 | 0.95 | 0.95 |
| ST-GCN + Physics Rescue | 98.7% | **0.955** | 0.95 | 0.96 |

> **중요:** Subject 1–4의 subject-dependent 결과입니다.
> 논문 제출을 위해서는 전체 17명 대상 LOSO 평가가 필요합니다.
> 전체 실행 기록은 [RESULTS.md](RESULTS.md) 참조.

## 모델 크기 및 복잡도

| 구성 요소 | 파라미터 수 | 크기 |
|---|---|---|
| ST-GCN | 3.1 M | 12.5 MB (.pth) |
| YOLO11n-pose | ~2.9 M | 6.3 MB (.pt) / 8.8 MB (.engine) |

## 주요 기술 설정

| 파라미터 | 값 |
|---|---|
| YOLO 모델 | yolo11n-pose.pt |
| YOLO conf 임계값 | 0.1 (낮음, 낙상 자세 감지를 위해) |
| 윈도우 크기 | 30 프레임 (~1.6초 at 19fps) |
| Stride | 15 프레임 (~0.8초) |
| FPS | ~19 Hz |
| ST-GCN 채널 | 64→64→64→128→128→128→256→256→256 |
| ST-GCN 블록 수 | 9 |
| Optimizer | Adam lr=1e-3, weight_decay=1e-4 |
| Scheduler | CosineAnnealingLR |
| 학습 GPU | NVIDIA TITAN RTX 24GB |
| 추론 장치 | Jetson Orin Nano Super (TRT+CPU) |

## 해결한 문제들

1. **Zero frame 문제** — 낙상 중에 YOLO가 사람을 찾지 못해 0을 출력 (낙상 프레임의 14.5%). 해결: `conf=0.1` + forward-fill 보간 → zero frame 0%.
2. **카메라 폴더 이름 오류** — 모든 trial에 `Activity2`라는 이름이 붙어 있었음. PowerShell 스크립트로 수정 (54개 폴더).
3. **Physics filter의 역효과** — 기존 AND 로직이 Stage 1의 감지 결과를 삭제함. 새로운 "Rescue" 로직으로 해결 (physics는 불확실한 경우에만 작동).

