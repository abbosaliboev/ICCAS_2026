"""SolAPI SMS notification helper."""

import hashlib
import hmac
import logging
import os
import uuid
from datetime import datetime, timezone

import httpx

logger = logging.getLogger("mobicare.sms")

SOLAPI_API_KEY = os.environ.get("SOLAPI_API_KEY", "").strip()
SOLAPI_API_SECRET = os.environ.get("SOLAPI_API_SECRET", "").strip()
SOLAPI_SENDER = "".join(
    ch for ch in os.environ.get("SOLAPI_SENDER_PHONE", "").strip() if ch.isdigit()
)
SOLAPI_ENDPOINT = "https://api.solapi.com/messages/v4/send"


def sms_configured() -> bool:
    return bool(SOLAPI_API_KEY and SOLAPI_API_SECRET and SOLAPI_SENDER)


def _solapi_auth_header() -> str:
    date = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    salt = uuid.uuid4().hex
    signature = hmac.new(
        SOLAPI_API_SECRET.encode("utf-8"),
        (date + salt).encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    return (
        "HMAC-SHA256 "
        f"apiKey={SOLAPI_API_KEY}, date={date}, salt={salt}, signature={signature}"
    )


async def send_sms(to: str, message: str) -> dict:
    """Send SMS via SolAPI, or dry-run when credentials are not configured."""
    to_clean = "".join(ch for ch in (to or "") if ch.isdigit())
    if not to_clean:
        return {"ok": False, "mode": "error", "detail": "Recipient phone number is missing."}

    if not sms_configured():
        detail = f"[DRY-RUN] SMS provider not configured -> {to_clean}: {message}"
        logger.info(detail)
        return {"ok": True, "mode": "simulated", "detail": detail}

    payload = {"message": {"to": to_clean, "from": SOLAPI_SENDER, "text": message}}
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                SOLAPI_ENDPOINT,
                headers={
                    "Authorization": _solapi_auth_header(),
                    "Content-Type": "application/json",
                },
                json=payload,
            )
        if resp.status_code >= 400:
            return {
                "ok": False,
                "mode": "error",
                "detail": f"SolAPI 오류 {resp.status_code}: {resp.text}",
            }
        return {"ok": True, "mode": "live", "detail": resp.json()}
    except Exception as exc:
        return {"ok": False, "mode": "error", "detail": f"SMS 발송 실패: {exc}"}
