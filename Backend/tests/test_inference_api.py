"""Contract tests for the internal FastAPI inference service."""

from fastapi.testclient import TestClient

from api.main import app

client = TestClient(app)


def prediction_payload():
    return {
        "windowId": "window-001",
        "monitoredId": "monitored-001",
        "sampleRateHz": 50,
        "samples": {
            "accX": [0.1, 0.2],
            "accY": [0.1, 0.2],
            "accZ": [9.8, 9.7],
            "gyroX": [0.0, 0.1],
            "gyroY": [0.0, 0.1],
            "gyroZ": [0.0, 0.1],
        },
        "subjectFeatures": {
            "age": 78,
            "sex": "M",
            "weightKg": 78.5,
            "heightCm": 172,
        },
    }


def test_health_exposes_service_and_model_version():
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "healthy"
    assert response.json()["service"] == "sentilife-inference"
    assert response.json()["modelVersion"]


def test_predict_matches_frozen_contract():
    response = client.post("/predict", json=prediction_payload())

    assert response.status_code == 200
    assert set(response.json()) == {
        "fallDetected",
        "confidence",
        "modelVersion",
        "latencyMs",
    }
    assert response.json()["fallDetected"] is False
    assert 0 <= response.json()["confidence"] <= 1
    assert response.json()["latencyMs"] >= 0


def test_predict_rejects_sensor_series_with_different_lengths():
    payload = prediction_payload()
    payload["samples"]["gyroZ"] = [0.0]

    response = client.post("/predict", json=payload)

    assert response.status_code == 422


def test_model_operations_are_available():
    info_response = client.get("/model/info")
    reload_response = client.post("/model/reload")

    assert info_response.status_code == 200
    assert set(info_response.json()) == {
        "version",
        "algorithm",
        "trainedAt",
        "metrics",
    }
    assert reload_response.status_code == 200
    assert reload_response.json()["modelVersion"] == info_response.json()["version"]


def test_metrics_are_exposed_in_prometheus_format():
    client.get("/health")

    response = client.get("/metrics")

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/plain")
    assert "sentilife_inference_http_requests_total" in response.text
    assert "sentilife_inference_prediction_duration_seconds" in response.text


def test_only_inference_and_deprecated_ota_application_routes_exist():
    application_paths = {
        route.path
        for route in app.routes
        if getattr(route, "path", "").startswith("/")
        and route.path not in {"/openapi.json", "/docs", "/docs/oauth2-redirect", "/redoc"}
    }

    assert application_paths == {
        "/predict",
        "/health",
        "/metrics",
        "/model/info",
        "/model/reload",
        "/app/latest-version",
        "/app/register-version",
    }
    ota_routes = [
        route
        for route in app.routes
        if getattr(route, "path", "").startswith("/app/")
    ]
    assert ota_routes
    assert all(route.deprecated for route in ota_routes)
