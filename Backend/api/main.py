from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from math import sqrt
from typing import Optional
import os
import uvicorn
from supabase import create_client, Client

from api import db as pg

app = FastAPI(
    title="Fall Detector API",
    description="API para detección de caídas basada en datos de sensores.",
    version="0.1.0",
)

# CORS — solo orígenes necesarios.
# Las apps móviles nativas no envían Origin, así que allow_origins=["*"]
# es seguro en la práctica para una API mobile. Si añades un frontend web,
# añade su dominio aquí y elimina "*".
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "X-API-Key"],
)

# --- Supabase client (legacy) ---
# TODO: eliminar — producción migrará a AWS + Postgres (RDS).
# Solo se usa si DATABASE_URL no está configurada (p. ej. Render legacy).
_supabase_url = os.environ.get("SUPABASE_URL", "")
_supabase_key = os.environ.get("SUPABASE_KEY", "")
supabase: Client | None = None
if _supabase_url and _supabase_key:
    supabase = create_client(_supabase_url, _supabase_key)


def _require_supabase() -> Client:
    if supabase is None:
        raise HTTPException(status_code=503, detail="Supabase no configurado (legacy)")
    return supabase


# --- Modelos de datos ---

# App versioning
class AppVersion(BaseModel):
    version_code: int
    version_name: str
    apk_url: str
    release_notes: Optional[str] = None
    min_supported_version_code: Optional[int] = None

class RegisterVersionRequest(AppVersion):
    pass


class SensorData(BaseModel):
    accel_x: float
    accel_y: float
    accel_z: float
    gyro_x: float
    gyro_y: float
    gyro_z: float
    heart_rate: float
    room_temp: float
    room_light: float


class PredictionResponse(BaseModel):
    fall_detected: bool
    confidence: float
    message: str


def _row_to_app_version(row: dict) -> AppVersion:
    return AppVersion(
        version_code=row["version_code"],
        version_name=row["version_name"],
        apk_url=row["apk_url"],
        release_notes=row.get("release_notes"),
        min_supported_version_code=row.get("min_supported_version_code"),
    )


# --- Lógica de clasificación ---
# TODO: eliminar umbrales — reemplazar por modelo ML en api/inference/

def classify(data: SensorData) -> tuple[bool, float]:
    accel_mag = sqrt(data.accel_x**2 + data.accel_y**2 + data.accel_z**2)
    gyro_mag = sqrt(data.gyro_x**2 + data.gyro_y**2 + data.gyro_z**2)

    fall = accel_mag > 15 or gyro_mag > 300

    # Confianza aproximada basada en cuánto superan el umbral
    if fall:
        accel_ratio = min(accel_mag / 15, 2.0)
        gyro_ratio = min(gyro_mag / 300, 2.0)
        confidence = min(0.75 + max(accel_ratio, gyro_ratio) * 0.1, 0.99)
    else:
        confidence = min(0.85 + (1 - min(accel_mag / 15, 1.0)) * 0.1, 0.99)

    return fall, round(confidence, 3)


# --- Endpoints ---

@app.get("/")
def root():
    return {"status": "ok", "service": "Fall Detector API"}


@app.get("/health")
def health():
    return {"status": "healthy"}


# --- App update endpoints ---

@app.get("/app/latest-version", response_model=AppVersion)
def get_latest_version():
    if pg.postgres_enabled():
        row = pg.fetch_latest_app_version()
        if not row:
            raise HTTPException(status_code=404, detail="No hay versiones registradas")
        return _row_to_app_version(row)

    # TODO: eliminar bloque Supabase al migrar a AWS
    db = _require_supabase()
    result = (
        db.table("app_versions")
        .select("*")
        .order("version_code", desc=True)
        .limit(1)
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="No hay versiones registradas")

    return _row_to_app_version(result.data[0])


@app.post("/app/register-version", status_code=201)
def register_version(body: RegisterVersionRequest):
    payload = {
        "version_code": body.version_code,
        "version_name": body.version_name,
        "apk_url": body.apk_url,
        "release_notes": body.release_notes,
        "min_supported_version_code": body.min_supported_version_code,
    }

    if pg.postgres_enabled():
        pg.insert_app_version(payload)
        return {"status": "ok", "version_code": body.version_code}

    # TODO: eliminar bloque Supabase al migrar a AWS
    db = _require_supabase()
    db.table("app_versions").insert(payload).execute()

    return {"status": "ok", "version_code": body.version_code}


@app.post("/predict", response_model=PredictionResponse)
def predict(data: SensorData):
    fall_detected, confidence = classify(data)
    return PredictionResponse(
        fall_detected=fall_detected,
        confidence=confidence,
        message="Caída detectada" if fall_detected else "Sin caída",
    )


if __name__ == "__main__":
    uvicorn.run("api.main:app", host="0.0.0.0", port=8000, reload=True)
