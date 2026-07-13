"""
SL-36 / T2.10 — Exportar dataset etiquetado para reentrenamiento.

Genera un CSV en data/feedback/ a partir de alertas con feedback confirmado.
En producción lo alimenta GET /admin/export; aquí es un script reproducible
que crea datos de ejemplo + estructura del export real.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

OUTPUT_DIR = Path("data/feedback")
SAMPLE_PATH = OUTPUT_DIR / "labeled_feedback_sample.csv"
MANIFEST_PATH = OUTPUT_DIR / "export_manifest.json"


def _sample_records() -> list[dict]:
    """Registros de ejemplo alineados con spec §6.5 feedback_labels."""
    now = datetime.now(timezone.utc)
    return [
        {
            "alert_id": "uuid-alert-002",
            "monitored_person_id": "uuid-person-001",
            "detected_at": (now.replace(hour=10)).isoformat(),
            "fall_detected": True,
            "confidence": 0.87,
            "model_version": "xgboost-v1.0.0",
            "feedback_label": "TRUE_FALL",
            "reviewed_by": "caregiver@test.com",
            "comment": "Caída confirmada en el salón",
        },
        {
            "alert_id": "uuid-alert-003",
            "monitored_person_id": "uuid-person-001",
            "detected_at": (now.replace(hour=8)).isoformat(),
            "fall_detected": True,
            "confidence": 0.61,
            "model_version": "xgboost-v1.0.0",
            "feedback_label": "FALSE_ALARM",
            "reviewed_by": "caregiver@test.com",
            "comment": "Se agachó a recoger algo",
        },
    ]


def export_labeled_dataset(output: Path = SAMPLE_PATH) -> Path:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    records = _sample_records()
    df = pd.DataFrame(records)
    df.to_csv(output, index=False)

    manifest = {
        "task": "SL-36 / T2.10",
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "format": "csv",
        "records": len(records),
        "path": str(output),
        "columns": list(df.columns),
        "note": "En producción este CSV se genera desde feedback_labels en Postgres",
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default=str(SAMPLE_PATH))
    args = parser.parse_args()
    path = export_labeled_dataset(Path(args.output))
    print(f"✅ Export generado: {path} ({MANIFEST_PATH})")


if __name__ == "__main__":
    main()
