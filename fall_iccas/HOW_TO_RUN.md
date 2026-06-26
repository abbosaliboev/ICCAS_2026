# How to Run MobiCare / 실행 방법 / Qanday Ishga Tushirish

> **Language / 언어 / Til**
> - [🇺🇸 English](#english)
> - [🇰🇷 한국어](#korean)
> - [🇺🇿 O'zbekcha](#uzbek)

---

<a name="english"></a>
# 🇺🇸 English

## System overview

```
[IP Camera] ──RTSP──► [Jetson Orin NX]  ──── Fall event POST ────► [Backend PC]
                       edge_server.py         http://PC_IP:8000      main.py
                       MJPEG :8081 ──────────────────────────────► [Phone/Browser]
                                                                     :8000/app
```

---

## 0. Prerequisites & Dependencies

**Python:** 3.10+ required

**Edge device (Jetson):**
```bash
# PyTorch for Jetson — install from NVIDIA wheel (torch 2.5.0a0, JetPack 6.1)
pip install torch-2.5.0a0+*.whl   # from /home/dalab/Desktop/edge_deploy_final_exp/

# NumPy must be < 2.0 (torch 2.5.0a0 compiled against NumPy 1.x)
pip install "numpy<2"

# Other dependencies
pip install ultralytics opencv-python scipy scikit-learn pandas matplotlib requests
```

**Training PC:**
```bash
pip install torch torchvision ultralytics opencv-python scipy scikit-learn pandas numpy matplotlib
```

**Backend server:**
```bash
cd backend && pip install -r requirements.txt
# requirements.txt includes: fastapi, uvicorn, httpx, pydantic
```

**Verify GPU is working:**
```bash
python3 -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"
# Expected: True  NVIDIA Jetson Orin Nano Super (or similar)
```

**Model files needed:**
```
fall_iccas/
├── yolo11n-pose.pt              # YOLO weights (6.3 MB) — from ultralytics
├── yolo11n-pose.engine          # TensorRT engine (8.8 MB) — auto-generated on first --tensorrt run
└── experiments/subject1_2_3_4/
    └── checkpoints/
        ├── best_stgcn.pth       # ST-GCN weights (12.5 MB) — from training
        └── two_stage_config.json  # tuned thresholds — from training
```

---

## 1. Backend server (PC / any machine)

```bash
cd backend
pip install -r requirements.txt
python main.py
```

Web app opens at: **http://localhost:8000/app**

To access from other devices (phone, Jetson):
- Find your PC IP: `ip addr` → e.g. `10.198.137.100`
- Open on phone: **http://10.198.137.100:8000/app**

---

## 2. Edge server (Jetson Orin NX)

### 2-1. Basic — USB/built-in camera (index 0)
```bash
cd fall_iccas
python edge_server.py
```

### 2-2. RTSP IP camera
```bash
python edge_server.py \
  --source "rtsp://admin:PASSWORD@CAMERA_IP:554/stream1"
```

### 2-3. RTSP + TensorRT (recommended for Jetson — faster YOLO)
```bash
python edge_server.py \
  --source "rtsp://admin:PASSWORD@CAMERA_IP:554/stream1" \
  --tensorrt
```
> First run: exports YOLO to `.engine` (~2 min). Subsequent runs: loads instantly.

### 2-4. Camera type (Settings → Camera → Camera Type)

| Camera placement | Setting | h_span threshold | Notes |
|---|---|:---:|---|
| Home camera — TV stand / wall | `front` (default) | 0.80 | Normal side-view skeleton |
| CCTV — ceiling / top-down | `top` | 0.35 | Skeleton appears compressed from above |

Set via **Settings → 📡 Camera → Camera Type** in the web app. Saved to `camera_config.json`.

### 2-5. Full options (connect to backend on another machine)
```bash
python edge_server.py \
  --source "rtsp://admin:PASSWORD@CAMERA_IP:554/stream1" \
  --backend "http://10.198.137.100:8000" \
  --device-token "edge-device-001" \
  --tensorrt \
  --stream-port 8081
```

### All arguments

| Argument | Default | Description |
|---|---|---|
| `--source` | `0` | Camera index (0) or RTSP URL |
| `--backend` | `http://localhost:8000` | Backend server address |
| `--device-token` | `edge-device-001` | Auth token for backend |
| `--stream-port` | `8081` | MJPEG stream port |
| `--tensorrt` | off | Use TensorRT for YOLO (Jetson GPU) |
| `--exp` | `experiments/subject1_2_3_4` | Model experiment directory |
| `--display` | off | Show OpenCV window (needs monitor) |
| `--confirm` | `3` | Fall windows needed to trigger alert |
| `--min-lock` | `5.0` | Seconds to hold FALL alert |
| `--stand-streak` | `2` | Standing windows to auto-reset |
| `--width` | `640` | Camera capture width |
| `--height` | `480` | Camera capture height |
| `--snap-dir` | `snapshots/` | Directory to save fall screenshots |

---

## 3. View the stream

| What | URL |
|---|---|
| MJPEG stream (direct) | `http://JETSON_IP:8081/video` |
| Web app with stream | `http://PC_IP:8000/app` |
| Stream URL to paste in app | `http://JETSON_IP:8081/video` |

> In the web app: paste the MJPEG URL into the **Stream URL** box and click **Connect**.

---

## 4. Training (on a PC with GPU)

### Step 1: Extract keypoints from UP-Fall dataset images
```bash
cd fall_iccas
python prepare_cv_dataset.py
```
Requires: `dataset/SubjectN/ActivityN/TrialN/Camera1/` images
Output: `cv_dataset/X.npy`, `y.npy`, `meta.csv`

### Step 2: Train the two-stage model
```bash
python train_two_stage.py
```
Output: `checkpoints/best_stgcn.pth`, `checkpoints/two_stage_config.json`

### Step 3: Run FPS benchmark (Jetson only)
```bash
python bench_fps.py
```
Output: `FPS_BENCHMARK.md` with per-component timings

---

## 5. Project structure

```
ICCAS_2026/
├── fall_iccas/             # Main fall detection code (Jetson)
│   ├── edge_server.py      # Real-time edge server ← run this on Jetson
│   ├── train_two_stage.py  # Training pipeline ← run this on PC
│   ├── prepare_cv_dataset.py
│   ├── bench_fps.py        # FPS benchmark
│   ├── stgcn/              # Model code
│   │   ├── model.py        # ST-GCN
│   │   ├── graph.py        # COCO skeleton
│   │   ├── physics.py      # PhysicsFilter
│   │   └── two_stage.py    # TwoStageDetector
│   ├── experiments/
│   │   └── subject1_2_3_4/ # Current best model
│   │       └── checkpoints/
│   │           ├── best_stgcn.pth
│   │           └── two_stage_config.json
│   ├── yolo11n-pose.pt     # YOLO weights
│   └── yolo11n-pose.engine # TensorRT engine (auto-generated)
└── backend/                # Web backend (PC)
    ├── main.py             # FastAPI server ← run this on PC
    ├── db.py               # SQLite database
    └── static/index.html   # Web UI
```

---

## 6. Troubleshooting

### Camera not opening (RTSP)
```
[EDGE] Camera not connected — retrying...
```
- Check camera IP: `ping CAMERA_IP`
- Try URL in VLC: `Media → Open Network Stream`
- Password special chars must be URL-encoded: `$` → `%24`

### CUDA out of memory on Jetson
Always use `--tensorrt` — it runs YOLO on TRT and ST-GCN on CPU automatically.
Never run both YOLO and ST-GCN on CUDA simultaneously on Jetson (allocator conflict).

### torchvision import error
```
PackageNotFoundError: torchvision
```
Already patched. If it reappears after ultralytics upgrade, re-apply the patch:
```python
# In ultralytics/utils/__init__.py line ~55:
try:
    TORCHVISION_VERSION = importlib.metadata.version("torchvision")
except Exception:
    TORCHVISION_VERSION = "0.0.0"
```

### NumPy 2.x error
```bash
pip install "numpy<2"
```

---

<a name="korean"></a>
# 🇰🇷 한국어

## 시스템 구조

```
[IP 카메라] ──RTSP──► [Jetson Orin NX]  ── Fall 이벤트 POST ──► [백엔드 PC]
                       edge_server.py        http://PC_IP:8000     main.py
                       MJPEG :8081 ──────────────────────────────► [폰/브라우저]
                                                                    :8000/app
```

---

## 1. 백엔드 서버 (PC)

```bash
cd backend
pip install -r requirements.txt
python main.py
```

웹앱: **http://localhost:8000/app**

다른 기기(폰, Jetson)에서 접속:
- PC IP 확인: `ip addr` → 예: `10.198.137.100`
- 폰에서 접속: **http://10.198.137.100:8000/app**

---

## 2. 엣지 서버 (Jetson Orin NX)

### 2-1. 기본 — USB 카메라 (인덱스 0)
```bash
cd fall_iccas
python edge_server.py
```

### 2-2. RTSP IP 카메라
```bash
python edge_server.py \
  --source "rtsp://admin:PASSWORD@CAMERA_IP:554/stream1"
```

### 2-3. RTSP + TensorRT (Jetson 권장)
```bash
python edge_server.py \
  --source "rtsp://admin:PASSWORD@CAMERA_IP:554/stream1" \
  --tensorrt
```
> 최초 실행 시 `.engine` 변환 (~2분). 이후 즉시 로드.

### 2-4. 전체 옵션 (다른 PC의 백엔드에 연결)
```bash
python edge_server.py \
  --source "rtsp://admin:PASSWORD@CAMERA_IP:554/stream1" \
  --backend "http://10.198.137.100:8000" \
  --device-token "edge-device-001" \
  --tensorrt \
  --stream-port 8081
```

### 전체 인자

| 인자 | 기본값 | 설명 |
|---|---|---|
| `--source` | `0` | 카메라 인덱스 또는 RTSP URL |
| `--backend` | `http://localhost:8000` | 백엔드 서버 주소 |
| `--device-token` | `edge-device-001` | 백엔드 인증 토큰 |
| `--stream-port` | `8081` | MJPEG 스트림 포트 |
| `--tensorrt` | 꺼짐 | TensorRT 엔진 사용 (Jetson GPU) |
| `--exp` | `experiments/subject1_2_3_4` | 모델 실험 디렉토리 |
| `--display` | 꺼짐 | OpenCV 윈도우 표시 (모니터 필요) |
| `--confirm` | `3` | 알림 전 연속 FALL 윈도우 수 |
| `--min-lock` | `5.0` | FALL 알림 유지 시간 (초) |
| `--stand-streak` | `2` | 자동 리셋을 위한 서 있는 윈도우 수 |
| `--width` | `640` | 카메라 캡처 너비 |
| `--height` | `480` | 카메라 캡처 높이 |
| `--snap-dir` | `snapshots/` | 낙상 스크린샷 저장 디렉토리 |

---

## 3. 스트림 보기

| 내용 | URL |
|---|---|
| MJPEG 스트림 (직접) | `http://JETSON_IP:8081/video` |
| 웹앱 (스트림 포함) | `http://PC_IP:8000/app` |
| 앱에 붙여넣을 URL | `http://JETSON_IP:8081/video` |

---

## 4. 학습 (GPU 있는 PC에서)

```bash
# 1단계: UP-Fall 이미지에서 키포인트 추출
python prepare_cv_dataset.py

# 2단계: 2단계 모델 학습
python train_two_stage.py

# 3단계: FPS 벤치마크 (Jetson에서)
python bench_fps.py
```

---

## 5. 문제 해결

### RTSP 카메라 연결 안 됨
- 카메라 IP 확인: `ping CAMERA_IP`
- VLC로 테스트: `미디어 → 네트워크 스트림 열기`
- 비밀번호 특수문자 URL 인코딩: `$` → `%24`

### Jetson CUDA 메모리 충돌
항상 `--tensorrt` 사용 — YOLO는 TRT, ST-GCN은 CPU로 자동 분리됨.
Jetson에서 두 모델을 동시에 CUDA로 실행하지 말 것 (할당자 충돌).

### NumPy 버전 오류
```bash
pip install "numpy<2"
```

---

<a name="uzbek"></a>
# 🇺🇿 O'zbekcha

## Tizim tuzilishi

```
[IP Kamera] ──RTSP──► [Jetson Orin NX]  ── Fall event POST ──► [Backend PC]
                       edge_server.py        http://PC_IP:8000    main.py
                       MJPEG :8081 ─────────────────────────────► [Telefon/Brauzer]
                                                                   :8000/app
```

---

## 1. Backend server (PC da)

```bash
cd backend
pip install -r requirements.txt
python main.py
```

Web ilova: **http://localhost:8000/app**

Boshqa qurilmalardan (telefon, Jetson) kirish:
- PC IP ni toping: `ip addr` → masalan: `10.198.137.100`
- Telefondan: **http://10.198.137.100:8000/app**

---

## 2. Edge server (Jetson Orin NX da)

### 2-1. Oddiy — USB kamera (0-indeks)
```bash
cd fall_iccas
python edge_server.py
```

### 2-2. RTSP IP kamera
```bash
python edge_server.py \
  --source "rtsp://admin:PAROL@KAMERA_IP:554/stream1"
```

### 2-3. RTSP + TensorRT (Jetson uchun tavsiya)
```bash
python edge_server.py \
  --source "rtsp://admin:PAROL@KAMERA_IP:554/stream1" \
  --tensorrt
```
> Birinchi ishga tushirganda `.engine` ga eksport qiladi (~2 daqiqa). Keyingi safar tez yuklanadi.

### 2-4. To'liq — boshqa PC dagi backendga ulash
```bash
python edge_server.py \
  --source "rtsp://admin:PAROL@KAMERA_IP:554/stream1" \
  --backend "http://10.198.137.100:8000" \
  --device-token "edge-device-001" \
  --tensorrt \
  --stream-port 8081
```

### Barcha argumentlar

| Argument | Default | Izoh |
|---|---|---|
| `--source` | `0` | Kamera indeksi yoki RTSP URL |
| `--backend` | `http://localhost:8000` | Backend server manzili |
| `--device-token` | `edge-device-001` | Backend uchun auth token |
| `--stream-port` | `8081` | MJPEG stream porti |
| `--tensorrt` | o'chiq | TensorRT ishlatish (Jetson GPU) |
| `--exp` | `experiments/subject1_2_3_4` | Model experiment papkasi |
| `--display` | o'chiq | OpenCV oynasini ko'rsatish |
| `--confirm` | `3` | Ogohlantirish uchun ketma-ket FALL oynalari |
| `--min-lock` | `5.0` | FALL ogohlantirishni ushlab turish vaqti (soniya) |
| `--stand-streak` | `2` | Avtomatik reset uchun turib turish oynalari |
| `--width` | `640` | Kamera eni (piksel) |
| `--height` | `480` | Kamera balandligi (piksel) |
| `--snap-dir` | `snapshots/` | Yiqilish screenshotlari papkasi |

---

## 3. Stream ko'rish

| Nima | URL |
|---|---|
| MJPEG stream (to'g'ridan) | `http://JETSON_IP:8081/video` |
| Web ilova (stream bilan) | `http://PC_IP:8000/app` |
| Ilovaga joylashtiriladigan URL | `http://JETSON_IP:8081/video` |

> Web ilovada: **Stream URL** maydoniga MJPEG URL ni joylashtiring va **Connect** bosing.

---

## 4. Trening (GPU li PC da)

```bash
# 1-qadam: UP-Fall rasmlaridan keypointlarni ajratib olish
python prepare_cv_dataset.py

# 2-qadam: Ikki bosqichli modelni trening qilish
python train_two_stage.py

# 3-qadam: FPS benchmark (Jetson da)
python bench_fps.py
```

---

## 5. Muammolarni hal qilish

### RTSP kamera ochilmayapti
- Kamera IP ni tekshiring: `ping KAMERA_IP`
- VLC da test qiling: `Media → Open Network Stream`
- Parolda maxsus belgilar URL-encode qilinishi kerak: `$` → `%24`

### Jetson CUDA xotira xatosi
Doim `--tensorrt` ishlatilsin — YOLO TRT da, ST-GCN CPU da avtomatik ishlaydi.
Jetson da ikkala modelni bir vaqtda CUDA da ishlatmang (allocator konflikti).

### NumPy versiya xatosi
```bash
pip install "numpy<2"
```
