# FPS Benchmark — Edge Server / FPS 벤치마크

> **Language / 언어**
> - [🇺🇸 English](#english)
> - [🇰🇷 한국어](#korean)

---

<a name="english"></a>
# 🇺🇸 English

**Device:** NVIDIA Jetson Orin Nano Super (Engineering Reference Developer Kit)
**Power:** 15W + `jetson_clocks` (all CPU/GPU clocks pinned to max frequency)
**CUDA:** 12.6 | **PyTorch:** 2.5.0a0+872d972e41.nv24.08 | **TensorRT:** 10.3.0
**Date:** 2026-06-26 | **Frames:** 200 | **Warmup:** 10

---

## Camera

| Source | Resolution | Reported FPS | Measured FPS | Latency |
|--------|-----------|:------------:|:------------:|:-------:|
| Webcam (USB) | 640×480 | 30 | **30.0** | 33.3 ms |
| RTSP IP camera | 2560×1440 | 25 | **27.1** | 36.8 ms |

> RTSP measured FPS can spike above 25 due to OpenCV buffer drain. Real camera rate = 25 fps.

---

## Model Components (isolated benchmarks)

| Component | Backend | Mean FPS | Min FPS | Max FPS | Latency |
|-----------|---------|:--------:|:-------:|:-------:|:-------:|
| YOLO11n-pose (imgsz=320, conf=0.1) | PyTorch (GPU) | **28.8** | 27.0 | 29.9 | 34.7 ms |
| YOLO11n-pose (imgsz=320, conf=0.1) | **TensorRT (GPU)** | **89.2** | 79.9 | 98.1 | **11.2 ms** |
| ST-GCN only | CPU | 21.2 | 9.8 | 24.0 | 47.1 ms |
| ST-GCN only | **CUDA** | **59.5** | 54.9 | 60.6 | **16.8 ms** |
| Physics filter only | CPU (numpy) | **494** | 449 | 507 | 2.0 ms |
| ST-GCN + Physics (TwoStage) | CPU | 23.5 | 14.1 | 26.0 | 42.5 ms |
| ST-GCN + Physics (TwoStage) | **CUDA** | **60.0** | 59.2 | 60.7 | **16.7 ms** |

> ST-GCN CUDA is 2.8× faster than CPU (16.8 ms vs 47.1 ms).
> Physics filter adds only 0.1 ms on top of ST-GCN — essentially free.
> ST-GCN CUDA cannot be used with TensorRT YOLO in the same process (Jetson allocator conflict).

---

## Full Pipeline — YOLO + ST-GCN + Physics (end-to-end)

| YOLO backend | ST-GCN+Physics | Mean FPS | Min FPS | Max FPS | Latency |
|---|---|:---:|:---:|:---:|:---:|
| PyTorch (GPU) | **CUDA** | 27.7 | 18.5 | 29.6 | 36.1 ms |
| **TensorRT (GPU)** | CPU | **68.7** | 16.7 | 99.3 | **14.6 ms** |

> TensorRT pipeline is **2.5× faster** than PyTorch pipeline (68.7 vs 27.7 fps).
> Min FPS dip occurs when ST-GCN runs on the same frame as YOLO (every 15th frame).

---

## Summary Comparison

| Scenario | FPS | Latency | Notes |
|---|:---:|:---:|---|
| Camera (Webcam) | **30** | 33 ms | Hardware limit |
| Camera (RTSP 2560×1440) | **25–27** | 37 ms | Hardware limit |
| YOLO PyTorch alone | 28.8 | 34.7 ms | |
| YOLO TensorRT alone | **89.2** | **11.2 ms** | **3.1× faster than PT** |
| ST-GCN + Physics (CPU) | 23.5 | 42.5 ms | |
| ST-GCN + Physics (CUDA) | **60.0** | **16.7 ms** | **2.6× faster than CPU** |
| Physics filter alone | 494 | 2.0 ms | Essentially free |
| **Pipeline: PyTorch + CUDA** | 27.7 | 36.1 ms | Limited by YOLO PT |
| **Pipeline: TRT + CPU** | **68.7** | **14.6 ms** | **Recommended (no conflict)** |

**Conclusion:**
- YOLO TensorRT: 3.1× faster than PyTorch
- ST-GCN CUDA: 2.8× faster than CPU
- TRT pipeline is 2.5× faster than PyTorch pipeline overall
- In real deployment: **camera (~25–30 fps) is the bottleneck**, not the model

---

## Real-world vs Isolated FPS — Why the numbers differ

The benchmark measures **pure model inference speed** on a static dummy frame.
In the actual edge server, the effective throughput is lower and camera-limited:

```
Isolated benchmark (this file):
  YOLO TRT alone   → 89 fps   (no camera, no buffer copy, no MJPEG encode)
  Full pipeline     → 69 fps   (YOLO every frame + ST-GCN every 15th)

Real edge server (camera feeding frames):
  Camera delivers  → 25–30 fps  ← this is the true bottleneck
  YOLO runs on     → 25–30 fps  (waits for each camera frame)
  ST-GCN runs on   → ~1.7–2 calls/sec  (every 15th frame at 25–30 fps)
  Effective loop   → ~25–30 fps (camera-limited)
```

| Component | Isolated FPS | Real server FPS | Reason for difference |
|-----------|:-----------:|:---------------:|---|
| Camera | 27–30 | 25–30 | Same — hardware limit |
| YOLO TRT | **89** | ~25–30 | Camera feeds frames slower than YOLO can process |
| ST-GCN + Physics | 60 (CUDA) | ~1.7 calls/sec | Called once per 15 frames |
| Full loop | **69** | ~25–30 | Camera is the bottleneck |

**Why high isolated FPS still matters:**
- **Headroom:** YOLO finishes in 11 ms, well before the next frame arrives (33 ms)
- **Thermal:** Shorter GPU burst = lower sustained heat on Jetson
- **Recovery:** After RTSP reconnect or dropped frames, catches up instantly
- **Scaling:** Higher resolution or larger models can be adopted without redesign

---

## How to Reproduce

```bash
# Pin clocks to max
sudo nvpmodel -m 0 && sudo jetson_clocks

cd fall_iccas

# Get ST-GCN CUDA numbers (no TRT conflict)
python bench_fps.py --frames 200

# Get TensorRT YOLO numbers + both pipeline comparisons
python bench_fps.py --frames 200 --tensorrt \
  --rtsp "rtsp://admin:PASSWORD@CAMERA_IP:554/stream1"
```

---

<a name="korean"></a>
# 🇰🇷 한국어

**장치:** NVIDIA Jetson Orin Nano Super (Engineering Reference Developer Kit)
**전력:** 15W + `jetson_clocks` (CPU/GPU 클럭 최대 고정)
**CUDA:** 12.6 | **PyTorch:** 2.5.0a0+872d972e41.nv24.08 | **TensorRT:** 10.3.0
**날짜:** 2026-06-26 | **프레임:** 200 | **워밍업:** 10

---

## 카메라

| 소스 | 해상도 | 보고 FPS | 측정 FPS | 지연 |
|------|--------|:--------:|:--------:|:----:|
| 웹캠 (USB) | 640×480 | 30 | **30.0** | 33.3 ms |
| RTSP IP 카메라 | 2560×1440 | 25 | **27.1** | 36.8 ms |

---

## 모델 구성 요소 (단독 벤치마크)

| 구성 요소 | 백엔드 | 평균 FPS | 최소 | 최대 | 지연 |
|-----------|--------|:--------:|:----:|:----:|:----:|
| YOLO11n-pose (imgsz=320, conf=0.1) | PyTorch (GPU) | **28.8** | 27.0 | 29.9 | 34.7 ms |
| YOLO11n-pose (imgsz=320, conf=0.1) | **TensorRT (GPU)** | **89.2** | 79.9 | 98.1 | **11.2 ms** |
| ST-GCN 단독 | CPU | 21.2 | 9.8 | 24.0 | 47.1 ms |
| ST-GCN 단독 | **CUDA** | **59.5** | 54.9 | 60.6 | **16.8 ms** |
| Physics filter 단독 | CPU (numpy) | **494** | 449 | 507 | 2.0 ms |
| ST-GCN + Physics (TwoStage) | CPU | 23.5 | 14.1 | 26.0 | 42.5 ms |
| ST-GCN + Physics (TwoStage) | **CUDA** | **60.0** | 59.2 | 60.7 | **16.7 ms** |

> ST-GCN CUDA가 CPU보다 2.8배 빠름 (16.8 ms vs 47.1 ms).
> Physics filter는 ST-GCN 대비 0.1 ms만 추가 — 무시할 수준.
> ST-GCN CUDA는 TensorRT YOLO와 같은 프로세스에서 사용 불가 (Jetson 할당자 충돌).

---

## 전체 파이프라인 (YOLO → ST-GCN → Physics)

| YOLO 백엔드 | ST-GCN+Physics | 평균 FPS | 최소 | 최대 | 지연 |
|---|---|:---:|:---:|:---:|:---:|
| PyTorch (GPU) | **CUDA** | 27.7 | 18.5 | 29.6 | 36.1 ms |
| **TensorRT (GPU)** | CPU | **68.7** | 16.7 | 99.3 | **14.6 ms** |

> TensorRT 파이프라인이 **2.5배 빠름** (68.7 vs 27.7 fps).

---

## 요약 비교

| 시나리오 | FPS | 지연 | 비고 |
|---|:---:|:---:|---|
| 카메라 (웹캠) | **30** | 33 ms | 하드웨어 한계 |
| 카메라 (RTSP) | **25–27** | 37 ms | 하드웨어 한계 |
| YOLO PyTorch 단독 | 28.8 | 34.7 ms | |
| YOLO TensorRT 단독 | **89.2** | **11.2 ms** | PT 대비 3.1× |
| ST-GCN + Physics (CPU) | 23.5 | 42.5 ms | |
| ST-GCN + Physics (CUDA) | **60.0** | **16.7 ms** | CPU 대비 2.6× |
| Physics filter 단독 | 494 | 2.0 ms | 사실상 무료 |
| **파이프라인: PyTorch + CUDA** | 27.7 | 36.1 ms | YOLO PT가 병목 |
| **파이프라인: TRT + CPU** | **68.7** | **14.6 ms** | **권장 구성** |

---

## 실측 FPS vs 단독 벤치마크

벤치마크는 정지된 더미 프레임으로 **순수 모델 추론 속도**만 측정합니다.
실제 서버에서는 카메라가 병목이 됩니다:

```
단독 벤치마크:  YOLO TRT → 89 fps, 파이프라인 → 69 fps
실제 서버:       카메라 → 25–30 fps (실제 병목)
                 YOLO   → 카메라 속도에 맞춰 25–30 fps
                 ST-GCN → 15프레임마다 1회 (~1.7–2 회/초)
```

**그럼에도 높은 FPS가 중요한 이유:**
- YOLO 11 ms → 다음 프레임 전에 완전히 완료 (여유 22 ms)
- 발열 감소, RTSP 재연결 후 즉시 복구, 향후 확장성 확보
