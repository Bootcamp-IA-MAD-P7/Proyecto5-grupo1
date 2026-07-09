"""Shared SL-14 telemetry window contract.

The JSON file at repository root is the source of truth. This module gives
Python training and inference code a typed, importable view without changing
the current model pipeline.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


CONTRACT_PATH = (
    Path(__file__).resolve().parents[2] / "contracts" / "window_contract.json"
)


@dataclass(frozen=True)
class WindowContract:
    duration_ms: int
    sample_rate_hz: int
    overlap_ratio: float
    hop_ms: int
    samples_per_signal: int
    required_signal_keys: tuple[str, ...]
    optional_context_keys: tuple[str, ...]


def _require_mapping(raw: dict, key: str) -> dict:
    if key not in raw:
        raise ValueError(f"Invalid window contract: missing '{key}' section")
    value = raw[key]
    if not isinstance(value, dict):
        raise ValueError(f"Invalid window contract: '{key}' must be an object")
    return value


def _require_list(raw: dict, key: str) -> list:
    if key not in raw:
        raise ValueError(f"Invalid window contract: missing '{key}'")
    value = raw[key]
    if not isinstance(value, list):
        raise ValueError(f"Invalid window contract: '{key}' must be a list")
    return value


def _require_string_list(raw: dict, key: str, *, section: str) -> tuple[str, ...]:
    items = _require_list(raw, key)
    values = []
    for index, item in enumerate(items):
        if not isinstance(item, str) or not item:
            raise ValueError(
                f"Invalid window contract: '{section}.{key}[{index}]' "
                "must be a non-empty string"
            )
        values.append(item)
    return tuple(values)


def _require_string(raw: dict, key: str, *, section: str | None = None) -> str:
    path = f"{section}.{key}" if section else key
    if key not in raw:
        raise ValueError(f"Invalid window contract: missing '{path}'")
    value = raw[key]
    if not isinstance(value, str) or not value:
        raise ValueError(
            f"Invalid window contract: '{path}' must be a non-empty string"
        )
    return value


def _require_number(raw: dict, key: str, *, section: str) -> int | float:
    if key not in raw:
        raise ValueError(f"Invalid window contract: missing '{section}.{key}'")
    value = raw[key]
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise ValueError(
            f"Invalid window contract: '{section}.{key}' must be numeric"
        )
    return value


def _signal_names(items: list, *, section: str) -> tuple[str, ...]:
    if not items:
        raise ValueError(f"Invalid window contract: '{section}' must not be empty")

    names = []
    for index, item in enumerate(items):
        if not isinstance(item, dict):
            raise ValueError(
                f"Invalid window contract: '{section}[{index}]' must be an object"
            )
        name = item.get("name")
        if not isinstance(name, str) or not name:
            raise ValueError(
                f"Invalid window contract: '{section}[{index}].name' must be a non-empty string"
            )
        unit = item.get("unit")
        if not isinstance(unit, str) or not unit:
            raise ValueError(
                f"Invalid window contract: '{section}[{index}].unit' must be a non-empty string"
            )
        names.append(name)
    return tuple(names)


@lru_cache(maxsize=1)
def load_window_contract() -> WindowContract:
    raw = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("Invalid window contract: root must be an object")

    _require_string(raw, "schemaVersion")
    _require_string(raw, "source")
    window = _require_mapping(raw, "window")
    signals = _require_mapping(raw, "signals")
    api = _require_mapping(raw, "api")
    compatibility = _require_mapping(raw, "compatibility")

    _require_string(api, "telemetryEndpoint", section="api")
    _require_string(api, "inferenceEndpoint", section="api")
    _require_string(api, "timestampFormat", section="api")
    api_sample_keys = _require_string_list(
        api, "samplesObjectKeys", section="api"
    )
    _require_string(compatibility, "training", section="compatibility")
    _require_string(compatibility, "inference", section="compatibility")
    _require_string(compatibility, "flutter", section="compatibility")

    required_signals = _require_list(signals, "required")
    optional_context = _require_list(signals, "optionalContext")

    duration_ms = int(_require_number(window, "durationMs", section="window"))
    sample_rate_hz = int(_require_number(window, "sampleRateHz", section="window"))
    overlap_ratio = float(
        _require_number(window, "overlapRatio", section="window")
    )
    hop_ms = int(_require_number(window, "hopMs", section="window"))
    samples_per_signal = int(
        _require_number(window, "samplesPerSignal", section="window")
    )

    if duration_ms <= 0:
        raise ValueError("Invalid window contract: 'window.durationMs' must be > 0")
    if sample_rate_hz <= 0:
        raise ValueError("Invalid window contract: 'window.sampleRateHz' must be > 0")
    if not 0 < overlap_ratio < 1:
        raise ValueError(
            "Invalid window contract: 'window.overlapRatio' must be > 0 and < 1"
        )
    if hop_ms <= 0:
        raise ValueError("Invalid window contract: 'window.hopMs' must be > 0")
    if samples_per_signal <= 0:
        raise ValueError(
            "Invalid window contract: 'window.samplesPerSignal' must be > 0"
        )

    expected_samples = duration_ms * sample_rate_hz / 1000
    if samples_per_signal != expected_samples:
        raise ValueError(
            "Invalid window contract: 'window.samplesPerSignal' must equal "
            "window.durationMs * window.sampleRateHz / 1000"
        )

    expected_hop_ms = duration_ms * (1 - overlap_ratio)
    if hop_ms != expected_hop_ms:
        raise ValueError(
            "Invalid window contract: 'window.hopMs' must equal "
            "window.durationMs * (1 - window.overlapRatio)"
        )

    required_signal_keys = _signal_names(
        required_signals, section="signals.required"
    )
    optional_context_keys = _signal_names(
        optional_context, section="signals.optionalContext"
    )
    if tuple(api_sample_keys) != required_signal_keys:
        raise ValueError(
            "Invalid window contract: 'api.samplesObjectKeys' must match "
            "'signals.required' names"
        )

    return WindowContract(
        duration_ms=duration_ms,
        sample_rate_hz=sample_rate_hz,
        overlap_ratio=overlap_ratio,
        hop_ms=hop_ms,
        samples_per_signal=samples_per_signal,
        required_signal_keys=required_signal_keys,
        optional_context_keys=optional_context_keys,
    )


WINDOW_CONTRACT = load_window_contract()
