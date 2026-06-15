"""
MobiCare Backend Server

Run:
  cd backend
  pip install -r requirements.txt
  python main.py

Default: http://0.0.0.0:8000
Web app: http://localhost:8000/app
"""

import os, json, uuid, shutil
from datetime import datetime
from pathlib import Path
from typing import Optional

from fastapi import (FastAPI, WebSocket, WebSocketDisconnect,
                     HTTPException, UploadFile, File, Header, Depends)
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

import db

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

# Serve web app from static/
STATIC = BASE / "static"
app.mount("/static", StaticFiles(directory=str(STATIC)), name="static")


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


# ── routes ────────────────────────────────────────────────────────────────────

@app.get("/app", include_in_schema=False)
@app.get("/app/{path:path}", include_in_schema=False)
async def spa(path: str = ""):
    return FileResponse(str(STATIC / "index.html"))


@app.get("/", include_in_schema=False)
async def root():
    return FileResponse(str(STATIC / "index.html"))


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
                         body.display_name, body.age, body.phone, body.address)
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

    return {"ok": True}


@app.post("/api/fall-events/{event_id}/video")
async def upload_clip(event_id: str, file: UploadFile = File(...), dev=Depends(auth_device)):
    ext   = Path(file.filename).suffix or ".mp4"
    fname = f"{event_id}{ext}"
    dest  = CLIPS / fname
    with open(dest, "wb") as f:
        shutil.copyfileobj(file.file, f)
    db.update_fall_event_video(event_id, str(dest))
    return {"ok": True, "path": f"/api/fall-events/{event_id}/video/file"}


@app.get("/api/fall-events")
def list_fall_events(user=Depends(auth_user)):
    if user["role"] == "guardian":
        events = db.get_guardian_events(user["id"])
    else:
        events = db.get_fall_events(user["id"])
    return events


@app.get("/api/fall-events/{event_id}")
def get_fall_event(event_id: str, user=Depends(auth_user)):
    ev = db.get_fall_event(event_id)
    if not ev:
        raise HTTPException(404, "Not found")
    return ev


@app.get("/api/fall-events/{event_id}/video/file")
def get_clip(event_id: str, user=Depends(auth_user)):
    ev = db.get_fall_event(event_id)
    if not ev or not ev.get("video_path"):
        raise HTTPException(404, "영상이 없습니다")
    path = Path(ev["video_path"])
    if not path.exists():
        raise HTTPException(404, "파일을 찾을 수 없습니다")
    return FileResponse(str(path), media_type="video/mp4",
                        headers={"Content-Disposition": f'inline; filename="{event_id}.mp4"'})


@app.post("/api/fall-events/{event_id}/acknowledge")
def ack_event(event_id: str, user=Depends(auth_user)):
    db.acknowledge_fall_event(event_id)
    return {"ok": True}


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
