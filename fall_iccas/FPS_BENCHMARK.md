# FPS Benchmark — Edge Server / FPS 벤치마크 / FPS O'lchovi

> **Language / 언어 / Til**
> - [🇺🇸 English](#english)
> - [🇰🇷 한국어](#korean)
> - [🇺🇿 O'zbekcha](#uzbek)

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
| YOLO11n-pose (imgsz=320, conf=0.1) | PyTorch (GPU) | **28.6** | 27.0 | 29.4 | 35.0 ms |
| YOLO11n-pose (imgsz=320, conf=0.1) | **TensorRT (GPU)** | **89.2** | 79.9 | 98.1 | **11.2 ms** |
| ST-GCN only | CPU | **20.6** | 12.7 | 22.8 | 48.6 ms |
| ST-GCN only | CUDA | — | — | — | — *(TRT conflict)* |
| Physics filter only | CPU (numpy) | **452** | 154 | 501 | 2.2 ms |
| ST-GCN + Physics (TwoStage) | CPU | **22.8** | 11.3 | 25.3 | 43.9 ms |
| ST-GCN + Physics (TwoStage) | CUDA | — | — | — | — *(TRT conflict)* |

> ST-GCN CUDA skipped when TensorRT is active — shared CUDA allocator conflict on Jetson.
> Physics filter adds only 0.3 ms overhead on top of ST-GCN alone (negligible).

---

## Full Pipeline — YOLO + ST-GCN + Physics (end-to-end)

| YOLO backend | ST-GCN+Physics | Mean FPS | Min FPS | Max FPS | Latency |
|---|---|:---:|:---:|:---:|:---:|
| PyTorch (GPU) | CUDA | 26.3 | 2.9 | 29.2 | 38.0 ms |
| **TensorRT (GPU)** | **CPU** | **65.9** | 16.6 | 95.0 | **15.2 ms** |

> **TensorRT pipeline is 2.5× faster** than PyTorch pipeline (65.9 vs 26.3 fps).
> Min FPS dip occurs when ST-GCN runs on the same frame as YOLO (every 15th frame).
> In real deployment, pipeline is camera-limited at ~25–30 fps — both configurations are sufficient.

---

## Summary Comparison

| Scenario | FPS | Latency | Notes |
|---|:---:|:---:|---|
| Camera (Webcam) | **30** | 33 ms | Hardware limit |
| Camera (RTSP 2560×1440) | **25–27** | 37 ms | Hardware limit |
| YOLO PyTorch alone | 28.6 | 35 ms | |
| YOLO TensorRT alone | **89.2** | **11 ms** | **3.1× faster than PT** |
| ST-GCN + Physics (CPU) | 22.8 | 44 ms | Called every 15 frames |
| Physics filter alone | 452 | 2 ms | Essentially free |
| **Pipeline: PyTorch + CUDA** | 26.3 | 38 ms | Limited by YOLO PT |
| **Pipeline: TRT + CPU** | **65.9** | **15 ms** | **Recommended** |

**Conclusion:** YOLO TensorRT gives 3.1× speedup in isolation and 2.5× in the full pipeline.
In real deployment the system is camera-limited (~25 fps), so both pipelines handle real-time easily.
Use TensorRT for maximum headroom and lower thermal load.

---

## Real-world vs Isolated FPS — Why the numbers differ

The benchmark measures **pure model inference speed** on a static dummy frame.
In the actual edge server, the effective throughput is lower and camera-limited:

```
Isolated benchmark (this file):
  YOLO TRT alone   → 89 fps   (no camera, no buffer copy, no MJPEG encode)
  Full pipeline     → 66 fps   (YOLO every frame + ST-GCN every 15th)

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
| ST-GCN + Physics | 22 | ~1.7 calls/sec | Called once per 15 frames, not every frame |
| Full loop | **66** | ~25–30 | Camera is the bottleneck |

**Why benchmark high FPS still matters:**
- **Headroom:** If YOLO took 40 ms (25 fps), it would block the camera read loop. At 11 ms, it finishes well before the next frame arrives.
- **Thermal:** Faster inference = shorter GPU burst = lower sustained heat on Jetson.
- **Burst recovery:** After RTSP reconnect or dropped frames, the system catches up instantly.
- **Future scaling:** Higher resolution or larger models can be adopted without redesign.

---

## How to Reproduce

```bash
# Pin clocks to max (no reboot needed)
sudo nvpmodel -m 0 && sudo jetson_clocks

cd fall_iccas

# Full benchmark: webcam + RTSP + TRT vs PT comparison
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
| YOLO11n-pose (imgsz=320, conf=0.1) | PyTorch (GPU) | **28.6** | 27.0 | 29.4 | 35.0 ms |
| YOLO11n-pose (imgsz=320, conf=0.1) | **TensorRT (GPU)** | **89.2** | 79.9 | 98.1 | **11.2 ms** |
| ST-GCN 단독 | CPU | **20.6** | 12.7 | 22.8 | 48.6 ms |
| Physics filter 단독 | CPU (numpy) | **452** | 154 | 501 | 2.2 ms |
| ST-GCN + Physics (TwoStage) | CPU | **22.8** | 11.3 | 25.3 | 43.9 ms |

> Physics filter는 ST-GCN 대비 0.3 ms 오버헤드만 추가 — 무시할 수준.

---

## 전체 파이프라인 (YOLO → ST-GCN → Physics)

| YOLO 백엔드 | ST-GCN+Physics | 평균 FPS | 최소 | 최대 | 지연 |
|---|---|:---:|:---:|:---:|:---:|
| PyTorch (GPU) | CUDA | 26.3 | 2.9 | 29.2 | 38.0 ms |
| **TensorRT (GPU)** | **CPU** | **65.9** | 16.6 | 95.0 | **15.2 ms** |

> **TensorRT 파이프라인이 2.5배 빠름** (65.9 vs 26.3 fps).
> 실제 서비스에서는 카메라 (~25 fps)가 병목 — 두 구성 모두 실시간에 충분.

---

## 요약 비교

| 시나리오 | FPS | 비고 |
|---|:---:|---|
| 카메라 (웹캠) | **30** | 하드웨어 한계 |
| 카메라 (RTSP) | **25–27** | 하드웨어 한계 |
| YOLO PyTorch 단독 | 28.6 | |
| YOLO TensorRT 단독 | **89.2** | PyTorch 대비 3.1× 빠름 |
| ST-GCN + Physics (CPU) | 22.8 | 15프레임마다 1회 호출 |
| Physics filter 단독 | 452 | 사실상 무료 |
| **파이프라인: PyTorch + CUDA** | 26.3 | YOLO PT가 병목 |
| **파이프라인: TRT + CPU** | **65.9** | **권장 구성** |

**결론:** TensorRT는 단독 3.1배, 파이프라인 2.5배 속도 향상.
실제 배포에서는 카메라 (~25 fps)가 병목이므로 두 구성 모두 실시간 처리 가능.
TensorRT 사용 시 더 많은 여유와 낮은 발열.

---

## 실측 FPS vs 단독 벤치마크 — 왜 숫자가 다른가

벤치마크는 **정지된 더미 프레임으로 순수 모델 추론 속도**만 측정합니다.
실제 엣지 서버에서는 카메라가 병목이 되어 FPS가 낮아집니다:

```
단독 벤치마크 (이 파일):
  YOLO TRT 단독   → 89 fps   (카메라 없음, 버퍼 복사 없음, MJPEG 인코딩 없음)
  전체 파이프라인  → 66 fps

실제 엣지 서버 (카메라로 프레임 공급):
  카메라 공급 속도  → 25–30 fps  ← 실제 병목
  YOLO 처리 속도   → 25–30 fps  (카메라 프레임 대기)
  ST-GCN 호출     → ~1.7–2 회/초  (15프레임마다 1회)
  실효 루프 FPS    → ~25–30 fps  (카메라 제한)
```

| 구성 요소 | 단독 FPS | 실서버 FPS | 차이 원인 |
|-----------|:-------:|:---------:|---|
| 카메라 | 27–30 | 25–30 | 동일 — 하드웨어 한계 |
| YOLO TRT | **89** | ~25–30 | 카메라가 모델보다 느리게 프레임 공급 |
| ST-GCN + Physics | 22 | ~1.7 회/초 | 15프레임마다 1회 호출 |
| 전체 루프 | **66** | ~25–30 | 카메라가 병목 |

**그럼에도 높은 FPS가 중요한 이유:**
- **여유:** YOLO가 11 ms에 끝나면 다음 프레임 전에 충분히 완료됨 (40 ms라면 루프가 막힘)
- **발열:** 빠른 추론 = GPU 부하 시간 단축 = Jetson 온도 감소
- **버스트 복구:** RTSP 재연결이나 프레임 드롭 후 즉시 따라잡기 가능
- **확장성:** 고해상도나 더 큰 모델 도입 시 여유 확보

---

<a name="uzbek"></a>
# 🇺🇿 O'zbekcha

**Qurilma:** NVIDIA Jetson Orin Nano Super (Engineering Reference Developer Kit)
**Quvvat:** 15W + `jetson_clocks` (CPU/GPU clock larini maksimalga qo'yish)
**CUDA:** 12.6 | **PyTorch:** 2.5.0a0+872d972e41.nv24.08 | **TensorRT:** 10.3.0
**Sana:** 2026-06-26 | **Kadrlar:** 200 | **Isitish:** 10

---

## Kamera

| Manba | Ruxsat | Ko'rsatilgan FPS | O'lchangan FPS | Kechikish |
|-------|--------|:----------------:|:--------------:|:---------:|
| Webcam (USB) | 640×480 | 30 | **30.0** | 33.3 ms |
| RTSP IP kamera | 2560×1440 | 25 | **27.1** | 36.8 ms |

---

## Model komponentlari (alohida benchmark)

| Komponent | Backend | O'rtacha FPS | Min | Max | Kechikish |
|-----------|---------|:------------:|:---:|:---:|:---------:|
| YOLO11n-pose (imgsz=320, conf=0.1) | PyTorch (GPU) | **28.6** | 27.0 | 29.4 | 35.0 ms |
| YOLO11n-pose (imgsz=320, conf=0.1) | **TensorRT (GPU)** | **89.2** | 79.9 | 98.1 | **11.2 ms** |
| ST-GCN yolg'iz | CPU | **20.6** | 12.7 | 22.8 | 48.6 ms |
| Physics filter yolg'iz | CPU (numpy) | **452** | 154 | 501 | 2.2 ms |
| ST-GCN + Physics (TwoStage) | CPU | **22.8** | 11.3 | 25.3 | 43.9 ms |

> Physics filter ST-GCN ga nisbatan atigi 0.3 ms qo'shimcha kechikish beradi.

---

## To'liq pipeline (YOLO → ST-GCN → Physics)

| YOLO backend | ST-GCN+Physics | O'rtacha FPS | Min | Max | Kechikish |
|---|---|:---:|:---:|:---:|:---:|
| PyTorch (GPU) | CUDA | 26.3 | 2.9 | 29.2 | 38.0 ms |
| **TensorRT (GPU)** | **CPU** | **65.9** | 16.6 | 95.0 | **15.2 ms** |

> **TensorRT pipeline 2.5 barobar tezroq** (65.9 vs 26.3 fps).
> Haqiqiy ishlatishda kamera (~25 fps) bottleneck — ikkalasi ham real-time uchun yetarli.

---

## Xulosalar jadvali

| Holat | FPS | Izoh |
|---|:---:|---|
| Kamera (Webcam) | **30** | Hardware chegarasi |
| Kamera (RTSP) | **25–27** | Hardware chegarasi |
| YOLO PyTorch yolg'iz | 28.6 | |
| YOLO TensorRT yolg'iz | **89.2** | PyTorch dan 3.1× tez |
| ST-GCN + Physics (CPU) | 22.8 | Har 15-kadrda 1 marta |
| Physics filter yolg'iz | 452 | Deyarli bepul |
| **Pipeline: PyTorch + CUDA** | 26.3 | YOLO PT bottleneck |
| **Pipeline: TRT + CPU** | **65.9** | **Tavsiya etilgan** |

**Xulosa:** TensorRT yolg'iz 3.1×, to'liq pipelineda 2.5× tezlashtiradi.
Haqiqiy joylashtirishda kamera (~25 fps) cheklaydi — ikkalasi ham real-time da ishlaydi.
TensorRT ishlatilsa ko'proq zapas va past qizish.

---

## Haqiqiy vs Alohida FPS — Raqamlar nima uchun farq qiladi

Benchmark **statik dummy frame da sof model tezligini** o'lchaydi.
Haqiqiy edge serverda kamera bottleneck bo'lib, FPS pastroq bo'ladi:

```
Alohida benchmark (shu fayl):
  YOLO TRT yolg'iz  → 89 fps   (kamera yo'q, buffer nusxalash yo'q)
  To'liq pipeline   → 66 fps

Haqiqiy edge server (kamera kadr beradi):
  Kamera tezligi    → 25–30 fps  ← haqiqiy bottleneck
  YOLO ishlash tezi → 25–30 fps  (kamera kadrini kutadi)
  ST-GCN chaqiruvi  → ~1.7–2 marta/son  (har 15-kadrda bir marta)
  Samarali loop FPS → ~25–30 fps  (kamera cheklaydi)
```

| Komponent | Alohida FPS | Real server FPS | Farq sababi |
|-----------|:-----------:|:---------------:|---|
| Kamera | 27–30 | 25–30 | Bir xil — hardware chegarasi |
| YOLO TRT | **89** | ~25–30 | Kamera modeldan sekin kadr beradi |
| ST-GCN + Physics | 22 | ~1.7 marta/son | Har 15-kadrda bir marta chaqiriladi |
| To'liq loop | **66** | ~25–30 | Kamera bottleneck |

**Shunday bo'lsa ham yuqori FPS nima uchun muhim:**
- **Zapas:** YOLO 11 ms da tugasa keyingi kadr kelguncha erkin (40 ms bo'lsa loop to'xtaydi)
- **Qizish:** Tezroq inference = GPU qisqa vaqt ishlaydi = Jetson harorati past
- **Tiklash:** RTSP uzilgandan keyin tizim darhol kadrlarni quvib oladi
- **Kengayish:** Katta modellar yoki yuqori ruxsatga o'tishda zapas mavjud
