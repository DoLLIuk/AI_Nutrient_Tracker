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
        return main.JSONResponse({"request_id": "sample"})

    monkeypatch.setattr(main, "forward", fake_forward)
    response = client.post(
        "/v0/ai/photo-food",
        headers=HEADERS,
        data={"locale": "en-US", "analysis_mode": "initial"},
        files={"image": ("food.jpg", b"abc", "image/jpeg")},
    )
    assert response.status_code == 200
    assert forwarded["api_key"] == "private-test-key"
    assert forwarded["files"]["image"][1] == b"abc"


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
