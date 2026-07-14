"""ADL replay gate — T2c.5.

Replays labeled ADL fixtures through the loaded model and counts false positives.
Used in CI to ensure normal activity does not trigger fall detection after the
mobile alignment fix.
"""

from __future__ import annotations

import json
import pickle
from dataclasses import dataclass
from pathlib import Path

import pandas as pd

from api.inference.features import extract_features

FIXTURES_DIR = Path(__file__).resolve().parents[2] / "data" / "fixtures" / "mobile"
DEFAULT_MODEL = Path(__file__).resolve().parents[1] / "models" / "model.pkl"

ADL_LABEL_KEYWORDS = ("ADL", "WALK", "REST")


@dataclass(frozen=True)
class WindowReplay:
    fixture_name: str
    label: str
    fall_detected: bool
    confidence: float
    fall_probability: float


@dataclass(frozen=True)
class ADLReplayResult:
    total_windows: int
    adl_false_positives: int
    fall_windows_detected: int
    threshold: float
    model_version: str
    windows: tuple[WindowReplay, ...]


def _is_adl_label(label: str) -> bool:
    upper = label.upper()
    if "SPIKE" in upper or upper.endswith("_TRUE_FALL") or upper.startswith("MOBILE_FALL"):
        return False
    return "ADL" in upper or "WALK" in upper or "REST" in upper


def _predict_window(payload: dict, model_bundle: dict) -> tuple[bool, float, float]:
    samples = payload["samples"]
    aligned = extract_features(
        samples["accX"],
        samples["accY"],
        samples["accZ"],
        samples["gyroX"],
        samples["gyroY"],
        samples["gyroZ"],
    )
    numeric_features = model_bundle["numeric_features"]
    threshold = float(model_bundle["threshold"])
    model = model_bundle["model"]

    row = {name: [aligned[name]] for name in numeric_features}
    df = pd.DataFrame(row)
    proba = model.predict_proba(df)[0]
    fall_prob = float(proba[1])
    is_fall = fall_prob >= threshold
    confidence = fall_prob if is_fall else (1.0 - fall_prob)
    return is_fall, confidence, fall_prob


def _discover_adl_fixtures(fixtures_dir: Path) -> list[tuple[str, dict]]:
    items: list[tuple[str, dict]] = []
    for path in sorted(fixtures_dir.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if _is_adl_label(data.get("label", "")):
            items.append((path.stem, data))
    return items


def run_adl_replay(
    *,
    model_path: Path = DEFAULT_MODEL,
    fixtures_dir: Path = FIXTURES_DIR,
) -> ADLReplayResult:
    with open(model_path, "rb") as handle:
        bundle = pickle.load(handle)

    replays: list[WindowReplay] = []
    adl_false_positives = 0

    for name, payload in _discover_adl_fixtures(fixtures_dir):
        fall_detected, confidence, fall_prob = _predict_window(payload, bundle)
        replays.append(
            WindowReplay(
                fixture_name=name,
                label=payload["label"],
                fall_detected=fall_detected,
                confidence=confidence,
                fall_probability=fall_prob,
            )
        )
        if fall_detected:
            adl_false_positives += 1

    version = str(bundle.get("model_name", "unknown"))
    return ADLReplayResult(
        total_windows=len(replays),
        adl_false_positives=adl_false_positives,
        fall_windows_detected=sum(1 for r in replays if r.fall_detected),
        threshold=float(bundle["threshold"]),
        model_version=version,
        windows=tuple(replays),
    )


def main() -> None:
    result = run_adl_replay()
    print(
        json.dumps(
            {
                "total_windows": result.total_windows,
                "adl_false_positives": result.adl_false_positives,
                "threshold": result.threshold,
                "model_version": result.model_version,
                "windows": [w.__dict__ for w in result.windows],
            },
            indent=2,
        )
    )
    if result.adl_false_positives > 0:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
