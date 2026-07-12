"""SentiLife internal inference service.

Business APIs belong to the Spring Boot backend. OTA endpoints remain here only
as a deprecated compatibility bridge until their postponed migration.
"""

from __future__ import annotations

from time import perf_counter
from typing import Annotated, Literal

import uvicorn
from fastapi import FastAPI, HTTPException, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from pydantic import BaseModel, Field, model_validator

from api import db as pg
from api.inference import model as ml_model

app = FastAPI(
    title="SentiLife Inference Service",
    description="Internal service for fall-detection model inference.",
    version="0.2.0",
)

REQUESTS = Counter(
    "sentilife_inference_http_requests_total",
    "HTTP requests handled by the inference service.",
    ("method", "path", "status"),
)
REQUEST_LATENCY = Histogram(
    "sentilife_inference_http_request_duration_seconds",
    "HTTP request latency by endpoint.",
    ("method", "path"),
)
PREDICTION_LATENCY = Histogram(
    "sentilife_inference_prediction_duration_seconds",
    "Time spent computing a prediction.",
)


@app.middleware("http")
async def observe_requests(request, call_next):
    path = request.url.path
    started_at = perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        REQUESTS.labels(request.method, path, str(status)).inc()
        REQUEST_LATENCY.labels(request.method, path).observe(
            perf_counter() - started_at
        )


class AppVersion(BaseModel):
    """Deprecated OTA contract retained until its Java migration."""

    version_code: int
    version_name: str
    apk_url: str
    release_notes: str | None = None
    min_supported_version_code: int | None = None


class RegisterVersionRequest(AppVersion):
    pass


SampleSeries = Annotated[list[float], Field(min_length=1)]


class SensorSamples(BaseModel):
    accX: SampleSeries
    accY: SampleSeries
    accZ: SampleSeries
    gyroX: SampleSeries
    gyroY: SampleSeries
    gyroZ: SampleSeries

    @model_validator(mode="after")
    def validate_series_length(self):
        lengths = {len(series) for series in self.__dict__.values()}
        if len(lengths) != 1:
            raise ValueError("all sensor series must contain the same number of samples")
        return self


class SubjectFeatures(BaseModel):
    age: int = Field(ge=0, le=130)
    sex: Literal["M", "F", "OTHER"]
    weightKg: float = Field(gt=0)
    heightCm: float = Field(gt=0)


class PredictionRequest(BaseModel):
    windowId: str = Field(min_length=1)
    monitoredId: str = Field(min_length=1)
    sampleRateHz: float = Field(gt=0)
    samples: SensorSamples
    subjectFeatures: SubjectFeatures


class PredictionResponse(BaseModel):
    fallDetected: bool
    confidence: float = Field(ge=0, le=1)
    modelVersion: str
    latencyMs: float = Field(ge=0)


class ModelInfo(BaseModel):
    version: str
    algorithm: str
    trainedAt: str | None
    metrics: dict[str, float]


class ReloadResponse(BaseModel):
    status: Literal["reloaded", "unchanged"]
    modelVersion: str
    detail: str


class RegistryModel(BaseModel):
    id: str
    algorithm: str
    status: str
    metrics: dict[str, float]
    trainedAt: str | None = None


class RegistryResponse(BaseModel):
    active: str
    models: list[RegistryModel]


def _build_model_info() -> ModelInfo:
    try:
        ml_model.ensure_loaded()
        return ModelInfo(
            version=ml_model.version(),
            algorithm=ml_model.model_name(),
            trainedAt="2026-07-12",
            metrics=ml_model.metrics_info(),
        )
    except Exception:
        return ModelInfo(
            version="threshold-baseline-0.1.0",
            algorithm="ThresholdBaseline",
            trainedAt=None,
            metrics={},
        )


MODEL_INFO = _build_model_info()


def _classify(samples: SensorSamples) -> tuple[bool, float]:
    """Run inference using the trained ML model (T1.7 / SL-20)."""
    try:
        return ml_model.predict(
            samples.accX, samples.accY, samples.accZ,
            samples.gyroX, samples.gyroY, samples.gyroZ,
        )
    except Exception:
        # Fallback to threshold baseline if model is unavailable.
        from math import sqrt
        accel_peak = max(
            sqrt(x**2 + y**2 + z**2)
            for x, y, z in zip(samples.accX, samples.accY, samples.accZ)
        )
        gyro_peak = max(
            sqrt(x**2 + y**2 + z**2)
            for x, y, z in zip(samples.gyroX, samples.gyroY, samples.gyroZ)
        )
        fall_detected = accel_peak > 15 or gyro_peak > 300
        peak_ratio = max(accel_peak / 15, gyro_peak / 300)
        confidence = (
            min(0.75 + min(peak_ratio, 2.0) * 0.1, 0.99)
            if fall_detected
            else min(0.85 + (1 - min(peak_ratio, 1.0)) * 0.1, 0.99)
        )
        return fall_detected, round(confidence, 3)


def _require_postgres() -> None:
    if not pg.postgres_enabled():
        raise HTTPException(
            status_code=503,
            detail="DATABASE_URL is not configured; PostgreSQL is required",
        )


def _row_to_app_version(row: dict) -> AppVersion:
    return AppVersion(
        version_code=row["version_code"],
        version_name=row["version_name"],
        apk_url=row["apk_url"],
        release_notes=row.get("release_notes"),
        min_supported_version_code=row.get("min_supported_version_code"),
    )



@app.get("/health", tags=["operation"])
def health():
    return {
        "status": "healthy",
        "service": "sentilife-inference",
        "modelVersion": MODEL_INFO.version,
    }


@app.get("/metrics", include_in_schema=False)
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/model/info", response_model=ModelInfo, tags=["model"])
def model_info():
    return MODEL_INFO


@app.post("/model/reload", response_model=ReloadResponse, tags=["model"])
def reload_model():
    try:
        new_version = ml_model.reload()
        return ReloadResponse(
            status="reloaded",
            modelVersion=new_version,
            detail="ACTIVE model reloaded from registry.",
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Could not reload model: {exc}") from exc


@app.get("/model/registry", response_model=RegistryResponse, tags=["model"])
def model_registry():
    try:
        entries = ml_model.list_registry()
        active = next((e["id"] for e in entries if e["status"] == "ACTIVE"), entries[0]["id"])
        return RegistryResponse(
            active=active,
            models=[RegistryModel(**e) for e in entries],
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Registry unavailable: {exc}") from exc


@app.post("/predict", response_model=PredictionResponse, tags=["inference"])
def predict(data: PredictionRequest):
    started_at = perf_counter()
    with PREDICTION_LATENCY.time():
        fall_detected, confidence = _classify(data.samples)
    latency_ms = (perf_counter() - started_at) * 1000
    return PredictionResponse(
        fallDetected=fall_detected,
        confidence=confidence,
        modelVersion=ml_model.version(),
        latencyMs=round(latency_ms, 3),
    )


@app.get(
    "/app/latest-version",
    response_model=AppVersion,
    deprecated=True,
    tags=["deprecated-ota"],
)
def get_latest_version(response: Response):
    response.headers["Deprecation"] = "true"
    response.headers["Warning"] = '299 - "Migrate this endpoint to the Java backend"'
    _require_postgres()
    row = pg.fetch_latest_app_version()
    if not row:
        raise HTTPException(status_code=404, detail="No app versions are registered")
    return _row_to_app_version(row)


@app.post(
    "/app/register-version",
    status_code=201,
    deprecated=True,
    tags=["deprecated-ota"],
)
def register_version(body: RegisterVersionRequest, response: Response):
    response.headers["Deprecation"] = "true"
    response.headers["Warning"] = '299 - "Migrate this endpoint to the Java backend"'
    _require_postgres()
    pg.insert_app_version(body.model_dump())
    return {"status": "ok", "version_code": body.version_code}


if __name__ == "__main__":
    uvicorn.run("api.main:app", host="0.0.0.0", port=8000, reload=True)
