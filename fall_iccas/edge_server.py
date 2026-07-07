"""
MobiCare Edge Server — Jetson Orin NX

Real-time fall detection on the edge device:
  1. MJPEG video stream  → http://JETSON_IP:8081/video
  2. Fall events POST    → backend server
  3. Video clip recording (10 s before each fall)

Usage (from fall_iccas/):
  python edge_server.py
  python edge_server.py --source rtsp://192.168.1.100/stream
  python edge_server.py --backend http://192.168.1.200:8000
  python edge_server.py --device-token mytoken123 --display

TensorRT (Jetson, first run only — exports engine then reuses):
  python edge_server.py --tensorrt
"""

import os, sys, json, time, threading, argparse, logging
from collections import deque
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import cv2
import numpy as np
import torch
import requests
from ultralytics import YOLO

sys.path.insert(0, os.path.dirname(__file__))
from stgcn import STGCN, PhysicsFilter, TwoStageDetector

logging.basicConfig(level=logging.INFO, format="%(asctime)s [EDGE] %(message)s")
log = logging.getLogger("edge")

# ── COCO skeleton ─────────────────────────────────────────────────────────────
SKELETON = [
    (0,1),(0,2),(1,3),(2,4),
    (5,6),(5,7),(7,9),(6,8),(8,10),
    (5,11),(6,12),(11,12),
    (11,13),(13,15),(12,14),(14,16),
]
N_JOINTS = 17
WINDOW   = 30
STRIDE   = 15

# ── shared MJPEG frame ────────────────────────────────────────────────────────
_frame_lock   = threading.Lock()
_latest_jpg   = None    # bytes


def _make_placeholder_jpg(text: str = "Loading...") -> bytes:
    """Simple gray placeholder frame with text — shown before camera is ready."""
    img = np.full((240, 320, 3), 40, dtype=np.uint8)
    cv2.putText(img, text, (20, 130), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (180, 180, 180), 2)
    _, jpg = cv2.imencode(".jpg", img)
    return jpg.tobytes()

_PLACEHOLDER_JPG = None   # created lazily after cv2 is imported


class _MJPEGHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        global _PLACEHOLDER_JPG
        if self.path == "/":
            body = b"<html><body><img src='/video' style='max-width:100%'></body></html>"
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Content-Length", len(body))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/video":
            self.send_response(200)
            self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=--mjpeg")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            try:
                while True:
                    with _frame_lock:
                        jpg = _latest_jpg
                    if jpg is None:
                        if _PLACEHOLDER_JPG is None:
                            _PLACEHOLDER_JPG = _make_placeholder_jpg("카메라 준비 중...")
                        jpg = _PLACEHOLDER_JPG
                    self.wfile.write(b"--mjpeg\r\nContent-Type: image/jpeg\r\n\r\n")
                    self.wfile.write(jpg)
                    self.wfile.write(b"\r\n")
                    time.sleep(0.05)   # 20 fps max
            except Exception:
                pass
        elif self.path == "/snapshot":
            with _frame_lock:
                jpg = _latest_jpg
            if jpg is None:
                if _PLACEHOLDER_JPG is None:
                    _PLACEHOLDER_JPG = _make_placeholder_jpg("카메라 준비 중...")
                jpg = _PLACEHOLDER_JPG
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.send_header("Content-Length", str(len(jpg)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Cache-Control", "no-cache, no-store")
            self.end_headers()
            self.wfile.write(jpg)
        elif self.path == "/status":
            body = json.dumps({"status": "ok", "time": datetime.now().isoformat()}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *args):
        pass


def start_mjpeg_server(port: int):
    srv = ThreadingHTTPServer(("0.0.0.0", port), _MJPEGHandler)
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    log.info(f"MJPEG stream at http://0.0.0.0:{port}/video")


# ── backend HTTP client ───────────────────────────────────────────────────────
class BackendClient:
    def __init__(self, base_url: str, device_token: str):
        self.base    = base_url.rstrip("/")
        self.token   = device_token
        self.headers = {"X-Device-Token": device_token}

    def post_fall(self, event_id: str, category: str, timestamp: str) -> bool:
        payload = {
            "event_id":  event_id,
            "category":  category,
            "timestamp": timestamp,
        }
        try:
            r = requests.post(
                f"{self.base}/api/fall-events",
                json=payload,
                headers=self.headers,
                timeout=5,
            )
            if r.status_code in (200, 201):
                log.info(f"Fall event posted: {event_id}")
                return True
            log.warning(f"Backend responded {r.status_code}")
        except Exception as e:
            log.warning(f"Cannot reach backend: {e}")
        return False

    def upload_screenshot(self, event_id: str, img_path: str):
        for attempt in range(3):
            if os.path.exists(img_path):
                break
            time.sleep(0.5)
        if not os.path.exists(img_path):
            log.warning(f"Screenshot file not found: {img_path}")
            return
        try:
            with open(img_path, "rb") as f:
                r = requests.post(
                    f"{self.base}/api/fall-events/{event_id}/screenshot",
                    files={"file": (os.path.basename(img_path), f, "image/jpeg")},
                    headers=self.headers,
                    timeout=10,
                )
            if r.status_code in (200, 201):
                log.info(f"Screenshot uploaded for {event_id}")
            else:
                log.warning(f"Screenshot upload got {r.status_code}: {r.text[:100]}")
        except Exception as e:
            log.warning(f"Screenshot upload failed: {e}")

    def upload_video(self, event_id: str, video_path: str):
        if not os.path.exists(video_path):
            log.warning(f"Video file not found: {video_path}")
            return
        try:
            with open(video_path, "rb") as f:
                r = requests.post(
                    f"{self.base}/api/fall-events/{event_id}/video",
                    files={"file": (os.path.basename(video_path), f, "video/mp4")},
                    headers=self.headers,
                    timeout=30,
                )
            if r.status_code in (200, 201):
                log.info(f"Video uploaded for {event_id}")
            else:
                log.warning(f"Video upload got {r.status_code}: {r.text[:100]}")
        except Exception as e:
            log.warning(f"Video upload failed: {e}")

    def resolve_fall(self, event_id: str):
        try:
            requests.post(
                f"{self.base}/api/fall-events/{event_id}/resolve",
                headers=self.headers,
                timeout=5,
            )
            log.info(f"Fall resolved: {event_id}")
        except Exception as e:
            log.warning(f"Cannot send fall-resolve: {e}")


# ── keypoint helpers (same as demo_webcam.py) ─────────────────────────────────
def extract_kp(result, h, w):
    kp = np.zeros((N_JOINTS, 3), dtype=np.float32)
    if result.keypoints is None or len(result.keypoints.xy) == 0:
        return kp
    if result.keypoints.conf is not None:
        idx = int(result.keypoints.conf.sum(dim=1).argmax())
    else:
        idx = 0
    xy   = result.keypoints.xy[idx].cpu().numpy()
    conf = result.keypoints.conf[idx].cpu().numpy()
    kp[:, 0] = xy[:, 0] / w
    kp[:, 1] = xy[:, 1] / h
    kp[:, 2] = conf
    return kp


def draw_skeleton(frame, kp_norm, h, w):
    pts = (kp_norm[:, :2] * np.array([w, h])).astype(int)
    vis = kp_norm[:, 2] > 0.2
    for a, b in SKELETON:
        if vis[a] and vis[b]:
            cv2.line(frame, tuple(pts[a]), tuple(pts[b]), (255, 200, 0), 2)
    for i in range(N_JOINTS):
        if vis[i]:
            cv2.circle(frame, tuple(pts[i]), 4, (0, 255, 0), -1)


def to_stgcn_tensor(seq_np, device):
    x = torch.from_numpy(seq_np.transpose(2, 0, 1)).float()
    return x.unsqueeze(0).unsqueeze(-1).to(device)


def is_lying(kp, delta=0.10):
    if kp[[5,6],2].max() < 0.2 or kp[[11,12],2].max() < 0.2:
        return False
    return (kp[[11,12],1].mean() - kp[[5,6],1].mean()) < delta


def is_standing(kp, delta=0.12):
    if kp[[5,6],2].max() < 0.2 or kp[[11,12],2].max() < 0.2:
        return False
    return (kp[[11,12],1].mean() - kp[[5,6],1].mean()) > delta


def ffill(buf):
    out  = buf.copy()
    T    = len(out)
    zero = out[:, :, :2].sum(axis=(1,2)) == 0
    last = None
    for i in range(T):
        if not zero[i]:
            last = out[i].copy()
        elif last is not None:
            out[i] = last
    first = None
    for i in range(T):
        if out[i, :, :2].sum() > 0:
            first = out[i].copy(); break
    if first is not None:
        for i in range(T):
            if out[i, :, :2].sum() == 0: out[i] = first
            else: break
    return out


def load_detector(
    exp_dir: str,
    device: str,
    tensorrt: bool = False,
    stage1_threshold: float = None,
    rescue_threshold: float = None,
):
    ckpt  = os.path.join(exp_dir, "checkpoints")
    cfg   = json.load(open(os.path.join(ckpt, "two_stage_config.json")))
    pth   = os.path.join(ckpt, "best_stgcn.pth")
    fps   = cfg.get("fps", 19.0)

    model = STGCN(in_channels=3, num_classes=2, dropout=0.0).to(device)
    model.load_state_dict(torch.load(pth, map_location=device))
    model.eval()

    physics  = PhysicsFilter(fps=fps, vel_threshold=cfg["vel_threshold"], acc_threshold=cfg["acc_threshold"])
    stage1_t = cfg["stage1_threshold"] if stage1_threshold is None else stage1_threshold
    rescue_t = cfg["rescue_threshold"] if rescue_threshold is None else rescue_threshold
    detector = TwoStageDetector(model, physics,
                                stage1_threshold=stage1_t,
                                rescue_threshold=rescue_t,
                                device=device)
    log.info(f"Detector thresholds: stage1={stage1_t:.2f}, rescue={rescue_t:.2f}")
    return detector, fps


def load_yolo(tensorrt: bool):
    engine = "yolo11n-pose.engine"
    if tensorrt:
        if not os.path.exists(engine):
            log.info("Exporting YOLO to TensorRT engine (one-time, ~2 min)…")
            m = YOLO("yolo11n-pose.pt")
            m.export(format="engine", half=True, device=0, imgsz=320)
            log.info("TensorRT export done.")
        log.info(f"Loading TensorRT engine: {engine}")
        return YOLO(engine)
    return YOLO("yolo11n-pose.pt")


def prune_time_buffer(buf, now_ts: float, keep_seconds: float):
    cutoff = now_ts - keep_seconds
    while buf and buf[0][0] < cutoff:
        buf.popleft()


def save_and_upload_clip(event_id: str, frames, clip_dir: str, client: BackendClient):
    if len(frames) < 2:
        log.warning(f"Not enough frames to save clip for {event_id}")
        return

    Path(clip_dir).mkdir(parents=True, exist_ok=True)
    clip_path = os.path.join(clip_dir, f"{event_id}.mp4")
    first_ts = frames[0][0]
    last_ts = frames[-1][0]
    duration = max(last_ts - first_ts, 0.1)
    out_fps = max(5.0, min(30.0, (len(frames) - 1) / duration))
    h, w = frames[0][1].shape[:2]

    writer = cv2.VideoWriter(
        clip_path,
        cv2.VideoWriter_fourcc(*"mp4v"),
        out_fps,
        (w, h),
    )
    if not writer.isOpened():
        log.warning(f"Cannot open clip writer: {clip_path}")
        return

    try:
        for _, frame in frames:
            writer.write(frame)
    finally:
        writer.release()

    log.info(f"Saved pre-fall clip: {clip_path} ({len(frames)} frames, {out_fps:.1f} fps)")
    client.upload_video(event_id, clip_path)


# ── main loop ─────────────────────────────────────────────────────────────────

def main():
    global _latest_jpg
    ap = argparse.ArgumentParser()
    ap.add_argument("--exp",          default=None,            help="Experiment dir with checkpoints/ (default: fall_iccas — uses checkpoints/, the latest 17-subject model)")
    ap.add_argument("--source",       default="0",             help="Camera index or RTSP URL")
    ap.add_argument("--backend",      default="http://localhost:8000", help="Backend server URL")
    ap.add_argument("--device-token", default="edge-device-001", help="Device token for backend auth")
    ap.add_argument("--stream-port",  type=int, default=8081,  help="MJPEG HTTP port (default 8081)")
    ap.add_argument("--snap-dir",     default="snapshots",     help="Directory to save fall screenshots")
    ap.add_argument("--clip-dir",     default="clips",         help="Directory to save fall video clips")
    ap.add_argument("--preclip-seconds", type=float, default=5.0, help="Seconds of video to keep before a fall")
    ap.add_argument("--clip-buffer-fps", type=float, default=19.0, help="Max FPS stored in pre-fall clip buffer")
    ap.add_argument("--stage1-threshold", type=float, default=0.55, help="ST-GCN confident FALL threshold")
    ap.add_argument("--rescue-threshold", type=float, default=0.50, help="Physics rescue lower probability threshold")
    ap.add_argument("--confirm",      type=int, default=3,     help="Consecutive FALL windows to confirm (default 3)")
    ap.add_argument("--min-lock",     type=float, default=5.0, help="Min seconds to hold FALL alert")
    ap.add_argument("--stand-streak", type=int, default=2,     help="Standing windows to auto-reset")
    ap.add_argument("--display",      action="store_true",     help="Show cv2 window (requires display)")
    ap.add_argument("--tensorrt",     action="store_true",     help="Use TensorRT engine for YOLO (Jetson)")
    ap.add_argument("--width",        type=int, default=640)
    ap.add_argument("--height",       type=int, default=480)
    args = ap.parse_args()

    base    = os.path.dirname(__file__)
    # default: fall_iccas/checkpoints/ — the latest 17-subject two-stage model
    exp_dir = args.exp or base
    device  = "cuda" if torch.cuda.is_available() else "cpu"
    log.info(f"Device: {device}")

    # ST-GCN must run on CPU when TensorRT is used — TRT and PyTorch CUDA
    # allocators conflict on Jetson shared GPU memory (CUDACachingAllocator crash).
    stgcn_device = "cpu" if args.tensorrt else device
    detector, train_fps = load_detector(
        exp_dir,
        stgcn_device,
        tensorrt=False,
        stage1_threshold=args.stage1_threshold,
        rescue_threshold=args.rescue_threshold,
    )
    yolo = load_yolo(args.tensorrt)
    log.info("Models loaded")

    start_mjpeg_server(args.stream_port)

    snap_dir = args.snap_dir if os.path.isabs(args.snap_dir) else os.path.join(base, args.snap_dir)
    clip_dir = args.clip_dir if os.path.isabs(args.clip_dir) else os.path.join(base, args.clip_dir)
    Path(snap_dir).mkdir(parents=True, exist_ok=True)
    Path(clip_dir).mkdir(parents=True, exist_ok=True)
    client   = BackendClient(args.backend, args.device_token)

    # resolve camera source — V4L2 for local indices, FFMPEG for RTSP/HTTP URLs
    src = int(args.source) if args.source.isdigit() else args.source
    if isinstance(src, int):
        backend = cv2.CAP_V4L2
    elif isinstance(src, str) and src.startswith("rtsp"):
        backend = cv2.CAP_FFMPEG
    else:
        backend = cv2.CAP_ANY
    def open_cap():
        c = cv2.VideoCapture(src, backend)
        if backend == cv2.CAP_FFMPEG:
            c.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        c.set(cv2.CAP_PROP_FRAME_WIDTH,  args.width)
        c.set(cv2.CAP_PROP_FRAME_HEIGHT, args.height)
        return c

    cap = open_cap()
    if not cap.isOpened():
        log.warning(f"Cannot open source yet: {src} — will keep retrying...")

    buf              = deque(maxlen=WINDOW)
    pre_clip_buf     = deque()
    frame_no         = 0
    read_fail_count  = 0
    fps_disp      = 0.0   # overall loop FPS
    cam_fps       = 0.0   # camera frame delivery FPS
    yolo_fps      = 0.0   # YOLO inference FPS  (1 / inference_time)
    stgcn_fps     = 0.0   # ST-GCN inference FPS (1 / inference_time)
    t_prev        = time.time()
    last_clip_sample_t = 0.0
    fall_streak   = 0
    fall_active   = False
    fall_lock_t   = 0.0
    stand_streak  = 0
    baseline_hip  = 0.0
    lying_streak  = 0
    no_person_frames = 0
    current_event_id = None
    smooth_bbox      = None   # EMA-smoothed [x1,y1,x2,y2] from YOLO boxes

    # camera type config (front = normal, top = ceiling/CCTV)
    cam_cfg_path = os.path.join(base, "camera_config.json")
    def load_cam_config():
        try:
            if os.path.exists(cam_cfg_path):
                with open(cam_cfg_path) as _f:
                    return json.load(_f).get("camera_type", "front")
        except Exception:
            pass
        return "front"
    camera_type = load_cam_config()
    last_cam_reload = 0.0
    # top-down camera: person appears compressed vertically → lower h_span threshold
    # front camera: normal threshold
    log.info(f"Camera type: {camera_type}")

    # safe zone
    safe_zone_path   = os.path.join(base, "safe_zone.json")
    safe_zones       = []
    last_zone_reload = 0.0

    def load_safe_zones():
        try:
            if os.path.exists(safe_zone_path):
                with open(safe_zone_path) as _f:
                    zones = json.load(_f).get("zones", [])
                # normalize: mobile app saves {x,y,w,h}, web UI saves {x1,y1,x2,y2}
                norm = []
                for z in zones:
                    if "x1" in z:
                        norm.append(z)
                    else:
                        norm.append({
                            "x1": z["x"], "y1": z["y"],
                            "x2": z["x"] + z["w"], "y2": z["y"] + z["h"],
                        })
                return norm
        except Exception:
            pass
        return []

    safe_zones = load_safe_zones()
    log.info(f"Safe zones loaded: {len(safe_zones)}")
    log.info("Edge server running. Ctrl+C to stop.")

    while True:
        if not cap.isOpened():
            read_fail_count += 1
            if read_fail_count % 5 == 1:
                log.warning(f"Camera not connected — retrying ({read_fail_count})...")
                cap.release()
                time.sleep(3.0)
                cap = open_cap()
            else:
                time.sleep(1.0)
            continue

        t_read0 = time.time()
        ret, frame = cap.read()
        t_read1 = time.time()
        if not ret:
            read_fail_count += 1
            if read_fail_count % 10 == 1:
                log.warning(f"Frame read failed ({read_fail_count}x) — reconnecting...")
                cap.release()
                time.sleep(2.0)
                cap = open_cap()
            else:
                time.sleep(0.1)
            continue
        read_fail_count = 0

        # camera FPS: inverse of time blocked inside cap.read()
        read_dt = max(t_read1 - t_read0, 1e-6)
        cam_fps = 0.9 * cam_fps + 0.1 / read_dt

        h, w = frame.shape[:2]
        frame_no += 1
        now = time.time()
        fps_disp = 0.9 * fps_disp + 0.1 / max(now - t_prev, 1e-6)
        t_prev = now

        t_yolo0 = time.time()
        results = yolo(frame, verbose=False, conf=0.1, imgsz=320)
        t_yolo1 = time.time()
        yolo_fps = 0.9 * yolo_fps + 0.1 / max(t_yolo1 - t_yolo0, 1e-6)

        kp = extract_kp(results[0], h, w)
        buf.append(kp)

        person_visible = float(kp[:, 2].max()) > 0.15
        no_person_frames = 0 if person_visible else no_person_frames + 1

        # reload camera config every 30 s
        if time.time() - last_cam_reload > 30:
            camera_type = load_cam_config()
            last_cam_reload = time.time()

        # reload safe zones every 10 s
        if time.time() - last_zone_reload > 10:
            safe_zones = load_safe_zones()
            last_zone_reload = time.time()

        # check if mid-hip is inside a safe zone
        in_safe_zone = False
        if safe_zones and person_visible:
            hip_x = float((kp[11, 0] + kp[12, 0]) / 2)
            hip_y = float((kp[11, 1] + kp[12, 1]) / 2)
            for _z in safe_zones:
                if _z["x1"] <= hip_x <= _z["x2"] and _z["y1"] <= hip_y <= _z["y2"]:
                    in_safe_zone = True
                    break

        draw_skeleton(frame, kp, h, w)

        # draw safe zone overlay (green semi-transparent)
        if safe_zones:
            _overlay = frame.copy()
            for _z in safe_zones:
                zx1, zy1 = int(_z["x1"]*w), int(_z["y1"]*h)
                zx2, zy2 = int(_z["x2"]*w), int(_z["y2"]*h)
                cv2.rectangle(_overlay, (zx1, zy1), (zx2, zy2), (0, 200, 80), -1)
            cv2.addWeighted(_overlay, 0.12, frame, 0.88, 0, frame)
            for _z in safe_zones:
                zx1, zy1 = int(_z["x1"]*w), int(_z["y1"]*h)
                zx2, zy2 = int(_z["x2"]*w), int(_z["y2"]*h)
                cv2.rectangle(frame, (zx1, zy1), (zx2, zy2), (0, 200, 80), 2)
                cv2.putText(frame, "SAFE ZONE", (zx1+4, zy1+18),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 200, 80), 1, cv2.LINE_AA)

        # update smoothed bounding box from YOLO result (only when person detected well)
        boxes = results[0].boxes
        if boxes is not None and len(boxes) > 0:
            # pick most confident box
            best = int(boxes.conf.argmax())
            conf_val = float(boxes.conf[best])
            if conf_val > 0.25:
                bx = boxes.xyxy[best].cpu().numpy().astype(int)
                # EMA smooth: blend toward new bbox
                if smooth_bbox is None:
                    smooth_bbox = bx.copy().astype(float)
                else:
                    smooth_bbox = 0.6 * smooth_bbox + 0.4 * bx

        # draw red bounding box when fall active and we have a stable bbox
        if fall_active and smooth_bbox is not None:
            sx1, sy1, sx2, sy2 = smooth_bbox.astype(int)
            pad = 12
            sx1, sy1 = max(0, sx1 - pad), max(0, sy1 - pad)
            sx2, sy2 = min(w, sx2 + pad), min(h, sy2 + pad)
            cv2.rectangle(frame, (sx1, sy1), (sx2, sy2), (0, 0, 255), 3)
            label_y = max(sy1 - 8, 20)
            cv2.putText(frame, "FALL", (sx1, label_y),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2, cv2.LINE_AA)

        pred = 0
        if len(buf) == WINDOW and frame_no % STRIDE == 0:
            seq = ffill(np.stack(buf, axis=0))
            x_t = to_stgcn_tensor(seq, device)

            # skip inference if too few joints visible (edge/close-up = distorted skeleton)
            n_vis  = int((kp[:, 2] > 0.15).sum())
            vis_kp = kp[kp[:, 2] > 0.15]
            h_span = float(vis_kp[:, 1].max() - vis_kp[:, 1].min()) if n_vis >= 4 else 0.0
            # top-down camera: skeleton height span much smaller (person seen from above)
            h_span_thresh = 0.35 if camera_type == "top" else 0.80
            if n_vis >= 9 and h_span <= h_span_thresh:
                t_stgcn0 = time.time()
                pred = detector.predict_one(x_t.squeeze(0), seq)
                t_stgcn1 = time.time()
                stgcn_fps = 0.9 * stgcn_fps + 0.1 / max(t_stgcn1 - t_stgcn0, 1e-6)

            # personal standing baseline
            if not fall_active and is_standing(kp):
                baseline_hip = 0.88 * baseline_hip + 0.12 * float(kp[[11,12],1].mean()) if baseline_hip > 0 else float(kp[[11,12],1].mean())

            if pred == 1 and not in_safe_zone:
                fall_streak += 1
            else:
                if not fall_active:
                    fall_streak = 0

            if fall_streak >= args.confirm and not fall_active:
                event_id         = datetime.now().strftime('%Y%m%d%H%M%S')
                event_created = client.post_fall(event_id, "severe", datetime.now().isoformat())
                if not event_created:
                    log.warning(f"FALL detected locally but backend event was not created: {event_id}")
                    fall_streak = max(args.confirm - 1, 0)
                else:
                    fall_active  = True
                    fall_lock_t  = time.time() + args.min_lock
                    stand_streak = 0
                    current_event_id = event_id
                    log.info("FALL DETECTED — backend event created, alert active")
                    clip_frames = [(ts, f.copy()) for ts, f in pre_clip_buf]
                    threading.Thread(
                        target=save_and_upload_clip,
                        args=(event_id, clip_frames, clip_dir, client),
                        daemon=True,
                    ).start()
                    ss_path = os.path.join(snap_dir, f"{event_id}.jpg")
                    ss_frame = cv2.resize(frame, (1280, 720), interpolation=cv2.INTER_LINEAR)
                    # draw bbox on screenshot (fall_active just set, bbox not yet on frame)
                    if smooth_bbox is not None:
                        _sx = 1280 / w; _sy = 720 / h
                        _bx1 = max(0,    int(smooth_bbox[0]*_sx) - 12)
                        _by1 = max(0,    int(smooth_bbox[1]*_sy) - 12)
                        _bx2 = min(1280, int(smooth_bbox[2]*_sx) + 12)
                        _by2 = min(720,  int(smooth_bbox[3]*_sy) + 12)
                        cv2.rectangle(ss_frame, (_bx1, _by1), (_bx2, _by2), (0, 0, 255), 3)
                        cv2.putText(ss_frame, "FALL", (_bx1, max(_by1-8, 20)),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2, cv2.LINE_AA)
                    cv2.imwrite(ss_path, ss_frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
                    threading.Thread(target=client.upload_screenshot, args=(event_id, ss_path), daemon=True).start()

        # auto-reset
        if fall_active and time.time() > fall_lock_t:
            if no_person_frames > 50:
                fall_active  = False
                fall_streak  = 0
                stand_streak = 0
                lying_streak = 0
                log.info("Auto-reset: person left frame")
                if current_event_id:
                    threading.Thread(target=client.resolve_fall, args=(current_event_id,), daemon=True).start()
            elif is_standing(kp):
                stand_streak += 1
                if stand_streak >= args.stand_streak:
                    fall_active  = False
                    fall_streak  = 0
                    stand_streak = 0
                    lying_streak = 0
                    log.info("Auto-reset: person standing")
                    if current_event_id:
                        threading.Thread(target=client.resolve_fall, args=(current_event_id,), daemon=True).start()
            else:
                stand_streak = 0

        # ── overlay: two lines — pipeline FPS + model latency ────────────────
        cv2.putText(frame,
            f"RTSP={cam_fps:.0f}fps  loop={fps_disp:.0f}fps  [{device}]",
            (10, h-28), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (150, 150, 150), 1, cv2.LINE_AA)
        stgcn_ms = (1000.0 / stgcn_fps) if stgcn_fps > 0 else 0.0
        yolo_ms  = (1000.0 / yolo_fps)  if yolo_fps  > 0 else 0.0
        cv2.putText(frame,
            f"YOLO={yolo_fps:.0f}fps({yolo_ms:.0f}ms)  ST-GCN+Phys={stgcn_fps:.0f}fps({stgcn_ms:.0f}ms)",
            (10, h-10), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (150, 150, 150), 1, cv2.LINE_AA)
        if frame_no % 60 == 0:
            log.info(f"FPS — rtsp={cam_fps:.1f}  loop={fps_disp:.1f}  yolo={yolo_fps:.1f}({yolo_ms:.1f}ms)  stgcn={stgcn_fps:.1f}({stgcn_ms:.1f}ms)")

        # MJPEG publish — resize to 854x480 for fast streaming (source may be 2560x1440)
        stream_w, stream_h = 854, 480
        if w > stream_w:
            small = cv2.resize(frame, (stream_w, stream_h), interpolation=cv2.INTER_LINEAR)
        else:
            small = frame
        clip_now = time.time()
        clip_interval = 1.0 / args.clip_buffer_fps if args.clip_buffer_fps > 0 else 0.0
        if clip_interval == 0.0 or clip_now - last_clip_sample_t >= clip_interval:
            pre_clip_buf.append((clip_now, small.copy()))
            last_clip_sample_t = clip_now
        prune_time_buffer(pre_clip_buf, clip_now, args.preclip_seconds)
        _, jpg = cv2.imencode(".jpg", small, [cv2.IMWRITE_JPEG_QUALITY, 70])
        with _frame_lock:
            _latest_jpg = jpg.tobytes()

        if args.display:
            cv2.imshow("MobiCare Edge", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

    cap.release()
    if args.display:
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
