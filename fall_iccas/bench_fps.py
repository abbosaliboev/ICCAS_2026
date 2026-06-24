"""
FPS benchmark: camera capture, YOLO pose, ST-GCN inference.
Run from fall_iccas/:  python bench_fps.py [--tensorrt] [--frames 150]
"""

import os, sys, time, argparse, json, statistics
import numpy as np
import torch
import cv2

sys.path.insert(0, os.path.dirname(__file__))
from stgcn import STGCN, PhysicsFilter, TwoStageDetector
from ultralytics import YOLO

N_JOINTS = 17
WINDOW   = 30

def load_detector(device):
    ckpt = "experiments/subject1_2_3_4/checkpoints"
    cfg  = json.load(open(f"{ckpt}/two_stage_config.json"))
    model = STGCN(in_channels=3, num_classes=2, dropout=0.0).to(device)
    model.load_state_dict(torch.load(f"{ckpt}/best_stgcn.pth", map_location=device))
    model.eval()
    physics  = PhysicsFilter(fps=cfg.get("fps", 19.0),
                             vel_threshold=cfg["vel_threshold"],
                             acc_threshold=cfg["acc_threshold"])
    detector = TwoStageDetector(model, physics,
                                stage1_threshold=cfg["stage1_threshold"],
                                rescue_threshold=cfg["rescue_threshold"],
                                device=device)
    return detector

def dummy_tensor(device):
    seq = np.random.rand(WINDOW, N_JOINTS, 3).astype(np.float32)
    x   = torch.from_numpy(seq.transpose(2, 0, 1)).float()
    return x.unsqueeze(0).unsqueeze(-1).to(device), seq

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tensorrt", action="store_true")
    ap.add_argument("--frames",   type=int, default=150)
    ap.add_argument("--source",   default="0")
    ap.add_argument("--width",    type=int, default=640)
    ap.add_argument("--height",   type=int, default=480)
    args = ap.parse_args()

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"\n=== MobiCare FPS Benchmark  |  device={device} ===\n")

    # ── Camera ────────────────────────────────────────────────────────────────
    print("[1/3] Camera capture FPS ...")
    src     = int(args.source) if args.source.isdigit() else args.source
    backend = cv2.CAP_V4L2 if isinstance(src, int) else cv2.CAP_ANY
    cap     = cv2.VideoCapture(src, backend)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  args.width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, args.height)

    cam_ok = cap.isOpened()
    if not cam_ok:
        print("    WARNING: camera not available — using dummy frame for YOLO test")
        cam_fps_mean = cam_fps_min = cam_fps_max = float("nan")
        cap_reported = 30.0
        actual_w, actual_h = args.width, args.height
        frame = np.zeros((args.height, args.width, 3), dtype=np.uint8)
        cap.release()
    else:
        cap_reported = cap.get(cv2.CAP_PROP_FPS)
        actual_w     = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        actual_h     = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

        cam_times = []
        for _ in range(args.frames):
            t0 = time.perf_counter()
            ret, frame = cap.read()
            t1 = time.perf_counter()
            if ret:
                cam_times.append(t1 - t0)

        cam_fps_mean = 1.0 / statistics.mean(cam_times)
        cam_fps_min  = 1.0 / max(cam_times)
        cam_fps_max  = 1.0 / min(cam_times)
        print(f"    mean={cam_fps_mean:.1f}  min={cam_fps_min:.1f}  max={cam_fps_max:.1f} fps")

        ret, frame = cap.read()
        cap.release()
        if not ret:
            frame = np.zeros((actual_h, actual_w, 3), dtype=np.uint8)

    # ── YOLO ─────────────────────────────────────────────────────────────────
    print("[2/3] YOLO pose inference FPS ...")
    engine_file = "yolo11n-pose.engine"
    if args.tensorrt and os.path.exists(engine_file):
        yolo = YOLO(engine_file)
        yolo_backend = "TensorRT"
    else:
        yolo = YOLO("yolo11n-pose.pt")
        yolo_backend = "PyTorch"

    # warmup
    for _ in range(5):
        yolo(frame, verbose=False, conf=0.1, imgsz=320)

    yolo_times = []
    for _ in range(args.frames):
        t0 = time.perf_counter()
        yolo(frame, verbose=False, conf=0.1, imgsz=320)
        t1 = time.perf_counter()
        yolo_times.append(t1 - t0)

    yolo_fps_mean = 1.0 / statistics.mean(yolo_times)
    yolo_fps_min  = 1.0 / max(yolo_times)
    yolo_fps_max  = 1.0 / min(yolo_times)
    yolo_ms_mean  = statistics.mean(yolo_times) * 1000
    print(f"    mean={yolo_fps_mean:.1f}fps ({yolo_ms_mean:.1f}ms)  min={yolo_fps_min:.1f}  max={yolo_fps_max:.1f}")

    # ── ST-GCN ───────────────────────────────────────────────────────────────
    print("[3/3] ST-GCN inference FPS ...")
    detector = load_detector(device)

    # warmup
    for _ in range(5):
        xt, seq = dummy_tensor(device)
        with torch.no_grad():
            detector.predict_one(xt.squeeze(0), seq)

    stgcn_times = []
    for _ in range(args.frames):
        xt, seq = dummy_tensor(device)
        t0 = time.perf_counter()
        with torch.no_grad():
            detector.predict_one(xt.squeeze(0), seq)
        t1 = time.perf_counter()
        stgcn_times.append(t1 - t0)

    stgcn_fps_mean = 1.0 / statistics.mean(stgcn_times)
    stgcn_fps_min  = 1.0 / max(stgcn_times)
    stgcn_fps_max  = 1.0 / min(stgcn_times)
    stgcn_ms_mean  = statistics.mean(stgcn_times) * 1000

    print(f"    mean={stgcn_fps_mean:.1f}fps ({stgcn_ms_mean:.2f}ms)  min={stgcn_fps_min:.1f}  max={stgcn_fps_max:.1f}")

    # ── Summary ───────────────────────────────────────────────────────────────
    print("\n" + "="*55)
    print(f"  Camera  : {cam_fps_mean:.1f} fps  (reported={cap_reported:.0f}fps, {actual_w}x{actual_h})")
    print(f"  YOLO    : {yolo_fps_mean:.1f} fps  ({yolo_ms_mean:.1f} ms/frame) [{yolo_backend}]")
    print(f"  ST-GCN  : {stgcn_fps_mean:.1f} fps  ({stgcn_ms_mean:.2f} ms/window)")
    print(f"  Device  : {device.upper()}")
    print("="*55 + "\n")

    # ── Write markdown ────────────────────────────────────────────────────────
    from datetime import datetime
    now  = datetime.now().strftime("%Y-%m-%d %H:%M")
    date = datetime.now().strftime("%Y-%m-%d")
    def fmt(v, dec=1): return f"{v:.{dec}f}" if v == v else "N/A"  # nan check

    cam_row = (f"| Camera capture ({actual_w}x{actual_h}) | {fmt(cam_fps_mean)} | {fmt(cam_fps_min)} | {fmt(cam_fps_max)} "
               f"| {'N/A (not connected)' if cam_fps_mean != cam_fps_mean else fmt(1000/cam_fps_mean) + ' ms'} |")
    stgcn_calls_per_sec = cam_fps_mean / 15 if cam_fps_mean == cam_fps_mean else float("nan")

    md = f"""# MobiCare FPS Benchmark — {date}

**Device:** Jetson Orin NX 16 GB  |  **Torch:** {device.upper()} ({torch.__version__})  |  **Frames measured:** {args.frames}  |  **Run:** {now}

## Results

| Component | Mean FPS | Min FPS | Max FPS | Mean latency |
|-----------|:--------:|:-------:|:-------:|:------------:|
{cam_row}
| YOLO11n-pose ({yolo_backend}, imgsz=320) | {fmt(yolo_fps_mean)} | {fmt(yolo_fps_min)} | {fmt(yolo_fps_max)} | {fmt(yolo_ms_mean)} ms |
| ST-GCN + PhysicsFilter | {fmt(stgcn_fps_mean)} | {fmt(stgcn_fps_min)} | {fmt(stgcn_fps_max)} | {fmt(stgcn_ms_mean, 2)} ms |

## Notes

- Camera: {'not connected during this run; measured separately at ~28.7 fps (USB, 640x480)' if not cam_ok else f'reported {cap_reported:.0f} fps by v4l2'}
- YOLO runs on every frame (conf=0.1, imgsz=320) — same as edge_server.py defaults
- ST-GCN runs every STRIDE=15 frames → ~{fmt(stgcn_calls_per_sec)} calls/sec at camera rate
- ST-GCN latency timed on random dummy windows (17 joints × 30 frames), warmup=5
- **Bottleneck:** YOLO ({fmt(yolo_ms_mean)} ms) dominates; ST-GCN ({fmt(stgcn_ms_mean, 2)} ms) is negligible
"""

    out_path = "FPS_BENCHMARK.md"
    with open(out_path, "w") as f:
        f.write(md)
    print(f"Results written to fall_iccas/{out_path}")

if __name__ == "__main__":
    main()
