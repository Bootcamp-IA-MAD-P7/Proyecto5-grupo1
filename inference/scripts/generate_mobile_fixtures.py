"""Generate labeled mobile telemetry fixtures for T2c.4 parity diagnosis."""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ml.pipeline.build_sisfall_window_features import (
    extract_contract_window,
    load_trial,
)
from ml.pipeline.window_contract import WINDOW_CONTRACT

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "data" / "fixtures" / "mobile"
SISFALL_ROOT = ROOT / "data" / "raw" / "sisfall"

SAMPLE_RATE = WINDOW_CONTRACT.sample_rate_hz
N = WINDOW_CONTRACT.samples_per_signal


def _samples_dict(window: np.ndarray) -> dict[str, list[float]]:
    signals = WINDOW_CONTRACT.required_signal_keys
    return {
        signal: [float(v) for v in window[:, index]]
        for index, signal in enumerate(signals)
    }


def _fixture(
    *,
    label: str,
    description: str,
    samples: dict[str, list[float]],
    source: str,
) -> dict:
    now = datetime.now(timezone.utc)
    return {
        "label": label,
        "description": description,
        "source": source,
        "sampleRateHz": SAMPLE_RATE,
        "windowStart": now.isoformat().replace("+00:00", "Z"),
        "windowEnd": (
            now.replace(microsecond=0).isoformat().replace("+00:00", "Z")
        ),
        "samples": samples,
    }


def _mobile_adl_rest_portrait() -> dict:
    """Smoke-like ADL: phone upright, gravity on accY (field false-positive pattern)."""
    samples = {}
    for signal in WINDOW_CONTRACT.required_signal_keys:
        arr = [0.1] * N
        if signal == "accY":
            arr = [9.8] * N
        elif signal == "accZ":
            arr = [0.2] * N
        samples[signal] = arr
    return _fixture(
        label="MOBILE_ADL_REST_PORTRAIT",
        description="Reposo simulado móvil — gravedad en accY como smoke E2E",
        samples=samples,
        source="synthetic:smoke-telemetry-e2e",
    )


def _mobile_fall_spike() -> dict:
    """Smoke-like fall spike used in MVP smoke scripts."""
    samples = {}
    for signal in WINDOW_CONTRACT.required_signal_keys:
        arr = [0.1] * N
        if signal == "accY":
            arr = [9.8 if i <= 60 else 35.0 for i in range(N)]
        elif signal.startswith("acc") and signal != "accY":
            arr = [0.1 if i <= 60 else 12.0 for i in range(N)]
        elif signal.startswith("gyro"):
            arr = [0.5] * N
        samples[signal] = arr
    return _fixture(
        label="MOBILE_FALL_SPIKE",
        description="Caída simulada móvil — spike post-muestra 60 como smoke MVP",
        samples=samples,
        source="synthetic:smoke-mvp-e2e",
    )


def _sisfall_window_fixture(path: Path, label: str, start_seconds: float = 0.0) -> dict:
    trial = load_trial(path)
    window = extract_contract_window(trial, start_seconds)
    return _fixture(
        label=label,
        description=f"Ventana SisFall {path.name} @ {start_seconds}s (cinturón, 200→50 Hz)",
        samples=_samples_dict(window.to_numpy(dtype=float)),
        source=f"sisfall:{path.name}",
    )


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    fixtures = [
        _mobile_adl_rest_portrait(),
        _mobile_fall_spike(),
        _sisfall_window_fixture(
            SISFALL_ROOT / "SA02" / "D05_SA02_R03.txt",
            "SISFALL_ADL_WALK",
            start_seconds=0.0,
        ),
        _sisfall_window_fixture(
            SISFALL_ROOT / "SA02" / "F04_SA02_R01.txt",
            "SISFALL_TRUE_FALL",
            start_seconds=0.0,
        ),
    ]

    for item in fixtures:
        out = OUT_DIR / f"{item['label'].lower()}.json"
        out.write_text(json.dumps(item, indent=2), encoding="utf-8")
        print(f"Wrote {out}")


if __name__ == "__main__":
    main()
