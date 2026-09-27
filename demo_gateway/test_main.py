import os

os.environ["DEMO_ALLOWED_ORIGINS"] = "https://dolliuk.github.io"
os.environ["PHOTO_FOOD_API_BASE_URL"] = "https://upstream.example"
os.environ["PHOTO_FOOD_API_KEY"] = "private-test-key"
os.environ["DEMO_HASH_SALT"] = "private-test-salt"

from fastapi.testclient import TestClient

import main


client = TestClient(main.app)
VISITOR = "a" * 32
HEADERS = {"Origin": "https://dolliuk.github.io", "X-Demo-Visitor": VISITOR}


def test_non_demo_origin_is_rejected_before_quota(monkeypatch):
    monkeypatch.setattr(main, "reserve_quota", lambda *args: (_ for _ in ()).throw(AssertionError()))
    response = client.post(
        "/v0/ai/photo-food",
        headers={"Origin": "https://other.example", "X-Demo-Visitor": VISITOR},
        files={"image": ("food.jpg", b"abc", "image/jpeg")},
    )
    assert response.status_code == 403


def test_daily_cap_stops_upstream_call(monkeypatch):
    monkeypatch.setattr(main, "reserve_quota", lambda *args: False)

    async def no_forward(*args, **kwargs):
        raise AssertionError("upstream must not be called")

    monkeypatch.setattr(main, "forward", no_forward)
    response = client.post(
        "/v0/ai/photo-food",
        headers=HEADERS,
        files={"image": ("food.jpg", b"abc", "image/jpeg")},
    )
    assert response.status_code == 429
    assert response.json()["error"]["code"] == "RATE_LIMITED"


def test_valid_analysis_forwards_only_server_key(monkeypatch):
    monkeypatch.setattr(main, "reserve_quota", lambda *args: True)
    forwarded = {}

    async def fake_forward(url, api_key, trace_id, **kwargs):
        forwarded.update(url=url, api_key=api_key, fields=kwargs["data"], files=kwargs["files"])
        forwarded["key"] = kwargs.get("operation_key")
        return main.JSONResponse({"request_id": "sample"})

    monkeypatch.setattr(main, "forward", fake_forward)
    response = client.post(
        "/v0/ai/photo-food",
        headers={**HEADERS, "Idempotency-Key": "saved_scan_1234567890"},
        data={"locale": "en-US", "analysis_mode": "initial"},
        files={"image": ("food.jpg", b"abc", "image/jpeg")},
    )
    assert response.status_code == 200
    assert forwarded["api_key"] == "private-test-key"
    assert forwarded["files"]["image"][1] == b"abc"
    assert forwarded["key"] == "saved_scan_1234567890"


def test_recovery_preflight_allows_stable_key():
    response = client.options("/v0/ai/photo-food", headers={
        "Origin": HEADERS["Origin"], "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "idempotency-key,x-demo-visitor",
    })
    assert response.status_code == 200


def test_capability_proxy_does_not_claim_support_from_old_backend(monkeypatch):
    class UpstreamClient:
        def __init__(self, **kwargs): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *args): pass
        async def get(self, url):
            return main.httpx.Response(200, json={"ok": True})
    monkeypatch.setattr(main.httpx, "AsyncClient", UpstreamClient)
    response = client.get("/v0/health", headers=HEADERS)
    assert response.status_code == 200
    assert response.json()["durable_operations"] is False


def test_invalid_confirmation_does_not_consume_quota(monkeypatch):
    monkeypatch.setattr(main, "reserve_quota", lambda *args: (_ for _ in ()).throw(AssertionError()))
    response = client.post(
        "/v0/ai/photo-food/confirm-portion",
        headers=HEADERS,
        json={"request_id": "abc", "confirm_mode": "manual", "portion_g": 3000},
    )
    assert response.status_code == 400


def test_missing_visitor_is_rejected(monkeypatch):
    monkeypatch.setattr(main, "reserve_quota", lambda *args: (_ for _ in ()).throw(AssertionError()))
    response = client.post(
        "/v0/ai/photo-food",
        headers={"Origin": "https://dolliuk.github.io"},
        files={"image": ("food.jpg", b"abc", "image/jpeg")},
    )
    assert response.status_code == 400


def test_onboarding_event_is_admitted_without_profile_data(monkeypatch):
    captured = {}

    def reserve(*args):
        captured["action"], captured["visitor"], captured["trace"], captured["name"], captured["step"] = args
        return True

    monkeypatch.setattr(main, "reserve_quota", reserve)
    response = client.post(
        "/v0/demo/event",
        headers=HEADERS,
        json={"name": "onboarding_step_viewed", "step": 2, "weight_kg": 65},
    )
    assert response.status_code == 200
    assert captured["action"] == "event"
    assert captured["name"] == "onboarding_step_viewed"
    assert captured["step"] == 2


def test_unknown_event_is_rejected_before_firestore(monkeypatch):
    monkeypatch.setattr(main, "reserve_quota", lambda *args: (_ for _ in ()).throw(AssertionError()))
    response = client.post(
        "/v0/demo/event",
        headers=HEADERS,
        json={"name": "profile_weight_changed", "weight_kg": 65},
    )
    assert response.status_code == 400


def test_firestore_reservation_enforces_visitor_and_shared_caps(monkeypatch):
    documents = {}

    class Snapshot:
        def __init__(self, value):
            self.value = value

        def to_dict(self):
            return self.value

    class Reference:
        def __init__(self, path):
            self.path = path

        def get(self, transaction=None):
            return Snapshot(documents.get(self.path))

    class Collection:
        def __init__(self, name):
            self.name = name

        def document(self, doc_id):
            return Reference(f"{self.name}/{doc_id}")

    class Transaction:
        def set(self, ref, value, merge=False):
            documents[ref.path] = {**documents.get(ref.path, {}), **value}

    class Client:
        def collection(self, name):
            return Collection(name)

        def transaction(self):
            return Transaction()

    monkeypatch.setattr(main.firestore, "Client", Client)
    monkeypatch.setattr(main.firestore, "transactional", lambda fn: fn)
    monkeypatch.setattr(main, "ANALYSES_PER_VISITOR", 2)
    monkeypatch.setattr(main, "ANALYSES_TOTAL", 3)

    assert main.reserve_quota("analysis", "visitor_one", "trace_1")
    assert main.reserve_quota("analysis", "visitor_one", "trace_2")
    assert not main.reserve_quota("analysis", "visitor_one", "trace_3")
    assert main.reserve_quota("analysis", "visitor_two", "trace_4")
    assert not main.reserve_quota("analysis", "visitor_three", "trace_5")
    assert len([key for key in documents if key.startswith("demo_events/")]) == 3
