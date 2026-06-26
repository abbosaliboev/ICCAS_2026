# MobiCare Feature List / 기능 목록 / Xususiyatlar Ro'yxati

> **Language / 언어 / Til**
> - [🇺🇸 English](#english)
> - [🇰🇷 한국어](#korean)
> - [🇺🇿 O'zbekcha](#uzbek)

---

<a name="english"></a>
# 🇺🇸 English

## System Overview

MobiCare is a real-time, camera-based fall detection system for elderly people living alone. It combines a skeleton-based deep learning model (ST-GCN) with a physics rule filter, deployed on an NVIDIA Jetson edge device, and monitored via a web/mobile dashboard.

```
[IP Camera / Webcam]
        │ RTSP / USB
        ▼
[Jetson Edge Server]  ─── Fall Event ──► [Backend Server]
  YOLO pose detect                         FastAPI + SQLite
  ST-GCN + Physics                              │
  MJPEG stream ◄───── Browser/Phone ◄──── Web Dashboard
```

---

## 1. Fall Detection Pipeline

| Stage | Component | Detail |
|---|---|---|
| 1 | Camera | RTSP IP camera or USB webcam |
| 2 | Pose estimation | YOLO11n-pose (17 COCO keypoints, conf=0.1) |
| 3 | Preprocessing | Zero-frame forward/backward fill |
| 4 | Sliding window | T=30 frames, stride=15 (~19 fps) |
| 5 | Stage 1 | ST-GCN (9 blocks, 3.1M params) → fall probability |
| 6 | Stage 2 | Physics Rescue filter (Butterworth + threshold) |
| 7 | Decision | p≥0.55 → FALL, 0.45≤p<0.55 → Physics, p<0.45 → OK |

**Key technical choices:**
- YOLO `conf=0.1` — intentionally low to detect fall poses with low visibility
- Zero-frame fill — YOLO misses people mid-fall; interpolation fixes 14.5% → 0% zero frames
- Physics Rescue (not AND) — physics only adds detections, never removes Stage-1 positives

---

## 2. Edge Server (`edge_server.py`)

| Feature | Description |
|---|---|
| MJPEG stream | Live video at `http://JETSON_IP:8081/video` (854×480, JPEG q=70) |
| Skeleton overlay | COCO 17-joint skeleton drawn on stream |
| Fall bounding box | Red box + "FALL" label around person during active alert |
| Safe zone overlay | Green semi-transparent zone drawn on stream |
| Camera type support | `front` (normal) or `top` (CCTV ceiling) — adjusts h_span threshold |
| RTSP reconnect | Auto-reconnects every 2–3 s on stream drop |
| Auto-reset | Person stands up → resets fall state automatically |
| TensorRT | YOLO runs as TRT engine (GPU); ST-GCN on CPU (Jetson allocator conflict) |
| Screenshot | 1280×720 JPEG saved and uploaded to backend on fall detection |

---

## 3. Safe Zone

- User draws a rectangle on a live snapshot in Settings
- Stored as normalized `[x1, y1, x2, y2]` in `safe_zone.json`
- Edge server checks mid-hip coordinate every frame
- If hip is inside zone → fall streak reset → no alert triggered
- Use case: bed, sofa — places where lying down is normal

---

## 4. Camera Type Adaptation

| Type | Setting | h_span threshold | Use case |
|---|---|---|---|
| Front-facing | `front` | 0.80 | Home camera on TV stand, wall mount |
| Top-down | `top` | 0.35 | CCTV ceiling mount, bird's-eye view |

The skeleton appears compressed vertically in top-down view — threshold is lowered accordingly.

---

## 5. Web Dashboard

| Feature | Description |
|---|---|
| Live MJPEG stream | Embedded in dashboard, connects via URL |
| Fall status | Animated pulsing dot (green=normal, red=alert) + live clock |
| Emergency call | Red call button with configurable contact name/number |
| Recent falls | Last N events shown on dashboard |
| WebSocket | Real-time fall alerts and auto-reset notifications |
| Multilingual | 6 languages: Korean, English, Spanish, French, Russian, Chinese |

---

## 6. Fall History

| Feature | Description |
|---|---|
| Event list | Chronological list with severity, time, acknowledged status |
| Screenshot viewer | Full-screen image with pinch-to-zoom |
| Detail page | Emergency info, fall time, category, video/screenshot |
| Delete | Swipe-to-delete with select-all mode |
| Acknowledge | Mark fall as confirmed |

---

## 7. Reports Page

| Feature | Description |
|---|---|
| Period filter | Today / This Week / This Month / All |
| Summary stats | Total falls, Peak hour, Severe count, Last event (time ago) |
| Bar chart | 7-day fall history (pure CSS, no external lib) |
| CSV export | Client-side generation, UTF-8 BOM, downloadable |
| PDF export | Standalone HTML page opens in new tab → browser print → Save as PDF |
| Email send | `mailto:` opens device email app with report pre-filled |
| Scheduled reports | Configure email + SMS + frequency (daily/weekly/monthly) |

---

## 8. Settings (Accordion UI)

| Section | Fields |
|---|---|
| 🎨 Appearance | Theme (dark/light), Language (6 options) |
| 📞 Emergency Contact | Name + phone → shown as call button on dashboard |
| 📡 Camera | Stream URL, Device token, Camera type (front/top) |
| 📅 Report Schedule | Email, SMS, Frequency |
| 🛏 Safe Zone | Draw zone on snapshot, clear zone |
| 👤 Account | Name, Age, Height, Weight, Gender, Phone, Address |

---

## 9. User Profile & Personalization

Registration collects:
- Name, username, password, role (user/guardian)
- Age, **height (cm)**, **weight (kg)**, **gender**
- Phone, address, guardian link

Height/weight/gender are stored and can be used to personalize thresholds in future versions.

---

## 10. Backend API

| Endpoint | Method | Description |
|---|---|---|
| `/api/auth/login` | POST | Login → JWT token |
| `/api/auth/register` | POST | Register with profile |
| `/api/users/me` | GET / PUT | Get / update profile |
| `/api/fall-events` | GET / POST | List / create fall events |
| `/api/fall-events/{id}/screenshot` | GET / POST | Screenshot |
| `/api/fall-events/{id}/resolve` | POST | Mark resolved (WebSocket broadcast) |
| `/api/safe-zone` | GET / POST / DELETE | Safe zone config |
| `/api/safe-zone/camera-type` | POST | Save camera type |
| `/api/reports/send-email` | POST | (stub) Send report email |
| `/api/stream/video` | GET | MJPEG stream proxy |
| `/api/stream/snapshot` | GET | Latest frame JPEG |
| `/ws` | WebSocket | Real-time fall_detected / fall_resolved |

---

## 11. Hardware & Performance (Jetson Orin Nano Super, jetson_clocks)

| Component | Backend | FPS | Latency |
|---|---|:---:|:---:|
| YOLO11n-pose | PyTorch (GPU) | 28.8 | 35 ms |
| YOLO11n-pose | **TensorRT (GPU)** | **89.2** | **11 ms** |
| ST-GCN + Physics | CPU | 22.5 | 44 ms |
| Full pipeline (TRT+CPU) | — | **68.7** | **15 ms** |
| Real deployment (camera-limited) | — | ~25–30 | — |

---

## 12. Deployment

```
Jetson Orin Nano Super:
  python edge_server.py
    --source "rtsp://IP/stream1"
    --backend "http://PC_IP:8000"
    --tensorrt

Backend (PC):
  cd backend && python main.py
  → http://0.0.0.0:8000

Web: http://PC_IP:8000/app
Stream: http://JETSON_IP:8081/video
```

---

<a name="korean"></a>
# 🇰🇷 한국어

## 시스템 개요

MobiCare는 독거 노인을 위한 실시간 카메라 기반 낙상 감지 시스템입니다. ST-GCN 딥러닝 모델과 물리 규칙 필터를 결합하여 NVIDIA Jetson 엣지 디바이스에 배포하고 웹/모바일 대시보드로 모니터링합니다.

## 주요 기능 목록

### 1. 낙상 감지 파이프라인
- YOLO11n-pose로 17개 키포인트 추출 (conf=0.1)
- Zero-frame 보간으로 낙상 중 미검출 문제 해결
- ST-GCN 9블록 모델 (3.1M 파라미터) → 낙상 확률
- Physics Rescue 필터 (AND 아님, 추가만 함)
- 연속 3회 FALL 윈도우 → 알림 발생

### 2. 엣지 서버
- MJPEG 라이브 스트리밍 (854×480)
- 스켈레톤 및 바운딩 박스 오버레이
- RTSP 자동 재연결
- TensorRT 가속 (YOLO: 89.2fps, 11ms)
- 낙상 자동 해제 (기립 감지)
- 스크린샷 자동 업로드

### 3. 안전 구역
- 침대/소파 영역 수동 지정 (스냅샷에서 드래그)
- 해당 구역에서는 낙상 알림 미발생

### 4. 카메라 유형
- 정면 홈 카메라: h_span 임계값 0.80
- 천장 CCTV: h_span 임계값 0.35 (압축된 스켈레톤 대응)

### 5. 웹 대시보드
- 실시간 스트리밍 + 낙상 상태 표시 (애니메이션 도트)
- 긴급 연락처 전화 버튼
- WebSocket 실시간 알림
- 6개 언어 지원

### 6. 리포트
- 기간 필터 + 통계 (건수, 위험 시간대, 중증)
- 7일 바 차트 (순수 CSS)
- CSV/PDF 내보내기
- 이메일 전송 (mailto:)

### 7. 사용자 프로필
- 등록 시: 이름, 나이, 키, 몸무게, 성별 입력
- 향후 맞춤형 임계값 조정에 활용

### 8. 성능 (Jetson Orin Nano Super)
- YOLO TRT: 89.2fps (11ms)
- ST-GCN+Physics CPU: 22.5fps (44ms)
- 전체 파이프라인: ~68.7fps (실서버: 카메라 25–30fps 한계)

---

<a name="uzbek"></a>
# 🇺🇿 O'zbekcha

## Tizim haqida

MobiCare — yolg'iz yashovchi keksa odamlar uchun real-time kamera asosidagi yiqilishni aniqlash tizimi. ST-GCN deep learning modeli va fizika qoidalari filtri birlashtirilgan, NVIDIA Jetson edge qurilmasida ishlatiladi.

## Asosiy xususiyatlar

### 1. Yiqilishni aniqlash pipeline
- YOLO11n-pose: 17 COCO keypoint (conf=0.1)
- Zero-frame interpolation: yiqilish paytida YOLO miss qilganlarni to'ldiradi
- ST-GCN 9 blok (3.1M parametr) → yiqilish ehtimoli
- Physics Rescue filter: faqat qo'shadi, o'chirmaydi

### 2. Edge server
- MJPEG live stream (854×480)
- Skeleton va bounding box overlay (yiqilishda qizil)
- RTSP avtomatik qayta ulanish
- TensorRT tezlashtirish (YOLO: 89.2fps, 11ms)
- Avtomatik reset (odam turganda)
- Screenshot avtomatik yuklash

### 3. Xavfsiz zona
- Karavot/divan sohasini qo'lda belgilash
- Shu sohada yiqilish ogohlantirilmaydi

### 4. Kamera turi
- Old tomondagi kamera: h_span=0.80
- Shiftdan CCTV: h_span=0.35

### 5. Web Dashboard
- Real-time stream + yiqilish holati (animatsiyali dot)
- Favqulodda qo'ng'iroq tugmasi
- WebSocket real-time xabarnoma
- 6 tilda qo'llab-quvvatlash

### 6. Hisobot sahifasi
- Davr filtri + statistika
- 7 kunlik bar chart (CSS)
- CSV/PDF eksport
- Email yuborish

### 7. Foydalanuvchi profili
- Ro'yxatdan o'tishda: ism, yosh, bo'y (sm), vazn (kg), jinsi
- Kelajakda threshold kalibrovkasida ishlatiladi

### 8. Ishlash ko'rsatkichlari (Jetson Orin Nano Super)
- YOLO TRT: 89.2fps (11ms)
- ST-GCN+Physics CPU: 22.5fps (44ms)
- To'liq pipeline: ~68.7fps (real serverda kamera 25–30fps cheklaydi)
