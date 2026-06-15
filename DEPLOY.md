# MobiCare — Jetson Orin NX Deployment Guide

## Architecture

```
[Camera] → [Jetson Orin NX]          → [Backend Server]   → [Mobile Browser]
            edge_server.py              backend/main.py       http://SERVER_IP:8000
            :8081/video (MJPEG)         :8000 (REST + WS)
```

## Jetson Orin NX Setup

### 1. Copy project to Jetson
```bash
rsync -av fall_iccas/ user@JETSON_IP:~/mobicare/fall_iccas/
```

### 2. Install dependencies (JetPack already has PyTorch + CUDA)
```bash
pip install ultralytics opencv-python scipy scikit-learn
```

### 3. First run — downloads YOLO model
```bash
cd ~/mobicare/fall_iccas
python edge_server.py --display       # with monitor
python edge_server.py                 # headless (SSH)
```

### 4. TensorRT acceleration (recommended for Jetson — up to 3× faster)
```bash
python edge_server.py --tensorrt      # exports engine on first run (~2 min), then loads it
```

### 5. IP camera (RTSP)
```bash
python edge_server.py --source "rtsp://admin:password@192.168.1.100/stream"
```

### Full options
```
--exp          experiments/subject1_2_3_4   Trained model directory
--source       0                             Camera index or RTSP URL
--backend      http://SERVER_IP:8000         Backend server URL
--device-token edge-device-001               Token for backend auth
--stream-port  8081                          MJPEG stream port
--confirm      3                             Consecutive FALL windows to trigger
--min-lock     5.0                           Seconds to hold alert before auto-reset
--display                                    Show CV2 window (needs X display)
--tensorrt                                   Use TensorRT YOLO (Jetson only)
```

## Backend Server Setup

Can run on Jetson or a separate PC.

### 1. Install
```bash
cd backend
pip install -r requirements.txt
```

### 2. Run
```bash
python main.py
# → http://0.0.0.0:8000
```

### 3. Autostart (systemd)
```ini
# /etc/systemd/system/mobicare-backend.service
[Unit]
Description=MobiCare Backend
After=network.target

[Service]
WorkingDirectory=/home/user/mobicare/backend
ExecStart=python main.py
Restart=always

[Install]
WantedBy=multi-user.target
```

## Mobile Web App

1. Open `http://SERVER_IP:8000` on your phone
2. Login: `user1 / 1234` (실사용자) or `guardian1 / 1234` (보호자)
3. Go to **설정** → enter the Jetson stream URL: `http://JETSON_IP:8081/video`
4. Save → live feed appears on Dashboard

### Add to Home Screen (PWA-style)
- iOS Safari: Share → Add to Home Screen
- Android Chrome: Menu → Add to Home Screen

## Complete startup (same Jetson for everything)

```bash
# Terminal 1 — backend
cd ~/mobicare/backend && python main.py

# Terminal 2 — edge inference
cd ~/mobicare/fall_iccas && python edge_server.py \
  --backend http://localhost:8000 \
  --tensorrt
```

## Demo Accounts

| Username  | Password | Role    |
|-----------|----------|---------|
| user1     | 1234     | 실사용자 |
| guardian1 | 1234     | 보호자  |

Device token: `edge-device-001`

## API Reference (quick)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/login` | Login |
| POST | `/api/auth/register` | Register |
| GET | `/api/fall-events` | List fall events |
| POST | `/api/fall-events` | Report fall (from edge, X-Device-Token) |
| POST | `/api/fall-events/{id}/video` | Upload clip (from edge) |
| GET | `/api/fall-events/{id}/video/file` | Download clip |
| GET | `/api/fall-events/{id}/emergency-report` | 119 report data |
| WS | `/ws?token=TOKEN` | Real-time push |
| GET | `/api/heatmap` | Risk zone data |
