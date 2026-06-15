"""
MobiCare Edge Server — Jetson Orin NX

Real-time fall detection on the edge device:
  1. MJPEG video stream  → http://JETSON_IP:8081/video
  2. Fall events POST    → backend server
  3. Video clip recording (30 s around each fall)

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
                        global _PLACEHOLDER_JPG
                        if _PLACEHOLDER_JPG is None:
                            _PLACEHOLDER_JPG = _make_placeholder_jpg("카메라 준비 중...")
                        jpg = _PLACEHOLDER_JPG
                    self.wfile.write(b"--mjpeg\r\nContent-Type: image/jpeg\r\n\r\n")
                    self.wfile.write(jpg)
                    self.wfile.write(b"\r\n")
                    time.sleep(0.05)   # 20 fps max
            except Exception:
                pass
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


# ── video clip recorder ───────────────────────────────────────────────────────
class ClipRecorder:
    """Buffers raw frames and saves a clip when triggered."""

    def __init__(self, clip_dir: str, pre_s: float = 5.0, post_s: float = 10.0, fps: float = 15.0):
        self.clip_dir  = Path(clip_dir)
        self.clip_dir.mkdir(parents=True, exist_ok=True)
        self.pre_buf   = deque(maxlen=int(pre_s * fps))
        self.post_buf  = []
        self.post_need = int(post_s * fps)
        self.recording = False
        self.clip_path = None
        self.fps       = fps
        self._lock     = threading.Lock()

    def add_frame(self, frame: np.ndarray):
        with self._lock:
            if self.recording:
                self.post_buf.append(frame.copy())
                if len(self.post_buf) >= self.post_need:
                    self._flush()
            else:
                self.pre_buf.append(frame.copy())

    def trigger(self, event_id: str) -> str:
        with self._lock:
            if self.recording:
                return self.clip_path
            ts = datetime.now().strftime("%Y%m%d_%H%M%S")
            self.clip_path = str(self.clip_dir / f"fall_{ts}_{event_id[:8]}.mp4")
            self.post_buf  = list(self.pre_buf)
            self.recording = True
        log.info(f"Recording clip → {self.clip_path}")
        return self.clip_path

    def _flush(self):
        frames = list(self.post_buf)
        path   = self.clip_path
        self.recording = False
        self.post_buf  = []
        t = threading.Thread(target=self._write, args=(path, frames), daemon=True)
        t.start()

    def _write(self, path: str, frames: list):
        if not frames:
            return
        h, w = frames[0].shape[:2]
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        out = cv2.VideoWriter(path, fourcc, self.fps, (w, h))
        for f in frames:
            out.write(f)
        out.release()
        log.info(f"Clip saved: {path}")


# ── backend HTTP client ───────────────────────────────────────────────────────
class BackendClient:
    def __init__(self, base_url: str, device_token: str):
        self.base    = base_url.rstrip("/")
        self.token   = device_token
        self.headers = {"X-Device-Token": device_token}

    def post_fall(self, event_id: str, category: str, timestamp: str, clip_path: str | None = None) -> bool:
        payload = {
            "event_id":  event_id,
            "category":  category,
            "timestamp": timestamp,
            "clip_path": clip_path or "",
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

    def upload_clip(self, event_id: str, clip_path: str):
        if not os.path.exists(clip_path):
            return
        try:
            with open(clip_path, "rb") as f:
                r = requests.post(
                    f"{self.base}/api/fall-events/{event_id}/video",
                    files={"file": (os.path.basename(clip_path), f, "video/mp4")},
                    headers=self.headers,
                    timeout=30,
                )
            if r.status_code in (200, 201):
                log.info(f"Clip uploaded for {event_id}")
        except Exception as e:
            log.warning(f"Clip upload failed: {e}")


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


def load_detector(exp_dir: str, device: str, tensorrt: bool = False):
    ckpt  = os.path.join(exp_dir, "checkpoints")
    cfg   = json.load(open(os.path.join(ckpt, "two_stage_config.json")))
    pth   = os.path.join(ckpt, "best_stgcn.pth")
    fps   = cfg.get("fps", 19.0)

    model = STGCN(in_channels=3, num_classes=2, dropout=0.0).to(device)
    model.load_state_dict(torch.load(pth, map_location=device))
    model.eval()

    physics  = PhysicsFilter(fps=fps, vel_threshold=cfg["vel_threshold"], acc_threshold=cfg["acc_threshold"])
    detector = TwoStageDetector(model, physics,
                                stage1_threshold=cfg["stage1_threshold"],
                                rescue_threshold=cfg["rescue_threshold"],
                                device=device)
    return detector, fps


def load_yolo(tensorrt: bool):
    engine = "yolo11n-pose.engine"
    if tensorrt:
        if not os.path.exists(engine):
            log.info("Exporting YOLO to TensorRT engine (one-time, ~2 min)…")
            m = YOLO("yolo11n-pose.pt")
            m.export(format="engine", half=True, device=0)
            log.info("TensorRT export done.")
        log.info(f"Loading TensorRT engine: {engine}")
        return YOLO(engine)
    return YOLO("yolo11n-pose.pt")


# ── main loop ─────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exp",          default=None,            help="Experiment dir (default: experiments/subject1_2_3_4)")
    ap.add_argument("--source",       default="0",             help="Camera index or RTSP URL")
    ap.add_argument("--backend",      default="http://localhost:8000", help="Backend server URL")
    ap.add_argument("--device-token", default="edge-device-001", help="Device token for backend auth")
    ap.add_argument("--stream-port",  type=int, default=8081,  help="MJPEG HTTP port (default 8081)")
    ap.add_argument("--clip-dir",     default="clips",         help="Directory to save fall clips")
    ap.add_argument("--confirm",      type=int, default=3,     help="Consecutive FALL windows to confirm (default 3)")
    ap.add_argument("--min-lock",     type=float, default=5.0, help="Min seconds to hold FALL alert")
    ap.add_argument("--stand-streak", type=int, default=2,     help="Standing windows to auto-reset")
    ap.add_argument("--display",      action="store_true",     help="Show cv2 window (requires display)")
    ap.add_argument("--tensorrt",     action="store_true",     help="Use TensorRT engine for YOLO (Jetson)")
    ap.add_argument("--width",        type=int, default=640)
    ap.add_argument("--height",       type=int, default=480)
    args = ap.parse_args()

    base    = os.path.dirname(__file__)
    exp_dir = args.exp or os.path.join(base, "experiments", "subject1_2_3_4")
    device  = "cuda" if torch.cuda.is_available() else "cpu"
    log.info(f"Device: {device}")

    detector, train_fps = load_detector(exp_dir, device, tensorrt=False)
    yolo = load_yolo(args.tensorrt)
    log.info("Models loaded")

    start_mjpeg_server(args.stream_port)

    clip_dir = args.clip_dir if os.path.isabs(args.clip_dir) else os.path.join(base, args.clip_dir)
    recorder = ClipRecorder(clip_dir, pre_s=5.0, post_s=10.0, fps=15.0)
    client   = BackendClient(args.backend, args.device_token)

    # resolve camera source
    src = int(args.source) if args.source.isdigit() else args.source
    cap = cv2.VideoCapture(src)
    if not cap.isOpened():
        log.error(f"Cannot open source: {src}")
        sys.exit(1)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  args.width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, args.height)

    buf           = deque(maxlen=WINDOW)
    frame_no      = 0
    fps_disp      = 0.0
    t_prev        = time.time()
    fall_streak   = 0
    fall_active   = False
    fall_lock_t   = 0.0
    stand_streak  = 0
    baseline_hip  = 0.0
    lying_streak  = 0
    current_event_id   = None
    current_clip_path  = None

    log.info("Edge server running. Ctrl+C to stop.")

    while True:
        ret, frame = cap.read()
        if not ret:
            log.warning("Frame read failed — retrying")
            time.sleep(0.1)
            continue

        h, w = frame.shape[:2]
        frame_no += 1
        now = time.time()
        fps_disp = 0.9 * fps_disp + 0.1 / max(now - t_prev, 1e-6)
        t_prev = now

        results = yolo(frame, verbose=False, conf=0.1)
        kp = extract_kp(results[0], h, w)
        buf.append(kp)

        draw_skeleton(frame, kp, h, w)

        pred = 0
        if len(buf) == WINDOW and frame_no % STRIDE == 0:
            seq = ffill(np.stack(buf, axis=0))
            x_t = to_stgcn_tensor(seq, device)
            with torch.no_grad():
                logits = detector.model(x_t)
                prob   = float(torch.softmax(logits, dim=-1)[0, 1].item())
            pred = detector.predict_one(x_t.squeeze(0), seq)

            # personal standing baseline
            if not fall_active and is_standing(kp):
                baseline_hip = 0.88 * baseline_hip + 0.12 * float(kp[[11,12],1].mean()) if baseline_hip > 0 else float(kp[[11,12],1].mean())

            if pred == 1:
                fall_streak += 1
            else:
                if not fall_active:
                    fall_streak = 0

            if fall_streak >= args.confirm and not fall_active:
                fall_active  = True
                fall_lock_t  = time.time() + args.min_lock
                stand_streak = 0
                event_id     = f"{datetime.now().strftime('%Y%m%d%H%M%S')}"
                current_event_id  = event_id
                current_clip_path = recorder.trigger(event_id)
                client.post_fall(event_id, "severe", datetime.now().isoformat(), current_clip_path)
                log.info("FALL DETECTED — alert active")

        # auto-reset
        if fall_active and time.time() > fall_lock_t:
            if is_standing(kp):
                stand_streak += 1
                if stand_streak >= args.stand_streak:
                    fall_active  = False
                    fall_streak  = 0
                    stand_streak = 0
                    lying_streak = 0
                    log.info("Auto-reset: person standing")
            else:
                stand_streak = 0

        # upload clip once it's ready (non-blocking check)
        if current_clip_path and os.path.exists(current_clip_path) and not recorder.recording:
            eid, cp = current_event_id, current_clip_path
            current_event_id = None; current_clip_path = None
            threading.Thread(target=client.upload_clip, args=(eid, cp), daemon=True).start()

        # ── overlay ──────────────────────────────────────────────────────────
        if fall_active:
            color, label = (0,0,255), "FALL DETECTED"
        elif fall_streak > 0:
            color, label = (0,165,255), f"FALL? {fall_streak}/{args.confirm}"
        elif len(buf) == WINDOW:
            color, label = (0,220,0), "NO FALL"
        else:
            color, label = (200,200,0), "Buffering..."

        cv2.rectangle(frame, (0, 0), (w, 50), (20,20,20), -1)
        cv2.putText(frame, label, (10, 38), cv2.FONT_HERSHEY_SIMPLEX, 1.1, color, 3, cv2.LINE_AA)
        cv2.putText(frame, f"fps={fps_disp:.0f}  device={device}", (10, h-10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (150,150,150), 1, cv2.LINE_AA)

        # MJPEG publish
        _, jpg = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 75])
        with _frame_lock:
            _latest_jpg = jpg.tobytes()

        # video recording
        recorder.add_frame(frame)

        if args.display:
            cv2.imshow("MobiCare Edge", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

    cap.release()
    if args.display:
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
