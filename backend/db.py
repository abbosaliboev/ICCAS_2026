"""SQLite database layer for MobiCare backend."""

import sqlite3, os, uuid
from datetime import datetime
from pathlib import Path

DB_PATH = Path(__file__).parent / "mobicare.db"


def get_conn():
    conn = sqlite3.connect(str(DB_PATH), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db():
    conn = get_conn()
    c = conn.cursor()

    c.executescript("""
    CREATE TABLE IF NOT EXISTS users (
        id          TEXT PRIMARY KEY,
        username    TEXT UNIQUE NOT NULL,
        password    TEXT NOT NULL,
        role        TEXT NOT NULL DEFAULT 'user',
        display_name TEXT,
        age         INTEGER,
        phone       TEXT,
        address     TEXT,
        guardian_id TEXT,
        created_at  TEXT
    );

    CREATE TABLE IF NOT EXISTS devices (
        id          TEXT PRIMARY KEY,
        token       TEXT UNIQUE NOT NULL,
        name        TEXT,
        location    TEXT,
        stream_url  TEXT,
        user_id     TEXT,
        last_seen   TEXT,
        created_at  TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS fall_events (
        id              TEXT PRIMARY KEY,
        device_id       TEXT,
        user_id         TEXT,
        timestamp       TEXT,
        category        TEXT DEFAULT 'severe',
        direction       TEXT,
        estimated_injury TEXT,
        video_path      TEXT,
        thumbnail_path  TEXT,
        is_acknowledged INTEGER DEFAULT 0,
        created_at      TEXT,
        FOREIGN KEY (device_id) REFERENCES devices(id)
    );

    CREATE TABLE IF NOT EXISTS sessions (
        token       TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL,
        created_at  TEXT
    );
    """)

    # demo users
    now = datetime.now().isoformat()
    for row in [
        (str(uuid.uuid4()), "user1",     "1234", "user",     "김OO", 70, "010-1234-5678", "청주시 서원구",    None),
        (str(uuid.uuid4()), "guardian1", "1234", "guardian", "이OO", 40, "010-9876-5432", "청주시 흥덕구",    None),
    ]:
        try:
            c.execute("""
                INSERT INTO users (id,username,password,role,display_name,age,phone,address,guardian_id,created_at)
                VALUES (?,?,?,?,?,?,?,?,?,?)
            """, (*row, now))
        except sqlite3.IntegrityError:
            pass

    # demo device — link to user1
    user1 = conn.execute("SELECT id FROM users WHERE username='user1'").fetchone()
    user1_id = user1["id"] if user1 else None
    try:
        c.execute("""
            INSERT INTO devices (id,token,name,location,stream_url,user_id,last_seen,created_at)
            VALUES (?,?,?,?,?,?,?,?)
        """, (str(uuid.uuid4()), "edge-device-001", "거실 카메라", "거실", "", user1_id, now, now))
    except sqlite3.IntegrityError:
        # update existing device's user_id if null
        if user1_id:
            conn.execute("UPDATE devices SET user_id=? WHERE token='edge-device-001' AND user_id IS NULL", (user1_id,))
        pass

    conn.commit()
    conn.close()


# ── user helpers ──────────────────────────────────────────────────────────────

def get_user_by_username(username: str):
    conn = get_conn()
    row = conn.execute("SELECT * FROM users WHERE username=?", (username,)).fetchone()
    conn.close()
    return dict(row) if row else None


def get_user_by_id(user_id: str):
    conn = get_conn()
    row = conn.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def create_user(username, password, role, display_name, age, phone, address):
    uid = str(uuid.uuid4())
    now = datetime.now().isoformat()
    conn = get_conn()
    try:
        conn.execute("""
            INSERT INTO users (id,username,password,role,display_name,age,phone,address,guardian_id,created_at)
            VALUES (?,?,?,?,?,?,?,?,NULL,?)
        """, (uid, username, password, role, display_name, age, phone, address, now))
        conn.commit()
        return uid
    except sqlite3.IntegrityError:
        return None
    finally:
        conn.close()


def link_guardian(user_id: str, guardian_id: str):
    conn = get_conn()
    conn.execute("UPDATE users SET guardian_id=? WHERE id=?", (guardian_id, user_id))
    conn.commit()
    conn.close()


# ── session helpers ───────────────────────────────────────────────────────────

def create_session(user_id: str) -> str:
    token = str(uuid.uuid4())
    now   = datetime.now().isoformat()
    conn  = get_conn()
    conn.execute("INSERT INTO sessions (token,user_id,created_at) VALUES (?,?,?)", (token, user_id, now))
    conn.commit()
    conn.close()
    return token


def get_session(token: str):
    conn = get_conn()
    row  = conn.execute("SELECT * FROM sessions WHERE token=?", (token,)).fetchone()
    conn.close()
    return dict(row) if row else None


def delete_session(token: str):
    conn = get_conn()
    conn.execute("DELETE FROM sessions WHERE token=?", (token,))
    conn.commit()
    conn.close()


# ── device helpers ────────────────────────────────────────────────────────────

def get_device_by_token(token: str):
    conn = get_conn()
    row  = conn.execute("SELECT * FROM devices WHERE token=?", (token,)).fetchone()
    conn.close()
    return dict(row) if row else None


def get_devices_for_user(user_id: str):
    conn = get_conn()
    rows = conn.execute("SELECT * FROM devices WHERE user_id=?", (user_id,)).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def update_device_stream_url(device_id: str, stream_url: str):
    conn = get_conn()
    conn.execute("UPDATE devices SET stream_url=?, last_seen=? WHERE id=?",
                 (stream_url, datetime.now().isoformat(), device_id))
    conn.commit()
    conn.close()


def assign_device_to_user(device_token: str, user_id: str, stream_url: str = ""):
    conn = get_conn()
    now  = datetime.now().isoformat()
    dev  = conn.execute("SELECT * FROM devices WHERE token=?", (device_token,)).fetchone()
    if dev:
        conn.execute("UPDATE devices SET user_id=?, stream_url=?, last_seen=? WHERE token=?",
                     (user_id, stream_url, now, device_token))
    else:
        conn.execute("""
            INSERT INTO devices (id,token,name,location,stream_url,user_id,last_seen,created_at)
            VALUES (?,?,?,?,?,?,?,?)
        """, (str(uuid.uuid4()), device_token, "카메라", "거실", stream_url, user_id, now, now))
    conn.commit()
    conn.close()


# ── fall event helpers ────────────────────────────────────────────────────────

def create_fall_event(event_id, device_id, user_id, timestamp, category, clip_path=""):
    now = datetime.now().isoformat()
    conn = get_conn()
    conn.execute("""
        INSERT OR IGNORE INTO fall_events
          (id, device_id, user_id, timestamp, category, video_path, is_acknowledged, created_at)
        VALUES (?,?,?,?,?,?,0,?)
    """, (event_id, device_id, user_id, timestamp, category, clip_path, now))
    conn.commit()
    conn.close()


def get_fall_events(user_id: str = None, limit: int = 50):
    conn  = get_conn()
    if user_id:
        rows = conn.execute(
            "SELECT * FROM fall_events WHERE user_id=? ORDER BY created_at DESC LIMIT ?",
            (user_id, limit)
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT * FROM fall_events ORDER BY created_at DESC LIMIT ?", (limit,)
        ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_fall_event(event_id: str):
    conn = get_conn()
    row  = conn.execute("SELECT * FROM fall_events WHERE id=?", (event_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def update_fall_event_video(event_id: str, video_path: str):
    conn = get_conn()
    conn.execute("UPDATE fall_events SET video_path=? WHERE id=?", (video_path, event_id))
    conn.commit()
    conn.close()


def delete_fall_event(event_id: str):
    conn = get_conn()
    conn.execute("DELETE FROM fall_events WHERE id=?", (event_id,))
    conn.commit()
    conn.close()


def update_fall_event_thumbnail(event_id: str, thumbnail_path: str):
    conn = get_conn()
    conn.execute("UPDATE fall_events SET thumbnail_path=? WHERE id=?", (thumbnail_path, event_id))
    conn.commit()
    conn.close()


def acknowledge_fall_event(event_id: str):
    conn = get_conn()
    conn.execute("UPDATE fall_events SET is_acknowledged=1 WHERE id=?", (event_id,))
    conn.commit()
    conn.close()


def get_guardian_events(guardian_id: str, limit: int = 50):
    """Fall events for all users who have this guardian."""
    conn = get_conn()
    rows = conn.execute("""
        SELECT fe.* FROM fall_events fe
        JOIN users u ON fe.user_id = u.id
        WHERE u.guardian_id = ?
        ORDER BY fe.created_at DESC LIMIT ?
    """, (guardian_id, limit)).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_monitored_users(guardian_id: str):
    conn = get_conn()
    rows = conn.execute(
        "SELECT id,username,display_name,age,phone,address FROM users WHERE guardian_id=?",
        (guardian_id,)
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]
