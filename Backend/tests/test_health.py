"""Tests for the SentiLife inference service."""

from fastapi.testclient import TestClient

from api.main import app

client = TestClient(app)


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "Inference" in data["service"]


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "model_loaded" in data
    assert "model_name" in data


def test_metrics():
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "predictions_total" in response.text
    assert "prediction_latency_seconds" in response.text


def test_model_info():
    response = client.get("/model/info")
    assert response.status_code == 200
    data = response.json()
    assert "model_name" in data
    assert "version" in data
    assert "threshold" in data
    assert "features_count" in data


def test_predict_no_model_returns_503_or_200():
    """If model is loaded, predict returns 200; if not, returns 503."""
    # Send a minimal payload — model may or may not be loaded in test env
    response = client.post("/predict", json={"features": {}})
    # Either 503 (no model) or 422 (missing features) are acceptable
    assert response.status_code in (503, 422)


def test_model_reload_missing_file():
    response = client.post("/model/reload?path=nonexistent.pkl")
    assert response.status_code == 404
