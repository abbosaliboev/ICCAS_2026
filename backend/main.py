
"""
MobiCare Backend Server

Run:
  cd backend
  pip install -r requirements.txt
  python main.py

Default: http://0.0.0.0:8000
Web app: http://localhost:8000/app
"""

import os, json, uuid, shutil, asyncio, base64
from dotenv import load_dotenv
load_dotenv()
from datetime import datetime
from pathlib import Path
from typing import Optional

from fastapi import (FastAPI, WebSocket, WebSocketDisconnect,
                     HTTPException, UploadFile, File, Header, Depends, Query)
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
import uvicorn

import db
import sms

BASE   = Path(__file__).parent
CLIPS  = BASE / "storage" / "clips"
THUMBS = BASE / "storage" / "thumbnails"
CLIPS.mkdir(parents=True, exist_ok=True)
THUMBS.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="MobiCare API", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)



# ── WebSocket broadcast ───────────────────────────────────────────────────────
class ConnectionManager:
    def __init__(self):
        self._conns: dict[str, list[WebSocket]] = {}  # user_id → [ws, ...]

    async def connect(self, ws: WebSocket, user_id: str):
        await ws.accept()
        self._conns.setdefault(user_id, []).append(ws)

    def disconnect(self, ws: WebSocket, user_id: str):
        self._conns.get(user_id, []).remove(ws) if ws in self._conns.get(user_id, []) else None

    async def broadcast_to(self, user_id: str, data: dict):
        dead = []
        for ws in self._conns.get(user_id, []):
            try:
                await ws.send_json(data)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self._conns[user_id].remove(ws)

    async def broadcast_all(self, data: dict):
        for uid in list(self._conns):
            await self.broadcast_to(uid, data)


mgr = ConnectionManager()


# ── auth helpers ──────────────────────────────────────────────────────────────
def auth_user(token: str = Header(None, alias="Authorization")):
    if not token:
        raise HTTPException(401, "Missing Authorization header")
    t = token.replace("Bearer ", "").strip()
    sess = db.get_session(t)
    if not sess:
        raise HTTPException(401, "Invalid or expired token")
    user = db.get_user_by_id(sess["user_id"])
    if not user:
        raise HTTPException(401, "User not found")
    return user


def auth_device(x_device_token: str = Header(None, alias="X-Device-Token")):
    if not x_device_token:
        raise HTTPException(401, "Missing X-Device-Token")
    dev = db.get_device_by_token(x_device_token)
    if not dev:
        # auto-register unknown devices
        db.assign_device_to_user(x_device_token, None)
        dev = db.get_device_by_token(x_device_token)
    return dev


# ── Pydantic models ───────────────────────────────────────────────────────────
class LoginReq(BaseModel):
    username: str
    password: str

class RegisterReq(BaseModel):
    username:     str
    password:     str
    role:         str = "user"         # "user" | "guardian"
    display_name: str = ""
    age:          Optional[int] = None
    height:       Optional[int] = None  # cm
    weight:       Optional[int] = None  # kg
    gender:       str = ""              # "M" | "F" | ""
    phone:        str = ""
    address:      str = ""

class DeviceRegReq(BaseModel):
    device_token: str
    stream_url:   str = ""

class FallEventReq(BaseModel):
    event_id:  str
    category:  str = "severe"
    timestamp: str = ""
    clip_path: str = ""

class LinkGuardianReq(BaseModel):
    guardian_username: str

class LinkMonitoredReq(BaseModel):
    user_id: str

class CreateMonitoredReq(BaseModel):
    name: str
    address: str = ""
    phone: str = ""
    age: Optional[int] = None
    gender: str = ""
    rtsp_url: str = ""

class UpdateMonitoredReq(BaseModel):
    name: str
    address: str = ""
    phone: str = ""
    age: Optional[int] = None
    gender: str = ""
    rtsp_url: str = ""


# ── routes ────────────────────────────────────────────────────────────────────

def _fall_sms_text(target: dict, category: str) -> str:
    name = target.get("display_name") or "User"
    address = target.get("address") or "No address registered"
    label = "Severe fall" if category == "severe" else "Possible fall"
    now_str = datetime.now().strftime("%H:%M")
    return (
        f"[MobiCare] {label} detected for {name} at {now_str}. "
        f"Location: {address}. Please check the app."
    )


async def _notify_guardian_sms(event_id: str, target: dict, category: str) -> dict:
    guardian_id = target.get("guardian_id") if target else None
    if not guardian_id:
        result = {"ok": False, "mode": "error", "detail": "연결된 보호자가 없습니다."}
        db.log_sms(event_id, "", "", result["mode"], result["ok"], result["detail"])
        return result

    guardian = db.get_user_by_id(guardian_id)
    phone = (guardian or {}).get("phone", "")
    message = _fall_sms_text(target, category)
    result = await sms.send_sms(phone, message)
    db.log_sms(
        event_id,
        phone,
        message,
        result.get("mode", "error"),
        bool(result.get("ok")),
        str(result.get("detail", "")),
    )
    return result


def _can_access_event(user: dict, ev: dict, target: dict = None) -> bool:
    if not ev:
        return False
    if ev.get("user_id") == user.get("id"):
        return True
    if user.get("role") == "guardian":
        target = target or db.get_user_by_id(ev.get("user_id", "")) if ev.get("user_id") else None
        return bool(target and target.get("guardian_id") == user.get("id"))
    return False

# Web UI removed — the mobile app is the only client now.
@app.get("/", include_in_schema=False)
async def root():
    return {"service": "MobiCare backend", "client": "mobile app"}


# ── auth ──────────────────────────────────────────────────────────────────────

@app.post("/api/auth/login")
def login(body: LoginReq):
    user = db.get_user_by_username(body.username)
    if not user or user["password"] != body.password:
        raise HTTPException(401, "아이디 또는 비밀번호가 올바르지 않습니다")
    token = db.create_session(user["id"])
    return {
        "token": token,
        "user": {
            "id":           user["id"],
            "username":     user["username"],
            "role":         user["role"],
            "display_name": user["display_name"],
            "age":          user["age"],
            "phone":        user["phone"],
            "address":      user["address"],
        }
    }


@app.post("/api/auth/register", status_code=201)
def register(body: RegisterReq):
    uid = db.create_user(body.username, body.password, body.role,
                         body.display_name, body.age, body.phone, body.address,
                         body.height, body.weight, body.gender)
    if not uid:
        raise HTTPException(409, "이미 사용 중인 아이디입니다")
    token = db.create_session(uid)
    return {"token": token, "user_id": uid}


@app.post("/api/auth/logout")
def logout(token: str = Header(None, alias="Authorization")):
    if token:
        db.delete_session(token.replace("Bearer ", "").strip())
    return {"ok": True}


# ── users ─────────────────────────────────────────────────────────────────────

@app.get("/api/users/me")
def me(user=Depends(auth_user)):
    return user


class ProfileReq(BaseModel):
    display_name: str = ""
    age: Optional[int] = None
    height: Optional[int] = None
    weight: Optional[int] = None
    gender: str = ""
    phone: str = ""
    address: str = ""

@app.put("/api/users/me")
def update_profile(body: ProfileReq, user=Depends(auth_user)):
    db.update_user_profile(user["id"], body.display_name, body.age, body.phone, body.address,
                           body.height, body.weight, body.gender)
    updated = db.get_user_by_id(user["id"])
    return updated


@app.post("/api/users/link-guardian")
def link_guardian(body: LinkGuardianReq, user=Depends(auth_user)):
    g = db.get_user_by_username(body.guardian_username)
    if not g or g["role"] != "guardian":
        raise HTTPException(404, "보호자를 찾을 수 없습니다")
    db.link_guardian(user["id"], g["id"])
    return {"ok": True}


@app.get("/api/users/monitored")
def monitored(user=Depends(auth_user)):
    if user["role"] != "guardian":
        raise HTTPException(403, "Guardian only")
    return db.get_monitored_users(user["id"])



@app.post("/api/users/link-monitored")
def link_monitored(body: LinkMonitoredReq, user=Depends(auth_user)):
    if user["role"] != "guardian":
        raise HTTPException(403, "Guardian only")
    linked = db.link_monitored_user(user["id"], body.user_id.strip())
    if not linked:
        raise HTTPException(404, "실사용자를 찾을 수 없습니다")
    return linked


@app.post("/api/users/monitored")
def create_monitored(body: CreateMonitoredReq, user=Depends(auth_user)):
    if user["role"] != "guardian":
        raise HTTPException(403, "Guardian only")
    stream_url = body.rtsp_url.strip()
    if stream_url and not stream_url.startswith(("http://", "https://")):
        stream_url = "demo://" + stream_url
    linked = db.create_monitored_user(
        user["id"], body.name.strip() or "Demo User", body.age,
        body.phone.strip(), body.address.strip(), body.gender.strip(), stream_url,
    )
    if not linked:
        raise HTTPException(500, "실사용자를 추가할 수 없습니다")
    return linked



@app.put("/api/users/monitored/{user_id}")
def update_monitored(user_id: str, body: UpdateMonitoredReq, user=Depends(auth_user)):
    if user["role"] != "guardian":
        raise HTTPException(403, "Guardian only")
    stream_url = body.rtsp_url.strip()
    if stream_url and not stream_url.startswith(("http://", "https://")):
        stream_url = "demo://" + stream_url
    updated = db.update_monitored_user(
        user["id"], user_id, body.name.strip() or "Demo User", body.age,
        body.phone.strip(), body.address.strip(), body.gender.strip(), stream_url,
    )
    if not updated:
        raise HTTPException(404, "실사용자를 찾을 수 없습니다")
    return updated

@app.delete("/api/users/monitored/{user_id}")
def delete_monitored(user_id: str, user=Depends(auth_user)):
    if user["role"] != "guardian":
        raise HTTPException(403, "Guardian only")
    ok = db.remove_monitored_user(user["id"], user_id)
    if not ok:
        raise HTTPException(404, "실사용자를 찾을 수 없습니다")
    return {"ok": True}
@app.get("/api/reports/call-count")
def report_call_count(user=Depends(auth_user)):
    if user["role"] == "guardian":
        return {"count": db.get_guardian_call_count(user["id"])}
    return {"count": 0}

# ── devices ───────────────────────────────────────────────────────────────────

@app.post("/api/devices", status_code=201)
def register_device(body: DeviceRegReq, user=Depends(auth_user)):
    db.assign_device_to_user(body.device_token, user["id"], body.stream_url)
    return {"ok": True}


@app.get("/api/devices")
def list_devices(user=Depends(auth_user)):
    return db.get_devices_for_user(user["id"])


class StreamUrlReq(BaseModel):
    stream_url: str = ""

@app.put("/api/devices/{device_token}/stream-url")
def set_stream_url(device_token: str, body: StreamUrlReq, user=Depends(auth_user)):
    db.update_device_stream_url(device_token, body.stream_url)
    return {"ok": True}


# ── fall events (from edge device) ───────────────────────────────────────────

@app.post("/api/fall-events", status_code=201)
async def ingest_fall(body: FallEventReq, dev=Depends(auth_device)):
    ts = body.timestamp or datetime.now().isoformat()
    user_id = dev.get("user_id")
    db.create_fall_event(body.event_id, dev["id"], user_id, ts, body.category, body.clip_path)

    event_data = {
        "type":      "fall_detected",
        "event_id":  body.event_id,
        "category":  body.category,
        "timestamp": ts,
        "device_id": dev["id"],
    }

    # notify the device's user and their guardian
    if user_id:
        target = db.get_user_by_id(user_id)
        await mgr.broadcast_to(user_id, event_data)
        if target and target.get("guardian_id"):
            await mgr.broadcast_to(target["guardian_id"], {
                **event_data,
                "monitored_user_id":   user_id,
                "monitored_user_name": target.get("display_name", "피보호자"),
            })
        if target and body.category == "severe":
            await _notify_guardian_sms(body.event_id, target, body.category)

    return {"ok": True}


@app.post("/api/fall-events/{event_id}/video")
async def upload_clip(event_id: str, file: UploadFile = File(...), dev=Depends(auth_device)):
    ev = db.get_fall_event(event_id)
    if not ev:
        raise HTTPException(404, "낙상 이벤트가 DB에 먼저 생성되어야 합니다")
    ext   = Path(file.filename).suffix or ".mp4"
    fname = f"{event_id}{ext}"
    dest  = CLIPS / fname
    with open(dest, "wb") as f:
        shutil.copyfileobj(file.file, f)
    db.update_fall_event_video(event_id, str(dest))
    return {"ok": True, "path": f"/api/fall-events/{event_id}/video/file"}


@app.get("/api/fall-events")
def list_fall_events(
    user=Depends(auth_user),
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    if user["role"] == "guardian":
        events = db.get_guardian_events(user["id"])
        return events[offset:offset + limit]
    return db.get_fall_events(user["id"], limit=limit, offset=offset)


@app.get("/api/fall-events/{event_id}")
def get_fall_event(event_id: str, user=Depends(auth_user)):
    ev = db.get_fall_event(event_id)
    if not ev:
        raise HTTPException(404, "Not found")
    return ev


def auth_media(authorization: str = Header(None, alias="Authorization"),
               token: str = Query(None)):
    """Auth for media endpoints — accepts token as header OR query param (for <video> tags)."""
    t = token or (authorization or "").replace("Bearer ", "").strip()
    if not t:
        raise HTTPException(401, "Missing token")
    sess = db.get_session(t)
    if not sess:
        raise HTTPException(401, "Invalid token")
    return db.get_user_by_id(sess["user_id"])


@app.get("/api/fall-events/{event_id}/video/file")
def get_clip(event_id: str, user=Depends(auth_media)):
    ev = db.get_fall_event(event_id)
    if not ev or not ev.get("video_path"):
        raise HTTPException(404, "영상이 없습니다")
    path = Path(ev["video_path"])
    if not path.exists() or path.stat().st_size < 1000:
        raise HTTPException(404, "파일을 찾을 수 없습니다")
    return FileResponse(str(path), media_type="video/mp4",
                        headers={"Content-Disposition": f'inline; filename="{event_id}.mp4"'})


@app.post("/api/fall-events/{event_id}/resolve")
async def resolve_fall(event_id: str, dev=Depends(auth_device)):
    """Called by edge server when person stands up — broadcasts fall_resolved to frontend."""
    ev = db.get_fall_event(event_id)
    if ev and ev.get("user_id"):
        user_id = ev["user_id"]
        payload = {"type": "fall_resolved", "event_id": event_id}
        await mgr.broadcast_to(user_id, payload)
        target = db.get_user_by_id(user_id)
        if target and target.get("guardian_id"):
            await mgr.broadcast_to(target["guardian_id"], payload)
    return {"ok": True}


@app.post("/api/fall-events/{event_id}/acknowledge")
def ack_event(event_id: str, user=Depends(auth_user)):
    db.acknowledge_fall_event(event_id)
    return {"ok": True}


class BatchDeleteReq(BaseModel):
    ids: list[str]

@app.post("/api/fall-events/batch-delete")
def batch_delete_events(body: BatchDeleteReq, user=Depends(auth_user)):
    for event_id in body.ids:
        ev = db.get_fall_event(event_id)
        if ev:
            for key in ("video_path", "thumbnail_path"):
                p = ev.get(key)
                if p and Path(p).exists():
                    Path(p).unlink(missing_ok=True)
    db.delete_fall_events(body.ids)
    return {"ok": True, "deleted": len(body.ids)}


@app.delete("/api/fall-events/{event_id}")
def delete_event(event_id: str, user=Depends(auth_user)):
    import shutil
    ev = db.get_fall_event(event_id)
    if ev:
        for key in ("video_path", "thumbnail_path"):
            p = ev.get(key)
            if p and Path(p).exists():
                Path(p).unlink(missing_ok=True)
    db.delete_fall_event(event_id)
    return {"ok": True}


@app.post("/api/fall-events/{event_id}/screenshot")
async def upload_screenshot(event_id: str, file: UploadFile = File(...), dev=Depends(auth_device)):
    fname = f"{event_id}_thumb.jpg"
    dest  = THUMBS / fname
    with open(dest, "wb") as f:
        shutil.copyfileobj(file.file, f)
    db.update_fall_event_thumbnail(event_id, str(dest))
    return {"ok": True}


@app.get("/api/fall-events/{event_id}/screenshot")
def get_screenshot(event_id: str, user=Depends(auth_media)):
    ev = db.get_fall_event(event_id)
    if not ev:
        raise HTTPException(404, "Event not found")
    # Try DB path first
    if ev.get("thumbnail_path"):
        path = Path(ev["thumbnail_path"])
        if path.exists():
            return FileResponse(str(path), media_type="image/jpeg")
    # Fallback: check computed path (handles race condition where DB not updated yet)
    fallback = THUMBS / f"{event_id}_thumb.jpg"
    if fallback.exists():
        db.update_fall_event_thumbnail(event_id, str(fallback))
        return FileResponse(str(fallback), media_type="image/jpeg")
    raise HTTPException(404, "No screenshot")


@app.get("/api/fall-events/{event_id}/emergency-report")
def emergency_report(event_id: str, user=Depends(auth_user)):
    ev = db.get_fall_event(event_id)
    if not ev:
        raise HTTPException(404, "Not found")
    target = db.get_user_by_id(ev.get("user_id", "")) if ev.get("user_id") else {}
    ts = ev.get("timestamp", "")
    try:
        dt = datetime.fromisoformat(ts)
        ts_str = dt.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        ts_str = ts
    return {
        "event_id":  event_id,
        "timestamp": ts_str,
        "name":      target.get("display_name", "미상"),
        "age":       target.get("age", "미상"),
        "address":   target.get("address", "미상"),
        "phone":     target.get("phone", "미상"),
        "category":  ev.get("category", "severe"),
        "estimated_injury": "확인 필요",
        "gps":       "위치 정보 없음",
        "has_video": bool(ev.get("video_path")),
    }


_EMERGENCY_TEST_PHONE = "01088490868"  # 테스트용 — 실제 119 대신 이 번호로 전송

@app.post("/api/fall-events/{event_id}/notify-emergency-sms")
async def notify_emergency_sms(event_id: str, user=Depends(auth_user)):
    ev = db.get_fall_event(event_id)
    if not ev:
        raise HTTPException(404, "이벤트를 찾을 수 없습니다")
    target = db.get_user_by_id(ev.get("user_id", "")) if ev.get("user_id") else {}
    name = (target or {}).get("display_name") or "User"
    address = (target or {}).get("address") or "No address registered"
    now_str = datetime.now().strftime("%H:%M")
    message = (
        f"[MobiCare EMERGENCY] Fall detected for {name} at {now_str}. "
        f"Location: {address}. Immediate attention required."
    )
    result = await sms.send_sms(_EMERGENCY_TEST_PHONE, message)
    db.log_sms(
        event_id,
        _EMERGENCY_TEST_PHONE,
        message,
        result.get("mode", "error"),
        bool(result.get("ok")),
        str(result.get("detail", "")),
    )
    return result


@app.post("/api/fall-events/{event_id}/notify-guardian-sms")
async def notify_guardian_sms(event_id: str, user=Depends(auth_user)):
    ev = db.get_fall_event(event_id)
    if not ev:
        raise HTTPException(404, "이벤트를 찾을 수 없습니다")
    target = db.get_user_by_id(ev.get("user_id", "")) if ev.get("user_id") else None
    if not target:
        raise HTTPException(404, "대상 사용자를 찾을 수 없습니다")
    if not _can_access_event(user, ev, target):
        raise HTTPException(403, "이 이벤트에 접근할 수 없습니다")
    return await _notify_guardian_sms(event_id, target, ev.get("category", "severe"))


@app.get("/api/fall-events/{event_id}/sms-logs")
def fall_event_sms_logs(event_id: str, user=Depends(auth_user)):
    ev = db.get_fall_event(event_id)
    if not ev:
        raise HTTPException(404, "이벤트를 찾을 수 없습니다")
    target = db.get_user_by_id(ev.get("user_id", "")) if ev.get("user_id") else None
    if not _can_access_event(user, ev, target):
        raise HTTPException(403, "이 이벤트에 접근할 수 없습니다")
    return db.get_sms_logs_for_event(event_id)


# ── WebSocket ─────────────────────────────────────────────────────────────────

@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket, token: str = ""):
    sess = db.get_session(token) if token else None
    if not sess:
        await ws.close(code=4001)
        return
    user_id = sess["user_id"]
    await mgr.connect(ws, user_id)
    try:
        while True:
            data = await ws.receive_text()
            if data == "ping":
                await ws.send_text("pong")
    except WebSocketDisconnect:
        mgr.disconnect(ws, user_id)


# ── speech transcription fallback ─────────────────────────────────────────────

@app.post("/api/speech/transcribe")
async def transcribe_speech(file: UploadFile = File(...), user=Depends(auth_user)):
    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(503, "OPENAI_API_KEY is not configured")

    audio = await file.read()
    if not audio:
        raise HTTPException(400, "Empty audio")

    model = os.environ.get("OPENAI_TRANSCRIBE_MODEL", "whisper-1")
    filename = file.filename or "speech.webm"
    content_type = file.content_type or "audio/webm"
    files = {
        "file": (filename, audio, content_type),
        "model": (None, model),
        "language": (None, "ko"),
    }
    headers = {"Authorization": f"Bearer {api_key}"}
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            r = await client.post(
                "https://api.openai.com/v1/audio/transcriptions",
                headers=headers,
                files=files,
            )
        if r.status_code >= 400:
            raise HTTPException(r.status_code, r.text)
        data = r.json()
        return {"text": data.get("text", "")}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(502, f"Transcription failed: {exc}")


# ── MJPEG stream proxy ────────────────────────────────────────────────────────
# The edge server (edge_server.py) may run on a different machine than this
# backend. edge_server.py self-reports its own reachable address on startup via
# POST /api/device/stream-url, so this is normally zero-config.

EDGE_STREAM_URL     = os.environ.get("EDGE_STREAM_URL",     "http://localhost:8081/video")
EDGE_SNAPSHOT_URL   = os.environ.get("EDGE_SNAPSHOT_URL",  "http://localhost:8081/snapshot")
_DEMO_JPEG = base64.b64decode(
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAH/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAEFAqf/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEDAQE/ASP/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/ASP/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAY/Al//xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/IV//2gAMAwEAAgADAAAAEP/EABQRAQAAAAAAAAAAAAAAAAAAABD/2gAIAQMBAT8QH//EABQRAQAAAAAAAAAAAAAAAAAAABD/2gAIAQIBAT8QH//EABQQAQAAAAAAAAAAAAAAAAAAABD/2gAIAQEAAT8QH//Z"
)

async def _demo_mjpeg():
    while True:
        yield b"--mjpeg\r\nContent-Type: image/jpeg\r\nContent-Length: " + str(len(_DEMO_JPEG)).encode() + b"\r\n\r\n" + _DEMO_JPEG + b"\r\n"
        await asyncio.sleep(0.2)


def _stream_user_id(user: dict, requested_user_id: str = None) -> str:
    if not requested_user_id:
        return user.get("id")
    if requested_user_id == user.get("id"):
        return requested_user_id
    if user.get("role") == "guardian":
        target = db.get_user_by_id(requested_user_id)
        if target and target.get("guardian_id") == user.get("id"):
            return requested_user_id
    raise HTTPException(403, "이 스트림에 접근할 수 없습니다")


def _edge_stream_url(user_id: str = None) -> str:
    dev = db.get_latest_device_for_user(user_id) if user_id else db.get_latest_device()
    if dev and dev.get("stream_url"):
        return dev["stream_url"].rstrip("/") + "/video"
    if user_id:
        raise HTTPException(404, "연결된 카메라가 없습니다")
    return EDGE_STREAM_URL


def _edge_snapshot_url(user_id: str = None) -> str:
    dev = db.get_latest_device_for_user(user_id) if user_id else db.get_latest_device()
    if dev and dev.get("stream_url"):
        return dev["stream_url"].rstrip("/") + "/snapshot"
    if user_id:
        raise HTTPException(404, "연결된 카메라가 없습니다")
    return EDGE_SNAPSHOT_URL


@app.get("/api/stream/video")
async def proxy_stream(user_id: str = Query(None), user=Depends(auth_user)):
    target_user_id = _stream_user_id(user, user_id)

    stream_ref = _edge_stream_url(target_user_id)
    if stream_ref.startswith("demo://"):
        return StreamingResponse(
            _demo_mjpeg(),
            media_type="multipart/x-mixed-replace; boundary=--mjpeg",
            headers={"Cache-Control": "no-cache"},
        )

    async def _gen():
        try:
            async with httpx.AsyncClient(
                timeout=httpx.Timeout(connect=3.0, read=None, write=None, pool=None)
            ) as client:
                async with client.stream("GET", stream_ref) as r:
                    async for chunk in r.aiter_bytes(chunk_size=4096):
                        yield chunk
        except Exception as exc:
            import logging
            logging.getLogger("main").warning(f"Stream proxy error: {exc}")

    return StreamingResponse(
        _gen(),
        media_type="multipart/x-mixed-replace; boundary=--mjpeg",
        headers={"Cache-Control": "no-cache"},
    )


@app.get("/api/stream/snapshot")
async def stream_snapshot(user_id: str = Query(None), user=Depends(auth_user)):
    """Return the latest JPEG frame — works on all browsers including iOS Safari."""
    from fastapi.responses import Response
    target_user_id = _stream_user_id(user, user_id)
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(2.0)) as client:
            r = await client.get(_edge_snapshot_url(target_user_id))
            return Response(content=r.content, media_type="image/jpeg",
                            headers={"Cache-Control": "no-cache, no-store"})
    except Exception:
        raise HTTPException(503, "Stream unavailable")

# ── safe zone ────────────────────────────────────────────────────────────────

SAFE_ZONE_PATH  = BASE.parent / "fall_iccas" / "safe_zone.json"
CAM_CONFIG_PATH = BASE.parent / "fall_iccas" / "camera_config.json"

def _safe_zone_path(user_id: str = None):
    if not user_id:
        return SAFE_ZONE_PATH
    safe_id = "".join(c for c in user_id if c.isalnum() or c in ("-", "_"))
    return BASE.parent / "fall_iccas" / f"safe_zone_{safe_id}.json"

@app.get("/api/device/config")
def get_device_config(dev=Depends(auth_device)):
    """Edge server polls this every 15s to get safe zones + camera type."""
    zones = []
    zone_path = _safe_zone_path(dev.get("user_id"))
    if not zone_path.exists():
        zone_path = SAFE_ZONE_PATH
    if zone_path.exists():
        try:
            zones = json.loads(zone_path.read_text()).get("zones", [])
        except Exception:
            pass
    cam_type = "front"
    if CAM_CONFIG_PATH.exists():
        try:
            cam_type = json.loads(CAM_CONFIG_PATH.read_text()).get("camera_type", "front")
        except Exception:
            pass
    return {"zones": zones, "camera_type": cam_type}


class DeviceStreamUrlReq(BaseModel):
    stream_url: str

@app.post("/api/device/stream-url")
def report_device_stream_url(body: DeviceStreamUrlReq, dev=Depends(auth_device)):
    """Edge server self-reports its own reachable stream URL on startup (and
    periodically) — lets the app's stream proxy find it without the operator
    having to manually configure EDGE_STREAM_URL when edge and backend run on
    different machines."""
    db.update_device_stream_url(dev["id"], body.stream_url)
    return {"ok": True}


class SafeZoneReq(BaseModel):
    zones: list

@app.get("/api/safe-zone")
def get_safe_zone(user_id: str = Query(None), user=Depends(auth_user)):
    target_user_id = _stream_user_id(user, user_id)
    zone_path = _safe_zone_path(target_user_id)
    if not zone_path.exists() and target_user_id:
        zone_path = SAFE_ZONE_PATH
    if not zone_path.exists():
        return {"zones": []}
    return json.loads(zone_path.read_text())

@app.post("/api/safe-zone")
def set_safe_zone(body: SafeZoneReq, user_id: str = Query(None), user=Depends(auth_user)):
    target_user_id = _stream_user_id(user, user_id)
    zone_path = _safe_zone_path(target_user_id)
    zone_path.parent.mkdir(parents=True, exist_ok=True)
    zone_path.write_text(json.dumps({"zones": body.zones}, indent=2))
    return {"ok": True}

class CamTypeReq(BaseModel):
    camera_type: str = "front"  # "front" | "top"

@app.post("/api/safe-zone/camera-type")
def set_camera_type(body: CamTypeReq, user=Depends(auth_user)):
    cam_cfg_path = BASE.parent / "fall_iccas" / "camera_config.json"
    cam_cfg_path.write_text(json.dumps({"camera_type": body.camera_type}))
    return {"ok": True}

@app.delete("/api/safe-zone")
def clear_safe_zone(user_id: str = Query(None), user=Depends(auth_user)):
    target_user_id = _stream_user_id(user, user_id)
    zone_path = _safe_zone_path(target_user_id)
    if zone_path.exists():
        zone_path.unlink()
    return {"ok": True}


# ── heatmap (stub — returns static data) ─────────────────────────────────────

@app.get("/api/heatmap")
def heatmap(user=Depends(auth_user)):
    return {
        "zones": [
            {"label": "거실", "risk": 0.72, "x": 0.3, "y": 0.4},
            {"label": "화장실", "risk": 0.88, "x": 0.7, "y": 0.2},
            {"label": "침실", "risk": 0.45, "x": 0.5, "y": 0.7},
        ]
    }


# ── startup ───────────────────────────────────────────────────────────────────

@app.on_event("startup")
def startup():
    db.init_db()


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)









