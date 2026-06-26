
"""
MobiCare Backend Server

Run:
  cd backend
  pip install -r requirements.txt
  python main.py

Default: http://0.0.0.0:8000
Web app: http://localhost:8000/app
"""

import os, json, uuid, shutil, base64
from datetime import datetime
from pathlib import Path
from typing import Optional

from fastapi import (FastAPI, WebSocket, WebSocketDisconnect,
                     HTTPException, UploadFile, File, Header, Depends, Query)
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
import uvicorn

import db

BASE   = Path(__file__).parent
CLIPS  = BASE / "storage" / "clips"
THUMBS = BASE / "storage" / "thumbnails"
RISK_ZONES_FILE = BASE / "storage" / "risk_zones.json"
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

_NO_CACHE = {"Cache-Control": "no-cache, no-store, must-revalidate", "Pragma": "no-cache"}

@app.get("/app", include_in_schema=False)
@app.get("/app/{path:path}", include_in_schema=False)
async def spa(path: str = ""):
    return FileResponse(str(STATIC / "index.html"), headers=_NO_CACHE)


@app.get("/", include_in_schema=False)
async def root():
    return FileResponse(str(STATIC / "index.html"), headers=_NO_CACHE)


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
    return FileResponse(str(path), media_type='video/mp4; codecs="avc1.42E01F"',
                        headers={"Content-Disposition": f'inline; filename="{event_id}.mp4"'})


@app.post("/api/fall-events/{event_id}/acknowledge")
def ack_event(event_id: str, user=Depends(auth_user)):
    db.acknowledge_fall_event(event_id)
    return {"ok": True}


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
    if not ev or not ev.get("thumbnail_path"):
        raise HTTPException(404, "No screenshot")
    path = Path(ev["thumbnail_path"])
    if not path.exists():
        raise HTTPException(404, "File not found")
    return FileResponse(str(path), media_type="image/jpeg")


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


# ── MJPEG stream proxy ────────────────────────────────────────────────────────
# Edge server runs on the same machine at localhost:8081.
# Proxying here lets the browser load the stream from the same origin (port 8000),
# avoiding CORS issues and the need to expose port 8081 to the network separately.

EDGE_STREAM_URL     = os.environ.get("EDGE_STREAM_URL",     "http://localhost:8081/video")
EDGE_SNAPSHOT_URL   = os.environ.get("EDGE_SNAPSHOT_URL",  "http://localhost:8081/snapshot")


@app.get("/api/stream/video")
async def proxy_stream():
    async def _gen():
        try:
            async with httpx.AsyncClient(
                timeout=httpx.Timeout(connect=3.0, read=None, write=None, pool=None)
            ) as client:
                async with client.stream("GET", EDGE_STREAM_URL) as r:
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
async def stream_snapshot():
    """Return the latest JPEG frame — works on all browsers including iOS Safari."""
    from fastapi.responses import Response
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(2.0)) as client:
            r = await client.get(EDGE_SNAPSHOT_URL)
            return Response(content=r.content, media_type="image/jpeg",
                            headers={"Cache-Control": "no-cache, no-store"})
    except Exception:
        raise HTTPException(503, "Stream unavailable")


@app.get("/api/stream/sse")
async def stream_sse():
    """SSE stream of base64-encoded JPEG frames — universally supported including iOS Safari."""
    import asyncio, base64

    async def _generate():
        async with httpx.AsyncClient(timeout=httpx.Timeout(2.0)) as client:
            while True:
                try:
                    r = await client.get(EDGE_SNAPSHOT_URL)
                    if r.status_code == 200:
                        b64 = base64.b64encode(r.content).decode()
                        yield f"data: {b64}\n\n"
                except Exception:
                    yield "data: error\n\n"
                await asyncio.sleep(0.1)   # 10 fps

    return StreamingResponse(
        _generate(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


# ── living-room risk zones ────────────────────────────────────────────────────

def default_living_room_risk_zones():
    return {
        "room": "living_room",
        "source": "default_template",
        "basis": "CDC/NHS home fall-prevention guidance: rugs, cluttered pathways, furniture transfer areas, cords, and thresholds are common modifiable trip/fall hazards.",
        "zones": [
            {
                "id": "rug_edge",
                "rank": 1,
                "label": "Rug / Carpet Edge",
                "label_ko": "러그/카펫 경계",
                "risk": 0.92,
                "x": 0.18,
                "y": 0.60,
                "w": 0.64,
                "h": 0.25,
                "reason": "Loose rugs and floor-surface changes are common trip hazards.",
            },
            {
                "id": "sofa_transfer",
                "rank": 2,
                "label": "Sofa / Chair Transfer",
                "label_ko": "소파/의자 앞",
                "risk": 0.86,
                "x": 0.03,
                "y": 0.33,
                "w": 0.25,
                "h": 0.45,
                "reason": "Standing up, sitting down, and turning near furniture can destabilize balance.",
            },
            {
                "id": "walking_path",
                "rank": 3,
                "label": "Main Walking Path",
                "label_ko": "중앙 동선",
                "risk": 0.78,
                "x": 0.34,
                "y": 0.36,
                "w": 0.34,
                "h": 0.43,
                "reason": "Cluttered or narrow paths force detours around furniture.",
            },
            {
                "id": "cable_tv",
                "rank": 4,
                "label": "Cable / TV Stand",
                "label_ko": "전선/TV장 주변",
                "risk": 0.72,
                "x": 0.68,
                "y": 0.36,
                "w": 0.27,
                "h": 0.35,
                "reason": "Cords and low furniture near the wall can cause trips.",
            },
            {
                "id": "doorway_threshold",
                "rank": 5,
                "label": "Doorway / Threshold",
                "label_ko": "문턱/입구",
                "risk": 0.66,
                "x": 0.00,
                "y": 0.08,
                "w": 0.20,
                "h": 0.27,
                "reason": "Thresholds and lighting changes increase trip risk.",
            },
        ]
    }


def _sanitize_risk_zones(data: dict, source: str):
    zones = []
    for i, z in enumerate((data or {}).get("zones", [])[:6], start=1):
        try:
            x = max(0.0, min(1.0, float(z.get("x", 0))))
            y = max(0.0, min(1.0, float(z.get("y", 0))))
            w = max(0.04, min(1.0 - x, float(z.get("w", 0.2))))
            h = max(0.04, min(1.0 - y, float(z.get("h", 0.2))))
            risk = max(0.0, min(1.0, float(z.get("risk", 0.7))))
        except Exception:
            continue
        zones.append({
            "id": str(z.get("id") or f"gpt_zone_{i}"),
            "rank": int(z.get("rank") or i),
            "label": str(z.get("label") or f"Risk Zone {i}")[:48],
            "label_ko": str(z.get("label_ko") or z.get("label") or f"위험구역 {i}")[:48],
            "risk": risk,
            "x": x,
            "y": y,
            "w": w,
            "h": h,
            "reason": str(z.get("reason") or "")[:220],
        })
    return {
        "room": "living_room",
        "source": source,
        "analyzed_at": datetime.now().isoformat(),
        "basis": str((data or {}).get("basis") or "Camera snapshot analysis"),
        "zones": zones,
    }


def _load_saved_risk_zones():
    if not RISK_ZONES_FILE.exists():
        return None
    try:
        return json.loads(RISK_ZONES_FILE.read_text(encoding="utf-8"))
    except Exception:
        return None


def _save_risk_zones(data: dict):
    RISK_ZONES_FILE.parent.mkdir(parents=True, exist_ok=True)
    RISK_ZONES_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


@app.get("/api/heatmap")
def heatmap(user=Depends(auth_user)):
    return _load_saved_risk_zones() or default_living_room_risk_zones()


@app.post("/api/heatmap/analyze")
async def analyze_heatmap(user=Depends(auth_user)):
    """Analyze one current camera snapshot with a vision model, then cache coordinates."""
    gemini_key = os.environ.get("GEMINI_API_KEY")
    openai_key = os.environ.get("OPENAI_API_KEY")
    if not gemini_key and not openai_key:
        data = default_living_room_risk_zones()
        data["source"] = "default_template_no_ai_key"
        _save_risk_zones(data)
        return {"ok": True, "used_ai": False, **data}

    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(8.0)) as client:
            snap = await client.get(EDGE_SNAPSHOT_URL)
            snap.raise_for_status()
    except Exception:
        raise HTTPException(503, "Camera snapshot unavailable")

    image_b64 = base64.b64encode(snap.content).decode("ascii")
    schema = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "basis": {"type": "string"},
            "zones": {
                "type": "array",
                "maxItems": 5,
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "id": {"type": "string"},
                        "rank": {"type": "integer"},
                        "label": {"type": "string"},
                        "label_ko": {"type": "string"},
                        "risk": {"type": "number"},
                        "x": {"type": "number"},
                        "y": {"type": "number"},
                        "w": {"type": "number"},
                        "h": {"type": "number"},
                        "reason": {"type": "string"},
                    },
                    "required": ["id", "rank", "label", "label_ko", "risk", "x", "y", "w", "h", "reason"],
                },
            },
        },
        "required": ["basis", "zones"],
    }
    prompt = (
        "Analyze this fixed living-room camera snapshot for older-adult fall hazards. "
        "Return up to five rectangular risk zones using normalized coordinates x,y,w,h in 0..1 relative to the image. "
        "Prioritize visible hazards such as rug/carpet edges, cluttered walking paths, cords, low furniture, sofa/chair transfer areas, "
        "door thresholds, slippery-looking floor transitions, and poorly lit or narrow routes. "
        "If a hazard is uncertain, keep the rectangle conservative and explain briefly. Do not identify people."
    )
    if gemini_key:
        gemini_schema = json.loads(json.dumps(schema))
        def _strip_unsupported_schema_keys(obj):
            if isinstance(obj, dict):
                obj.pop("additionalProperties", None)
                for v in obj.values():
                    _strip_unsupported_schema_keys(v)
            elif isinstance(obj, list):
                for v in obj:
                    _strip_unsupported_schema_keys(v)
        _strip_unsupported_schema_keys(gemini_schema)
        gemini_model = os.environ.get("GEMINI_RISK_MODEL", "gemini-2.5-flash")
        gemini_payload = {
            "contents": [
                {
                    "role": "user",
                    "parts": [
                        {"text": prompt},
                        {"inline_data": {"mime_type": "image/jpeg", "data": image_b64}},
                    ],
                }
            ],
            "generationConfig": {
                "responseMimeType": "application/json",
                "responseSchema": gemini_schema,
                "temperature": 0.2,
            }
        }
        try:
            async with httpx.AsyncClient(timeout=httpx.Timeout(30.0)) as client:
                res = await client.post(
                    f"https://generativelanguage.googleapis.com/v1beta/models/{gemini_model}:generateContent",
                    params={"key": gemini_key},
                    headers={"Content-Type": "application/json"},
                    json=gemini_payload,
                )
                res.raise_for_status()
                raw = res.json()
            parts = raw.get("candidates", [{}])[0].get("content", {}).get("parts", [])
            text = "".join(p.get("text", "") for p in parts if isinstance(p, dict))
            parsed = json.loads(text)
            data = _sanitize_risk_zones(parsed, "gemini_snapshot")
            if data["zones"]:
                _save_risk_zones(data)
                return {"ok": True, "used_ai": True, **data}
        except httpx.HTTPStatusError as exc:
            gemini_error = exc.response.text[:240] if exc.response is not None else "Gemini HTTP error"
        except Exception as exc:
            gemini_error = exc.__class__.__name__
        else:
            gemini_error = "Gemini returned no zones"

        if not openai_key:
            data = default_living_room_risk_zones()
            data["source"] = "default_template_gemini_error"
            data["error"] = gemini_error
            _save_risk_zones(data)
            return {"ok": True, "used_ai": False, **data}

    payload = {
        "model": os.environ.get("OPENAI_RISK_MODEL", "gpt-4.1-mini"),
        "input": [{
            "role": "user",
            "content": [
                {"type": "input_text", "text": prompt},
                {"type": "input_image", "image_url": f"data:image/jpeg;base64,{image_b64}"},
            ],
        }],
        "text": {
            "format": {
                "type": "json_schema",
                "name": "living_room_risk_zones",
                "schema": schema,
                "strict": True,
            }
        },
    }
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(30.0)) as client:
            res = await client.post(
                "https://api.openai.com/v1/responses",
                headers={"Authorization": f"Bearer {openai_key}", "Content-Type": "application/json"},
                json=payload,
            )
            res.raise_for_status()
            raw = res.json()
    except Exception as exc:
        data = default_living_room_risk_zones()
        data["source"] = "default_template_openai_error"
        data["error"] = str(exc)[:240]
        _save_risk_zones(data)
        return {"ok": True, "used_ai": False, **data}

    text = raw.get("output_text")
    if not text:
        chunks = []
        for item in raw.get("output", []):
            for c in item.get("content", []):
                if c.get("type") in ("output_text", "text"):
                    chunks.append(c.get("text", ""))
        text = "".join(chunks)
    try:
        parsed = json.loads(text)
    except Exception:
        data = default_living_room_risk_zones()
        data["source"] = "default_template_parse_error"
        _save_risk_zones(data)
        return {"ok": True, "used_ai": False, **data}

    data = _sanitize_risk_zones(parsed, "openai_snapshot")
    if not data["zones"]:
        data = default_living_room_risk_zones()
        data["source"] = "default_template_empty_ai_result"
        return {"ok": True, "used_ai": False, **data}
    _save_risk_zones(data)
    return {"ok": True, "used_ai": True, **data}


# ── startup ───────────────────────────────────────────────────────────────────

@app.on_event("startup")
def startup():
    db.init_db()


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
