"""Contract tests for the SentiLife inference service (FastAPI).

Tests the inference-only API: /predict, /health, /metrics, /model/info,
/model/reload, /model/registry.
No business logic, no OTA, no database.
"""

import pytest
from fastapi.testclient import TestClient

from api.main import app

client = TestClient(app)

N_SAMPLES = 125


# ── /health ───────────────────────────────────────────────────────────────────

def test_health_returns_status_and_model_info():
    response = client.get("/health")

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "model_loaded" in data
    assert "model_name" in data
    assert "version" in data


# ── /predict ──────────────────────────────────────────────────────────────────

def test_predict_returns_503_or_422_without_valid_samples():
    """If model is loaded, predict returns 422 (missing samples).
    If no model, returns 503."""
    response = client.post("/predict", json={"windowId": "w1", "monitoredId": "m1", "sampleRateHz": 50, "samples": {}})
    assert response.status_code in (503, 422)


def test_predict_rejects_invalid_body():
    response = client.post("/predict", json={"invalid": "payload"})
    assert response.status_code == 422


def _make_samples(n: int = N_SAMPLES, spike: bool = False) -> dict:
    samples = {}
    for sig in ["accX", "accY", "accZ", "gyroX", "gyroY", "gyroZ"]:
        arr = []
        for i in range(n):
            if sig.startswith("acc"):
                if spike and i > 60:
                    arr.append(30.0 if sig == "accY" else 8.0)
                else:
                    arr.append(9.8 if sig == "accY" else 0.1)
            else:
                arr.append(250.0 if spike and i > 60 else 2.0)
        samples[sig] = arr
    return samples


def test_predict_rejects_wrong_sample_count():
    health = client.get("/health").json()
    if not health.get("model_loaded"):
        pytest.skip("No model loaded in test env")

    samples = _make_samples()
    samples["accX"] = samples["accX"][:10]

    response = client.post(
        "/predict",
        json={
            "windowId": "00000000-0000-0000-0000-000000000010",
            "monitoredId": "00000000-0000-0000-0000-000000000011",
            "sampleRateHz": 50,
            "samples": samples,
        },
    )
    assert response.status_code == 422
    assert "125 samples" in response.json()["detail"]


def test_predict_rejects_missing_signals():
    health = client.get("/health").json()
    if not health.get("model_loaded"):
        pytest.skip("No model loaded in test env")

    response = client.post(
        "/predict",
        json={
            "windowId": "00000000-0000-0000-0000-000000000012",
            "monitoredId": "00000000-0000-0000-0000-000000000013",
            "sampleRateHz": 50,
            "samples": {"accX": [0.1] * N_SAMPLES},
        },
    )
    assert response.status_code == 422
    assert "Missing required signals" in response.json()["detail"]


def test_predict_spike_window_contract():
    """Spike windows should return a valid §6.8 response when model is loaded."""
    health = client.get("/health").json()
    if not health.get("model_loaded"):
        pytest.skip("No model loaded in test env")

    payload = {
        "windowId": "00000000-0000-0000-0000-000000000014",
        "monitoredId": "00000000-0000-0000-0000-000000000015",
        "sampleRateHz": 50,
        "samples": _make_samples(spike=True),
        "subjectFeatures": {"age": 78, "sex": "F", "weightKg": 65, "heightCm": 160},
    }
    response = client.post("/predict", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data["fallDetected"], bool)
    assert 0.0 <= data["confidence"] <= 1.0
    assert data["latencyMs"] >= 0


def test_predict_returns_spec_response_when_model_loaded():
    """Contract §6.8: fallDetected, confidence, modelVersion, latencyMs."""
    health = client.get("/health").json()
    if not health.get("model_loaded"):
        pytest.skip("No model loaded in test env")

    payload = {
        "windowId": "00000000-0000-0000-0000-000000000001",
        "monitoredId": "00000000-0000-0000-0000-000000000002",
        "sampleRateHz": 50,
        "samples": _make_samples(spike=False),
        "subjectFeatures": {},
    }
    response = client.post("/predict", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert set(data.keys()) == {"fallDetected", "confidence", "modelVersion", "latencyMs"}
    assert isinstance(data["fallDetected"], bool)
    assert 0.0 <= data["confidence"] <= 1.0
    assert data["modelVersion"]
    assert data["latencyMs"] >= 0


# ── /model/info ───────────────────────────────────────────────────────────────

def test_model_info_returns_expected_fields():
    response = client.get("/model/info")

    assert response.status_code == 200
    data = response.json()
    assert set(data.keys()) == {
        "model_name",
        "version",
        "threshold",
        "features_count",
        "numeric_features",
        "categorical_features",
        "loaded_at",
        "file_path",
    }


# ── /model/reload ─────────────────────────────────────────────────────────────

def test_model_reload_with_invalid_path_returns_404():
    response = client.post("/model/reload?path=nonexistent.pkl")
    assert response.status_code == 404


def test_model_reload_without_path_uses_default():
    """Reload with no path param uses the configured MODEL_PATH."""
    response = client.post("/model/reload")
    assert response.status_code in (200, 404)


# ── /model/registry (SL-54 / T4.3) ───────────────────────────────────────────

def test_model_registry_returns_expected_structure():
    response = client.get("/model/registry")
    # 200 if registry file exists, 404 if not present in test env
    assert response.status_code in (200, 404)
    if response.status_code == 200:
        data = response.json()
        assert "active" in data
        assert "models" in data
        assert isinstance(data["models"], list)


# ── /metrics ──────────────────────────────────────────────────────────────────

def test_metrics_returns_prometheus_format():
    response = client.get("/metrics")

    assert response.status_code == 200
    assert "text/plain" in response.headers["content-type"]
    assert "predictions_total" in response.text
    assert "prediction_latency_seconds" in response.text


# ── Route structure ───────────────────────────────────────────────────────────

def test_only_inference_routes_exist():
    """Verifies only inference endpoints exist — no OTA, no business logic."""
    application_paths = {
        route.path
        for route in app.routes
        if getattr(route, "path", "").startswith("/")
        and route.path not in {"/openapi.json", "/docs", "/docs/oauth2-redirect", "/redoc"}
    }

    assert application_paths == {
        "/",
        "/health",
        "/predict",
        "/metrics",
        "/model/info",
        "/model/reload",
        "/model/registry",
    }
