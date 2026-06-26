"""
MobiCare — Comprehensive FPS Benchmark
Jetson Orin NX (MAX power mode recommended: sudo nvpmodel -m 0 && sudo jetson_clocks)

Usage (from fall_iccas/):
  python bench_fps.py                            # webcam only, PyTorch
  python bench_fps.py --tensorrt                 # add TensorRT YOLO
  python bench_fps.py --rtsp "rtsp://..."        # also test RTSP camera
  python bench_fps.py --tensorrt --rtsp "rtsp://..." --frames 200

Sections:
  [1] Camera — webcam
  [2] Camera — RTSP (if --rtsp given)
  [3] YOLO — PyTorch (GPU/CPU)
  [4] YOLO — TensorRT (if --tensorrt)
  [5] ST-GCN alone — CPU
  [6] ST-GCN alone — CUDA (if available, skip if TRT active)
  [7] Physics filter alone
  [8] ST-GCN + Physics (TwoStageDetector) — CPU
  [9] ST-GCN + Physics (TwoStageDetector) — CUDA
  [10] Full pipeline end-to-end (YOLO → ST-GCN → Physics)
"""

import os, sys, time, argparse, json, statistics, subprocess
from datetime import datetime
import numpy as np
import torch
import cv2

sys.path.insert(0, os.path.dirname(__file__))
from stgcn import STGCN, PhysicsFilter, TwoStageDetector
from ultralytics import YOLO

N_JOINTS = 17
WINDOW   = 30
STRIDE   = 15
WARMUP   = 10

# ── helpers ───────────────────────────────────────────────────────────────────

def fmt(v, dec=1):
    if v != v: return "N/A"      # nan
    return f"{v:.{dec}f}"

def bench(fn, n):
    """Run fn() n times, return (mean_fps, min_fps, max_fps, mean_ms)."""
    times = []
    for _ in range(n):
        t0 = time.perf_counter()
        fn()
        times.append(time.perf_counter() - t0)
    mean_t = statistics.mean(times)
    return 1/mean_t, 1/max(times), 1/min(times), mean_t*1000

def dummy_window(device="cpu"):
    seq = np.random.rand(WINDOW, N_JOINTS, 3).astype(np.float32)
    x   = torch.from_numpy(seq.transpose(2, 0, 1)).float()
    xt  = x.unsqueeze(0).unsqueeze(-1).to(device)
    return xt.squeeze(0), seq

def load_stgcn(device):
    ckpt = "experiments/subject1_2_3_4/checkpoints"
    cfg  = json.load(open(f"{ckpt}/two_stage_config.json"))
    model = STGCN(in_channels=3, num_classes=2, dropout=0.0).to(device)
    model.load_state_dict(torch.load(f"{ckpt}/best_stgcn.pth", map_location=device))
    model.eval()
    return model, cfg

def load_detector(device, cfg):
    model, _ = load_stgcn(device)
    physics   = PhysicsFilter(fps=cfg.get("fps", 19.0),
                              vel_threshold=cfg["vel_threshold"],
                              acc_threshold=cfg["acc_threshold"])
    return TwoStageDetector(model, physics,
                            stage1_threshold=cfg["stage1_threshold"],
                            rescue_threshold=cfg["rescue_threshold"],
                            device=device)

def open_cap(src, width, height):
    if isinstance(src, int):
        cap = cv2.VideoCapture(src, cv2.CAP_V4L2)
    else:
        cap = cv2.VideoCapture(src, cv2.CAP_FFMPEG)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
    return cap

def bench_camera(src, width, height, n):
    cap = open_cap(src, width, height)
    if not cap.isOpened():
        cap.release()
        return None
    reported = cap.get(cv2.CAP_PROP_FPS)
    act_w    = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    act_h    = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    # warmup
    for _ in range(WARMUP):
        cap.read()
    times, frame = [], None
    for _ in range(n):
        t0 = time.perf_counter()
        ret, f = cap.read()
        dt = time.perf_counter() - t0
        if ret:
            times.append(dt)
            frame = f
    cap.release()
    if not times:
        return None
    mean_t = statistics.mean(times)
    return {
        "mean": 1/mean_t, "min": 1/max(times), "max": 1/min(times),
        "ms": mean_t*1000, "reported": reported,
        "w": act_w, "h": act_h, "frame": frame,
    }

def get_jetson_info():
    try:
        model = open("/proc/device-tree/model").read().strip()
    except Exception:
        model = "Unknown"
    try:
        nvp = subprocess.check_output(["nvpmodel", "-q"], stderr=subprocess.DEVNULL,
                                      timeout=3).decode()
        mode_line = [l for l in nvp.splitlines() if "Power Model" in l or "NV Power" in l]
        power_mode = mode_line[0].strip() if mode_line else nvp.strip().splitlines()[0]
    except Exception:
        power_mode = "unknown (run: nvpmodel -q)"
    return model, power_mode

# ── main ─────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tensorrt", action="store_true")
    ap.add_argument("--frames",   type=int, default=150)
    ap.add_argument("--source",   default="0", help="Webcam index or path")
    ap.add_argument("--rtsp",     default="",  help="RTSP URL for RTSP camera test")
    ap.add_argument("--width",    type=int, default=640)
    ap.add_argument("--height",   type=int, default=480)
    args = ap.parse_args()

    device = "cuda" if torch.cuda.is_available() else "cpu"
    jetson_model, power_mode = get_jetson_info()
    now_str  = datetime.now().strftime("%Y-%m-%d %H:%M")
    date_str = datetime.now().strftime("%Y-%m-%d")

    src_cam = int(args.source) if args.source.isdigit() else args.source

    results = {}   # section_name → dict
    dummy_frame = np.random.randint(0, 255, (args.height, args.width, 3), dtype=np.uint8)

    print(f"\n{'='*60}")
    print(f"  MobiCare FPS Benchmark — {now_str}")
    print(f"  Device : {jetson_model}")
    print(f"  Power  : {power_mode}")
    print(f"  Torch  : {torch.__version__}  |  CUDA: {torch.cuda.is_available()}")
    print(f"  Frames : {args.frames}  |  Warmup: {WARMUP}")
    print(f"{'='*60}\n")

    # ── [1] Webcam ─────────────────────────────────────────────────────────────
    print("[1/10] Camera — Webcam ...")
    r = bench_camera(src_cam, args.width, args.height, args.frames)
    if r:
        results["webcam"] = r
        print(f"       {r['w']}x{r['h']}  mean={r['mean']:.1f}  min={r['min']:.1f}  max={r['max']:.1f} fps")
        dummy_frame = r["frame"] if r["frame"] is not None else dummy_frame
    else:
        print("       NOT AVAILABLE — using dummy frame")

    # ── [2] RTSP ───────────────────────────────────────────────────────────────
    if args.rtsp:
        print("[2/10] Camera — RTSP ...")
        r = bench_camera(args.rtsp, args.width, args.height, args.frames)
        if r:
            results["rtsp"] = r
            print(f"       {r['w']}x{r['h']}  reported={r['reported']:.0f}fps  "
                  f"measured mean={r['mean']:.1f}  min={r['min']:.1f}  max={r['max']:.1f} fps")
            dummy_frame = r["frame"] if r["frame"] is not None else dummy_frame
        else:
            print("       RTSP not reachable")
    else:
        print("[2/10] Camera — RTSP ... SKIPPED (pass --rtsp URL)")

    # ── [3] YOLO PyTorch ──────────────────────────────────────────────────────
    print("[3/10] YOLO — PyTorch ...")
    yolo_pt = YOLO("yolo11n-pose.pt")
    for _ in range(WARMUP): yolo_pt(dummy_frame, verbose=False, conf=0.1, imgsz=320)
    fps, mn, mx, ms = bench(lambda: yolo_pt(dummy_frame, verbose=False, conf=0.1, imgsz=320),
                            args.frames)
    results["yolo_pt"] = {"mean": fps, "min": mn, "max": mx, "ms": ms, "backend": "PyTorch"}
    print(f"       mean={fps:.1f}fps ({ms:.1f}ms)  min={mn:.1f}  max={mx:.1f}")
    del yolo_pt

    # ── [4] YOLO TensorRT ─────────────────────────────────────────────────────
    engine_file = "yolo11n-pose.engine"
    if args.tensorrt and os.path.exists(engine_file):
        print("[4/10] YOLO — TensorRT ...")
        yolo_trt = YOLO(engine_file)
        for _ in range(WARMUP): yolo_trt(dummy_frame, verbose=False, conf=0.1, imgsz=320)
        fps, mn, mx, ms = bench(lambda: yolo_trt(dummy_frame, verbose=False, conf=0.1, imgsz=320),
                                args.frames)
        results["yolo_trt"] = {"mean": fps, "min": mn, "max": mx, "ms": ms, "backend": "TensorRT"}
        print(f"       mean={fps:.1f}fps ({ms:.1f}ms)  min={mn:.1f}  max={mx:.1f}")
        del yolo_trt
        # release GPU memory before ST-GCN CUDA test
        if torch.cuda.is_available(): torch.cuda.empty_cache()
    elif args.tensorrt:
        print("[4/10] YOLO — TensorRT ... engine not found, run with --tensorrt first to export")
    else:
        print("[4/10] YOLO — TensorRT ... SKIPPED (pass --tensorrt)")

    # ── [5] ST-GCN alone CPU ──────────────────────────────────────────────────
    print("[5/10] ST-GCN alone — CPU ...")
    ckpt = "experiments/subject1_2_3_4/checkpoints"
    cfg  = json.load(open(f"{ckpt}/two_stage_config.json"))
    model_cpu, _ = load_stgcn("cpu")
    xt_cpu, _    = dummy_window("cpu")
    for _ in range(WARMUP):
        with torch.no_grad(): model_cpu(xt_cpu.unsqueeze(0))
    fps, mn, mx, ms = bench(
        lambda: model_cpu(xt_cpu.unsqueeze(0)),
        args.frames)
    results["stgcn_cpu"] = {"mean": fps, "min": mn, "max": mx, "ms": ms}
    print(f"       mean={fps:.1f}fps ({ms:.2f}ms)  min={mn:.1f}  max={mx:.1f}")

    # ── [6] ST-GCN alone CUDA ─────────────────────────────────────────────────
    if device == "cuda" and not args.tensorrt:
        print("[6/10] ST-GCN alone — CUDA ...")
        model_gpu, _ = load_stgcn("cuda")
        xt_gpu, _    = dummy_window("cuda")
        for _ in range(WARMUP):
            with torch.no_grad(): model_gpu(xt_gpu.unsqueeze(0))
        fps, mn, mx, ms = bench(
            lambda: model_gpu(xt_gpu.unsqueeze(0)),
            args.frames)
        results["stgcn_cuda"] = {"mean": fps, "min": mn, "max": mx, "ms": ms}
        print(f"       mean={fps:.1f}fps ({ms:.2f}ms)  min={mn:.1f}  max={mx:.1f}")
        del model_gpu
    elif args.tensorrt:
        print("[6/10] ST-GCN alone — CUDA ... SKIPPED (TRT active — allocator conflict on Jetson)")
    else:
        print("[6/10] ST-GCN alone — CUDA ... SKIPPED (no CUDA)")

    # ── [7] Physics filter alone ───────────────────────────────────────────────
    print("[7/10] Physics filter alone ...")
    physics = PhysicsFilter(fps=cfg.get("fps", 19.0),
                            vel_threshold=cfg["vel_threshold"],
                            acc_threshold=cfg["acc_threshold"])
    def bench_physics():
        seq = np.random.rand(WINDOW, N_JOINTS, 3).astype(np.float32)
        physics.predict(seq)
    for _ in range(WARMUP): bench_physics()
    fps, mn, mx, ms = bench(bench_physics, args.frames)
    results["physics"] = {"mean": fps, "min": mn, "max": mx, "ms": ms}
    print(f"       mean={fps:.1f}fps ({ms:.3f}ms)  min={mn:.1f}  max={mx:.1f}")

    # ── [8] ST-GCN + Physics (TwoStage) CPU ───────────────────────────────────
    print("[8/10] ST-GCN + Physics (TwoStageDetector) — CPU ...")
    det_cpu = load_detector("cpu", cfg)
    xt_c, seq_c = dummy_window("cpu")
    for _ in range(WARMUP):
        with torch.no_grad(): det_cpu.predict_one(xt_c, seq_c)
    fps, mn, mx, ms = bench(lambda: det_cpu.predict_one(xt_c, seq_c), args.frames)
    results["twostage_cpu"] = {"mean": fps, "min": mn, "max": mx, "ms": ms}
    print(f"       mean={fps:.1f}fps ({ms:.2f}ms)  min={mn:.1f}  max={mx:.1f}")

    # ── [9] ST-GCN + Physics (TwoStage) CUDA ─────────────────────────────────
    if device == "cuda" and not args.tensorrt:
        print("[9/10] ST-GCN + Physics (TwoStageDetector) — CUDA ...")
        det_gpu = load_detector("cuda", cfg)
        xt_g, seq_g = dummy_window("cuda")
        for _ in range(WARMUP):
            with torch.no_grad(): det_gpu.predict_one(xt_g, seq_g)
        fps, mn, mx, ms = bench(lambda: det_gpu.predict_one(xt_g, seq_g), args.frames)
        results["twostage_cuda"] = {"mean": fps, "min": mn, "max": mx, "ms": ms}
        print(f"       mean={fps:.1f}fps ({ms:.2f}ms)  min={mn:.1f}  max={mx:.1f}")
        del det_gpu
    elif args.tensorrt:
        print("[9/10] ST-GCN + Physics CUDA ... SKIPPED (TRT active)")
    else:
        print("[9/10] ST-GCN + Physics CUDA ... SKIPPED (no CUDA)")

    # ── [10a] Full pipeline — PyTorch YOLO + ST-GCN+Physics ──────────────────
    print("[10/10] Full pipeline A — YOLO PyTorch + ST-GCN+Physics ...")
    _stgcn_dev_pt = device
    det_pt = load_detector(_stgcn_dev_pt, cfg)
    yolo_pt_full = YOLO("yolo11n-pose.pt")
    buf_pt = np.zeros((WINDOW, N_JOINTS, 3), dtype=np.float32)
    sc_pt  = [0]

    def pipeline_pt():
        res = yolo_pt_full(dummy_frame, verbose=False, conf=0.1, imgsz=320)
        kps = res[0].keypoints
        if kps is not None and len(kps.data) > 0:
            kp = kps.data[0].cpu().numpy()
            buf_pt[:-1] = buf_pt[1:]
            buf_pt[-1]  = kp[:, :3] if kp.shape[1] >= 3 else np.zeros((N_JOINTS, 3))
        sc_pt[0] += 1
        if sc_pt[0] % STRIDE == 0:
            seq = buf_pt.copy()
            x   = torch.from_numpy(seq.transpose(2, 0, 1)).float()
            xt  = x.unsqueeze(0).unsqueeze(-1).to(_stgcn_dev_pt)
            det_pt.predict_one(xt.squeeze(0), seq)

    for _ in range(WARMUP): pipeline_pt()
    fps, mn, mx, ms = bench(pipeline_pt, args.frames)
    results["pipeline_pt"] = {
        "mean": fps, "min": mn, "max": mx, "ms": ms,
        "yolo": "PyTorch", "stgcn": _stgcn_dev_pt.upper(),
    }
    print(f"       mean={fps:.1f}fps ({ms:.1f}ms)  min={mn:.1f}  max={mx:.1f}")
    print(f"       YOLO=PyTorch({_stgcn_dev_pt.upper()})  ST-GCN+Physics={_stgcn_dev_pt.upper()}")
    del yolo_pt_full, det_pt
    if torch.cuda.is_available(): torch.cuda.empty_cache()

    # ── [10b] Full pipeline — TensorRT YOLO + ST-GCN+Physics CPU ─────────────
    if os.path.exists(engine_file):
        print("[10/10] Full pipeline B — YOLO TensorRT + ST-GCN+Physics CPU ...")
        yolo_trt_full = YOLO(engine_file)
        det_trt = load_detector("cpu", cfg)   # CPU: TRT+CUDA conflict on Jetson
        buf_trt = np.zeros((WINDOW, N_JOINTS, 3), dtype=np.float32)
        sc_trt  = [0]

        def pipeline_trt():
            res = yolo_trt_full(dummy_frame, verbose=False, conf=0.1, imgsz=320)
            kps = res[0].keypoints
            if kps is not None and len(kps.data) > 0:
                kp = kps.data[0].cpu().numpy()
                buf_trt[:-1] = buf_trt[1:]
                buf_trt[-1]  = kp[:, :3] if kp.shape[1] >= 3 else np.zeros((N_JOINTS, 3))
            sc_trt[0] += 1
            if sc_trt[0] % STRIDE == 0:
                seq = buf_trt.copy()
                x   = torch.from_numpy(seq.transpose(2, 0, 1)).float()
                xt  = x.unsqueeze(0).unsqueeze(-1).to("cpu")
                det_trt.predict_one(xt.squeeze(0), seq)

        for _ in range(WARMUP): pipeline_trt()
        fps, mn, mx, ms = bench(pipeline_trt, args.frames)
        results["pipeline_trt"] = {
            "mean": fps, "min": mn, "max": mx, "ms": ms,
            "yolo": "TensorRT", "stgcn": "CPU",
        }
        print(f"       mean={fps:.1f}fps ({ms:.1f}ms)  min={mn:.1f}  max={mx:.1f}")
        print(f"       YOLO=TensorRT(GPU)  ST-GCN+Physics=CPU")
    else:
        print("[10/10] Full pipeline B — TensorRT ... engine not found, skipped")

    # ── Summary ───────────────────────────────────────────────────────────────
    print(f"\n{'='*60}")
    print("  SUMMARY")
    print(f"{'='*60}")
    r = results
    if "webcam" in r:
        print(f"  [CAM] Webcam          : {r['webcam']['mean']:.1f} fps  ({r['webcam']['w']}x{r['webcam']['h']})")
    if "rtsp" in r:
        print(f"  [CAM] RTSP            : {r['rtsp']['mean']:.1f} fps (measured)  "
              f"reported={r['rtsp']['reported']:.0f}fps  ({r['rtsp']['w']}x{r['rtsp']['h']})")
    if "yolo_pt" in r:
        print(f"  [MDL] YOLO PyTorch    : {r['yolo_pt']['mean']:.1f} fps  ({r['yolo_pt']['ms']:.1f} ms)")
    if "yolo_trt" in r:
        print(f"  [MDL] YOLO TensorRT   : {r['yolo_trt']['mean']:.1f} fps  ({r['yolo_trt']['ms']:.1f} ms)")
    if "stgcn_cpu" in r:
        print(f"  [MDL] ST-GCN CPU      : {r['stgcn_cpu']['mean']:.1f} fps  ({r['stgcn_cpu']['ms']:.2f} ms)")
    if "stgcn_cuda" in r:
        print(f"  [MDL] ST-GCN CUDA     : {r['stgcn_cuda']['mean']:.1f} fps  ({r['stgcn_cuda']['ms']:.2f} ms)")
    if "physics" in r:
        print(f"  [MDL] Physics filter  : {r['physics']['mean']:.1f} fps  ({r['physics']['ms']:.3f} ms)")
    if "twostage_cpu" in r:
        print(f"  [MDL] ST-GCN+Phys CPU : {r['twostage_cpu']['mean']:.1f} fps  ({r['twostage_cpu']['ms']:.2f} ms)")
    if "twostage_cuda" in r:
        print(f"  [MDL] ST-GCN+Phys CUDA: {r['twostage_cuda']['mean']:.1f} fps  ({r['twostage_cuda']['ms']:.2f} ms)")
    if "pipeline_pt" in r:
        print(f"  [ALL] Pipeline PT     : {r['pipeline_pt']['mean']:.1f} fps  ({r['pipeline_pt']['ms']:.1f} ms)  "
              f"YOLO=PyTorch  STGCN={r['pipeline_pt']['stgcn']}")
    if "pipeline_trt" in r:
        print(f"  [ALL] Pipeline TRT    : {r['pipeline_trt']['mean']:.1f} fps  ({r['pipeline_trt']['ms']:.1f} ms)  "
              f"YOLO=TensorRT  STGCN=CPU")
    print(f"{'='*60}\n")

    # ── Write markdown ────────────────────────────────────────────────────────
    def row(label, backend, key):
        if key not in results:
            return ""
        d = results[key]
        return (f"| {label} | {backend} | **{fmt(d['mean'])}** |"
                f" {fmt(d['min'])} | {fmt(d['max'])} | {fmt(d['ms'], 2)} ms |\n")

    # pre-compute all dynamic strings before the f-string (no backslashes inside {})
    cuda_avail   = str(torch.cuda.is_available())
    torch_ver    = torch.__version__

    if "webcam" in r:
        webcam_res  = f"{r['webcam']['w']}x{r['webcam']['h']}"
        webcam_rep  = f"{r['webcam']['reported']:.0f}"
        webcam_fps  = fmt(r["webcam"]["mean"])
        webcam_ms   = fmt(r["webcam"]["ms"], 1) + " ms"
        webcam_row  = f"| Webcam (USB) | {webcam_res} | {webcam_rep} | **{webcam_fps}** | {webcam_ms} |\n"
    else:
        webcam_row  = "| Webcam (USB) | N/A | N/A | N/A | N/A |\n"

    if "rtsp" in r:
        rtsp_res    = f"{r['rtsp']['w']}x{r['rtsp']['h']}"
        rtsp_rep    = f"{r['rtsp']['reported']:.0f}"
        rtsp_fps    = fmt(r["rtsp"]["mean"])
        rtsp_ms     = fmt(r["rtsp"]["ms"], 1) + " ms"
        rtsp_row    = f"| RTSP | {rtsp_res} | {rtsp_rep} | **{rtsp_fps}** | {rtsp_ms} |\n"
    elif args.rtsp:
        rtsp_row    = "| RTSP | not reachable | — | — | — |\n"
    else:
        rtsp_row    = ""

    model_rows = (
        row("YOLO11n-pose (imgsz=320, conf=0.1)", "PyTorch", "yolo_pt")
        + row("YOLO11n-pose (imgsz=320, conf=0.1)", "TensorRT", "yolo_trt")
        + row("ST-GCN only", "CPU", "stgcn_cpu")
        + row("ST-GCN only", "CUDA", "stgcn_cuda")
        + row("Physics filter only", "CPU (numpy)", "physics")
        + row("ST-GCN + Physics (TwoStage)", "CPU", "twostage_cpu")
        + row("ST-GCN + Physics (TwoStage)", "CUDA", "twostage_cuda")
    )

    def pipeline_row(key):
        if key not in r:
            return ""
        d = r[key]
        return (f"| {d['yolo']} | {d['stgcn']} | **{fmt(d['mean'])}** |"
                f" {fmt(d['min'])} | {fmt(d['max'])} | {fmt(d['ms'], 1)} ms |\n")

    pipeline_rows = pipeline_row("pipeline_pt") + pipeline_row("pipeline_trt")
    if not pipeline_rows:
        pipeline_rows = "| N/A | N/A | N/A | N/A | N/A | N/A |\n"

    stgcn_calls = fmt(r["webcam"]["mean"] / STRIDE) if "webcam" in r else "?"
    phys_ms     = fmt(r["physics"]["ms"], 3) if "physics" in r else "?"
    trt_note    = ("TRT+CUDA allocator conflict on Jetson: when TensorRT is used, "
                   "ST-GCN+Physics always runs on CPU.")

    md = (
        f"# MobiCare FPS Benchmark — {date_str}\n\n"
        f"**Device:** {jetson_model}  \n"
        f"**Power mode:** {power_mode}  \n"
        f"**CUDA:** {cuda_avail} | **Torch:** {torch_ver}  \n"
        f"**Frames:** {args.frames} | **Warmup:** {WARMUP} | **Run:** {now_str}\n\n"
        "---\n\n"
        "## Camera\n\n"
        "| Source | Resolution | Reported FPS | Measured FPS | Latency |\n"
        "|--------|-----------|:------------:|:------------:|:-------:|\n"
        + webcam_row + rtsp_row +
        "\n---\n\n"
        "## Model Components (isolated)\n\n"
        "| Component | Backend | Mean FPS | Min FPS | Max FPS | Latency |\n"
        "|-----------|---------|:--------:|:-------:|:-------:|:-------:|\n"
        + model_rows +
        "\n---\n\n"
        "## Full Pipeline — YOLO + ST-GCN + Physics (end-to-end)\n\n"
        "| YOLO backend | ST-GCN+Physics | Mean FPS | Min FPS | Max FPS | Latency |\n"
        "|---|---|:---:|:---:|:---:|:---:|\n"
        + pipeline_rows +
        "\n---\n\n"
        "## Notes\n\n"
        f"- ST-GCN is called every STRIDE={STRIDE} frames → ~{stgcn_calls} calls/sec at webcam rate\n"
        f"- Physics filter overhead is negligible ({phys_ms} ms per window)\n"
        f"- {trt_note}\n"
        f"- All timings use `time.perf_counter()`, warmup={WARMUP} frames excluded\n"
    )

    out_path = "FPS_BENCHMARK.md"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(md)
    print(f"Results written to fall_iccas/{out_path}\n")

if __name__ == "__main__":
    main()
