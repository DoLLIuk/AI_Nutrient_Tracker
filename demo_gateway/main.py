"""Public, budgeted bridge from the static web demo to the private AI API."""

import hashlib
import json
import logging
import os
import re
import secrets
from datetime import datetime, timezone

import httpx
from fastapi import FastAPI, File, Form, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from google.cloud import firestore


MAX_IMAGE_BYTES = 8 * 1024 * 1024
ANALYSES_PER_VISITOR = 3
ANALYSES_TOTAL = 50
CONFIRMATIONS_PER_VISITOR = 9
CONFIRMATIONS_TOTAL = 150
VISITOR_PATTERN = re.compile(r"^[a-f0-9]{32}$")
IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}

ALLOWED_ORIGINS = [
    item.strip().rstrip("/")
    for item in os.environ.get("DEMO_ALLOWED_ORIGINS", "").split(",")
    if item.strip()
]

app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["POST"],
    allow_headers=["Content-Type", "X-Demo-Visitor", "X-Client-Trace-ID", "X-Client-Diagnostics"],
)


@app.middleware("http")
async def reject_untrusted_requests(request: Request, call_next):
    if request.method == "POST":
        if not origin_allowed(request):
            return error(403, "FORBIDDEN", "This demo origin is not allowed")
        length = request.headers.get("content-length")
        if length and (not length.isdigit() or int(length) > MAX_IMAGE_BYTES + 1024 * 1024):
            return error(413, "IMAGE_TOO_LARGE", "Request is too large")
    return await call_next(request)


def error(status: int, code: str, message: str) -> JSONResponse:
    return JSONResponse(status_code=status, content={"error": {"code": code, "message": message}})


def settings():
    upstream = os.environ.get("PHOTO_FOOD_API_BASE_URL", "").rstrip("/")
    api_key = os.environ.get("PHOTO_FOOD_API_KEY", "")
    salt = os.environ.get("DEMO_HASH_SALT", "")
    if not upstream.startswith("https://") or not api_key or not salt or not ALLOWED_ORIGINS:
        raise RuntimeError("Demo gateway needs HTTPS upstream, API key, hash salt and allowed origins")
    return upstream, api_key, salt


def request_identity(request: Request, salt: str):
    # This ID helps honest visitors retain a fair quota. It is not authentication;
    # the shared Firestore cap limits cost even when a visitor changes IDs.
    visitor = request.headers.get("X-Demo-Visitor", "")
    if not VISITOR_PATTERN.fullmatch(visitor):
        return None
    digest = hashlib.sha256((salt + visitor).encode()).hexdigest()
    return digest


def origin_allowed(request: Request) -> bool:
    # CORS alone does not stop a non-browser client from calling the endpoint.
    # The global Firestore cap remains the actual cost boundary.
    return request.headers.get("origin", "").rstrip("/") in ALLOWED_ORIGINS


def reserve_quota(action: str, visitor_hash: str, trace_id: str) -> bool:
    client = firestore.Client()
    day = datetime.now(timezone.utc).date().isoformat()
    global_ref = client.collection("demo_daily").document(day)
    visitor_ref = client.collection("demo_daily_visitors").document(f"{day}_{visitor_hash}")
    event_ref = client.collection("demo_events").document(secrets.token_hex(12))
    visitor_limit, total_limit = (
        (ANALYSES_PER_VISITOR, ANALYSES_TOTAL)
        if action == "analysis"
        else (CONFIRMATIONS_PER_VISITOR, CONFIRMATIONS_TOTAL)
    )

    @firestore.transactional
    def reserve(transaction):
        global_snapshot = global_ref.get(transaction=transaction)
        visitor_snapshot = visitor_ref.get(transaction=transaction)
        global_count = (global_snapshot.to_dict() or {}).get(action, 0)
        visitor_count = (visitor_snapshot.to_dict() or {}).get(action, 0)
        if global_count >= total_limit or visitor_count >= visitor_limit:
            return False
        transaction.set(global_ref, {action: global_count + 1}, merge=True)
        transaction.set(visitor_ref, {action: visitor_count + 1}, merge=True)
        transaction.set(event_ref, {
            "time": firestore.SERVER_TIMESTAMP,
            "action": action,
            "visitor_hash": visitor_hash,
            "trace_id": trace_id,
            "outcome": "admitted",
        })
        return True

    return reserve(client.transaction())


async def admission(request: Request, action: str):
    if not origin_allowed(request):
        return None, error(403, "FORBIDDEN", "This demo origin is not allowed")
    try:
        upstream, api_key, salt = settings()
    except RuntimeError:
        logging.exception("Demo gateway configuration is incomplete")
        return None, error(503, "DEMO_UNAVAILABLE", "The demo is temporarily unavailable")
    visitor_hash = request_identity(request, salt)
    if visitor_hash is None:
        return None, error(400, "INVALID_VISITOR", "Refresh the demo and try again")
    trace_id = request.headers.get("X-Client-Trace-ID", "")[:100]
    if not re.fullmatch(r"[a-zA-Z0-9_-]{1,100}", trace_id):
        trace_id = secrets.token_hex(12)
    try:
        allowed = reserve_quota(action, visitor_hash, trace_id)
    except Exception:
        logging.exception("Firestore quota check failed")
        return None, error(503, "DEMO_UNAVAILABLE", "The demo is temporarily unavailable")
    if not allowed:
        logging.info(json.dumps({"action": action, "outcome": "limited", "trace_id": trace_id}))
        return None, error(429, "RATE_LIMITED", "The daily demo limit has been reached. Try again tomorrow.")
    return (upstream, api_key, trace_id), None


async def forward(url: str, api_key: str, trace_id: str, *, data=None, files=None, payload=None):
    try:
        async with httpx.AsyncClient(timeout=35) as client:
            response = await client.post(
                url,
                headers={"X-API-Key": api_key, "X-Client-Trace-ID": trace_id},
                data=data,
                files=files,
                json=payload,
            )
        body = response.json()
        if not isinstance(body, dict):
            raise ValueError("Non-object upstream response")
        logging.info(json.dumps({"outcome": "upstream_response", "status": response.status_code, "trace_id": trace_id}))
        headers = {}
        if response.headers.get("X-Request-ID"):
            headers["X-Request-ID"] = response.headers["X-Request-ID"]
        return JSONResponse(status_code=response.status_code, content=body, headers=headers)
    except (httpx.HTTPError, ValueError):
        logging.exception("Upstream analysis failed")
        return error(502, "PROVIDER_ERROR", "Analysis is temporarily unavailable")


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/v0/ai/photo-food")
async def analyze(
    request: Request,
    image: UploadFile = File(...),
    locale: str = Form("en-US"),
    analysis_mode: str = Form("initial"),
    dish_category: str | None = Form(None),
    ingredient_hints: str | None = Form(None),
    meal_time: str | None = Form(None),
):
    if image.content_type not in IMAGE_TYPES:
        return error(415, "UNSUPPORTED_IMAGE_TYPE", "Use a JPG, PNG, or WEBP image")
    content = await image.read(MAX_IMAGE_BYTES + 1)
    if not content or len(content) > MAX_IMAGE_BYTES:
        return error(413, "IMAGE_TOO_LARGE", "Image must be 1 byte to 8 MB")
    if analysis_mode not in {"initial", "clarified"}:
        return error(400, "VALIDATION_ERROR", "Invalid analysis mode")
    upstream_info, rejection = await admission(request, "analysis")
    if rejection is not None:
        return rejection
    upstream, api_key, trace_id = upstream_info
    fields = {"locale": locale[:20], "analysis_mode": analysis_mode}
    if dish_category:
        fields["dish_category"] = dish_category[:40]
    if ingredient_hints:
        fields["ingredient_hints"] = ingredient_hints[:1000]
    if meal_time:
        fields["meal_time"] = meal_time[:40]
    return await forward(
        f"{upstream}/v0/ai/photo-food", api_key, trace_id,
        data=fields, files={"image": (image.filename or "meal.jpg", content, image.content_type)},
    )


@app.post("/v0/ai/photo-food/confirm-portion")
async def confirm_portion(request: Request):
    body = await request.body()
    if len(body) > 4096:
        return error(413, "VALIDATION_ERROR", "Request is too large")
    try:
        payload = json.loads(body)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return error(400, "VALIDATION_ERROR", "Invalid JSON")
    if not isinstance(payload, dict) or not isinstance(payload.get("request_id"), str):
        return error(400, "VALIDATION_ERROR", "Request ID is required")
    if payload.get("confirm_mode") not in {"manual", "use_ai_estimate"}:
        return error(400, "VALIDATION_ERROR", "Invalid confirmation mode")
    if len(payload["request_id"]) > 200:
        return error(400, "VALIDATION_ERROR", "Invalid request ID")
    if payload["confirm_mode"] == "manual":
        grams = payload.get("portion_g")
        if isinstance(grams, bool) or not isinstance(grams, (int, float)) or not 1 <= grams <= 2000:
            return error(400, "PORTION_OUT_OF_RANGE", "Portion must be 1 to 2000 g")
    upstream_info, rejection = await admission(request, "confirmation")
    if rejection is not None:
        return rejection
    upstream, api_key, trace_id = upstream_info
    safe_payload = {"request_id": payload["request_id"], "confirm_mode": payload["confirm_mode"]}
    if payload["confirm_mode"] == "manual":
        safe_payload["portion_g"] = grams
    return await forward(
        f"{upstream}/v0/ai/photo-food/confirm-portion", api_key, trace_id,
        payload=safe_payload,
    )
