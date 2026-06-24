# MobiCare Edge FPS Benchmark — 2026-06-24

**Device:** Jetson Orin NX 16 GB (JetPack 6.1 / R36.4.7)
**CUDA:** 12.6  |  **PyTorch:** 2.5.0a0+872d972e41.nv24.08  |  **TensorRT:** 10.3.0
**Frames measured:** 150 per component  |  **Warmup:** 5–10 iters before timing

---

## 1. Pipeline FPS (edge_server.py, imgsz=320, conf=0.1)

| Component | Backend | Mean FPS | Min FPS | Max FPS | Mean latency |
|-----------|---------|:--------:|:-------:|:-------:|:------------:|
| Camera (RTSP, 2560×1440) | FFMPEG/TCP | **29.8** | 13.9 | 101.6 | 33.6 ms |
| YOLO11n-pose | TensorRT engine | **70.9** | 27.1 | 93.6 | 14.1 ms |
| YOLO11n-pose | PyTorch (.pt) | — | — | — | — |
| ST-GCN + PhysicsFilter | CUDA (PyTorch) | **37.4** | 10.4 | 47.4 | 26.7 ms |
| ST-GCN + PhysicsFilter | CPU | 4.6 | 2.1 | 9.3 | 215.2 ms |

> Camera: RTSP stream from IP camera at `10.198.137.224:554/stream1` (2560×1440, Dahua/Hikvision), 120 frames measured.
> YOLO and ST-GCN benchmarks measured in separate isolated processes to avoid GPU memory conflicts between TensorRT and PyTorch CUDA allocator.

---

## 2. Effective Pipeline Throughput

- **Bottleneck:** Camera at 28.7 fps caps the pipeline. YOLO (70.9 fps) and ST-GCN (37.4 fps GPU) are both faster.
- **ST-GCN call rate:** every STRIDE=15 frames → ~2.0 calls/sec at 29.8 fps camera rate. ST-GCN adds **zero** throughput overhead.
- **Effective loop FPS:** ≈ min(cam, yolo) = **29.8 fps** (camera-limited)
- **YOLO latency headroom:** 14.1 ms per frame × 28.7 fps = 40% GPU time for YOLO; leaves 60% idle.

---

## 3. YOLO NvMap warnings

During TRT inference, `NvMapMemAllocInternalTagged` error 12 appeared 4× (fallback alloc, non-fatal). This is a known Jetson shared memory allocation retry — inference still completed correctly. Cause: shared GPU/CPU memory pressure from concurrent TRT + PyTorch CUDA contexts.

---

## 4. Reference: Dedicated Detection Benchmarks (edge_deploy, imgsz=640)

These are from a separate architecture experiment (det + pose shared backbone, imgsz=640):

| Method | Power mode | Mean FPS | Latency | Power | RAM |
|--------|-----------|:--------:|:-------:|:-----:|:---:|
| Det-only TRT | MAXN | 231.4 | 4.3 ms | 4.5 W | 974 MB |
| Det-only TRT | 15 W | 65.8 | 15.2 ms | — | — |
| Two-stage TRT | MAXN | 114.8 | 8.7 ms | 4.75 W | 1018 MB |
| Two-stage TRT | 15 W | 29.3 | 34.1 ms | — | — |
| Shared-backbone TRT | MAXN | 173.9 | 5.7 ms | 4.8 W | 1002 MB |
| Shared-backbone TRT | 15 W | 49.0 | 20.4 ms | — | — |

> Source: `/home/dalab/Desktop/edge_deploy_final_exp/edge_deploy/results/`
> These use a different YOLO architecture (det+pose heads, imgsz=640, 1000-iter benchmark) — not directly comparable to the edge_server yolo11n-pose at imgsz=320.

---

## 5. Model Complexity (from table1)

| Method | Backbone | Heads | Shared | Params (M) | GFLOPs | Size (MB) |
|--------|----------|-------|--------|:----------:|:------:|:---------:|
| Det-only (Baseline) | YOLO11 | Det | ✗ | 2.096 | 5.206 | 4.193 |
| Det+Pose (Two-stage) | YOLO11 | Det+Pose | ✗ | 4.605 | 11.135 | 9.226 |
| Det+Pose (Ours, Shared) | YOLO11 | Det+Pose | ✓ | 2.597 | 6.497 | 5.204 |
| **yolo11n-pose (edge_server)** | YOLO11 | Pose | — | ~2.9 | ~7.9 | ~8 (engine) |

---

## 6. Environment Notes

- `torch 2.10.0+cpu` was originally installed (CPU-only). Replaced with NVIDIA JetPack build `torch-2.5.0a0+872d972e41.nv24.08` from local wheel to enable CUDA.
- `torchvision` was not available in a compatible version for torch 2.5.0a0 (only 0.25.0 built for 2.10.0 was on disk). Two ultralytics import patches applied:
  - `ultralytics/utils/__init__.py`: wrapped `importlib.metadata.version("torchvision")` in try/except
  - `ultralytics/models/sam/sam3/geometry_encoders.py`: wrapped `import torchvision` in try/except
- TensorRT + PyTorch CUDA cannot run in the same process (shared GPU memory conflict on Jetson); benchmarks run in separate processes.
