"""Contract tests for the SentiLife inference service (FastAPI).

Tests the inference-only API: /predict, /health, /metrics, /model/info, /model/reload.
No business logic, no OTA, no database.
"""

from fastapi.testclient import TestClient

from api.main import app

client = TestClient(app)


# ── /health ──────────────────────────────────────────────────────────────────

def test_health_returns_status_and_model_info():
    response = client.get("/health")

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "model_loaded" in data
    assert "model_name" in data
    assert "version" in data


# ── /predict ─────────────────────────────────────────────────────────────────

def test_predict_returns_503_or_422_without_valid_features():
    """If model is loaded, predict returns 422 (missing features).
    If no model, returns 503."""
    response = client.post("/predict", json={"features": {}})
    assert response.status_code in (503, 422)


def test_predict_rejects_invalid_body():
    response = client.post("/predict", json={"invalid": "payload"})
    assert response.status_code == 422


# ── /model/info ──────────────────────────────────────────────────────────────

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


# ── /model/reload ────────────────────────────────────────────────────────────

def test_model_reload_with_invalid_path_returns_404():
    response = client.post("/model/reload?path=nonexistent.pkl")
    assert response.status_code == 404


def test_model_reload_without_path_uses_default():
    """Reload with no path param uses the configured MODEL_PATH."""
    response = client.post("/model/reload")
    # Either 200 (model found at default path) or 404 (no model file in test env)
    assert response.status_code in (200, 404)


# ── /metrics ─────────────────────────────────────────────────────────────────

def test_metrics_returns_prometheus_format():
    response = client.get("/metrics")

    assert response.status_code == 200
    assert "text/plain" in response.headers["content-type"]
    assert "predictions_total" in response.text
    assert "prediction_latency_seconds" in response.text


# ── Route structure ──────────────────────────────────────────────────────────

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
    }
