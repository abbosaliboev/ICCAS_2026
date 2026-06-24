# FPS Benchmark — Edge Server / FPS 벤치마크 / FPS O'lchovi

> **Language / 언어 / Til**
> - [🇺🇸 English](#english)
> - [🇰🇷 한국어](#korean)
> - [🇺🇿 O'zbekcha](#uzbek)

---

<a name="english"></a>
# 🇺🇸 English

**Device:** Jetson Orin NX 16 GB (JetPack 6.1 / R36.4.7)
**CUDA:** 12.6 | **PyTorch:** 2.5.0a0+872d972e41.nv24.08 | **TensorRT:** 10.3.0
**Camera:** RTSP IP camera — `10.198.137.227:554/stream1`, 2560×1440 @ 25 fps
**Date:** 2026-06-24

## Live Edge Server Results (2026-06-24)

Measured from actual edge server log during real-time detection:

| Component | Backend | Mean FPS | Latency |
|-----------|---------|:--------:|:-------:|
| RTSP camera (2560×1440) | FFMPEG/TCP | **25** (real) | 40 ms |
| YOLO11n-pose (imgsz=320, conf=0.1) | TensorRT (GPU) | **40** | **25 ms** |
| ST-GCN + PhysicsFilter | PyTorch (CPU) | **12** | **80 ms** |
| Full pipeline loop | — | **~18** | 56 ms |

> Note: `rtsp=86fps` shown in log is OpenCV buffer drain speed, not actual camera rate.
> Real camera delivers 25 fps. Loop FPS ~18 is the true throughput.

## Isolated Component Benchmarks (150 frames, warmup=5)

| Component | Backend | Mean FPS | Min FPS | Max FPS | Latency |
|-----------|---------|:--------:|:-------:|:-------:|:-------:|
| Camera capture (RTSP, 2560×1440) | FFMPEG | **29.8** | 13.9 | 101.6 | 33.6 ms |
| YOLO11n-pose (imgsz=320) | TensorRT (GPU) | **70.9** | 27.1 | 93.6 | 14.1 ms |
| ST-GCN + PhysicsFilter | PyTorch (CUDA) | **37.4** | 10.4 | 47.4 | 26.7 ms |
| ST-GCN + PhysicsFilter | PyTorch (CPU) | **4.6** | 2.1 | 9.3 | 215 ms |

> Isolated benchmark: YOLO and ST-GCN run in separate processes (TRT + PyTorch CUDA
> conflict on Jetson shared memory). In the live server, ST-GCN uses CPU to avoid this.

## Analysis

- **Bottleneck:** YOLO (25 ms) + ST-GCN every 15th frame (80 ms amortized ≈ 5 ms/frame)
- **Effective throughput:** ~18 fps loop — camera-limited at 25 fps source rate
- **ST-GCN call rate:** every STRIDE=15 frames → ~1.2 calls/sec at 18 fps loop
- **MJPEG stream:** downscaled to 854×480 before encoding (from 2560×1440)

## Fall Detection Verification (2026-06-24)

Tested with real person in camera view:

| Test | Result |
|------|--------|
| Fall detected → backend event posted | ✓ |
| Screenshot captured & uploaded | ✓ |
| Auto-reset when person stands up | ✓ |
| Stream delivered to browser (MJPEG) | ✓ |

## Environment Notes

- TensorRT + PyTorch CUDA cannot share GPU in same process on Jetson → ST-GCN runs on CPU
- Ultralytics patched to handle missing torchvision (torch 2.5.0a0 + no compatible torchvision available offline)
- RTSP camera IP changed: `.224` → `.227` (DHCP reassignment)

---

<a name="korean"></a>
# 🇰🇷 한국어

**장치:** Jetson Orin NX 16 GB (JetPack 6.1 / R36.4.7)
**CUDA:** 12.6 | **PyTorch:** 2.5.0a0+872d972e41.nv24.08 | **TensorRT:** 10.3.0
**카메라:** RTSP IP 카메라 — `10.198.137.227:554/stream1`, 2560×1440 @ 25 fps
**날짜:** 2026-06-24

## 실시간 엣지 서버 결과 (2026-06-24)

실제 엣지 서버 로그에서 측정:

| 구성 요소 | 백엔드 | 평균 FPS | 지연 |
|-----------|--------|:--------:|:----:|
| RTSP 카메라 (2560×1440) | FFMPEG/TCP | **25** (실제) | 40 ms |
| YOLO11n-pose (imgsz=320, conf=0.1) | TensorRT (GPU) | **40** | **25 ms** |
| ST-GCN + PhysicsFilter | PyTorch (CPU) | **12** | **80 ms** |
| 전체 파이프라인 루프 | — | **~18** | 56 ms |

## 성능 분석

- **병목:** YOLO (25 ms) + ST-GCN (15번째 프레임마다, 80 ms)
- **실효 처리량:** 루프 ~18 fps — 25 fps 카메라 소스 기준
- **낙상 감지 검증:** 실제 인물로 테스트 완료 ✓

## 낙상 감지 검증 (2026-06-24)

| 테스트 항목 | 결과 |
|-------------|------|
| 낙상 감지 → 백엔드 이벤트 전송 | ✓ |
| 스크린샷 캡처 및 업로드 | ✓ |
| 기립 시 자동 초기화 | ✓ |
| 브라우저 MJPEG 스트림 전달 | ✓ |

---

<a name="uzbek"></a>
# 🇺🇿 O'zbekcha

**Qurilma:** Jetson Orin NX 16 GB (JetPack 6.1 / R36.4.7)
**CUDA:** 12.6 | **PyTorch:** 2.5.0a0+872d972e41.nv24.08 | **TensorRT:** 10.3.0
**Kamera:** RTSP IP kamera — `10.198.137.227:554/stream1`, 2560×1440 @ 25 fps
**Sana:** 2026-06-24

## Real-time Edge Server Natijalari (2026-06-24)

Haqiqiy edge server logidan o'lchangan:

| Komponent | Backend | O'rtacha FPS | Kechikish |
|-----------|---------|:------------:|:---------:|
| RTSP kamera (2560×1440) | FFMPEG/TCP | **25** (haqiqiy) | 40 ms |
| YOLO11n-pose (imgsz=320, conf=0.1) | TensorRT (GPU) | **40** | **25 ms** |
| ST-GCN + PhysicsFilter | PyTorch (CPU) | **12** | **80 ms** |
| To'liq pipeline loop | — | **~18** | 56 ms |

## Tahlil

- **Bottleneck:** YOLO (25 ms) + ST-GCN (har 15-kadrda, 80 ms)
- **Samarali tezlik:** ~18 fps loop — 25 fps kamera manbaida cheklangan
- **Yiqilishni aniqlash:** real odam bilan sinovdan o'tkazildi ✓

## Yiqilishni aniqlash tekshiruvi (2026-06-24)

| Test | Natija |
|------|--------|
| Yiqilish aniqlandi → backend ga voqea yuborildi | ✓ |
| Screenshot olinib yuklandi | ✓ |
| Odam turganda avtomatik reset | ✓ |
| Brauzerda MJPEG stream ko'rindi | ✓ |
