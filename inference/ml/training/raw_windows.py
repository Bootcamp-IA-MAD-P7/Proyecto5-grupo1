"""Load SisFall raw telemetry windows (125 × 6) aligned with SL-14 contract.

Used by T4.2 deep-learning experiments. Windows are gravity-aligned before
return, matching the production feature pipeline.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd

from ml.pipeline.build_sisfall_window_features import (
    _window_starts_seconds,
    extract_contract_window_values,
    find_trial_files,
    load_trial,
    parse_filename,
)
from ml.pipeline.gravity_align import align_window_values
from ml.pipeline.window_contract import WINDOW_CONTRACT

SIGNAL_KEYS = list(WINDOW_CONTRACT.required_signal_keys)
CACHE_PATH = Path("data/processed/sisfall/sisfall_raw_windows.npz")
METADATA_PATH = Path("data/processed/sisfall/sisfall_raw_windows_meta.json")


def _build_raw_arrays(root: Path) -> tuple[np.ndarray, np.ndarray, np.ndarray, list[str]]:
    trial_files = find_trial_files(root)
    if not trial_files:
        raise FileNotFoundError(f"No SisFall trial files found under {root}")

    windows: list[np.ndarray] = []
    labels: list[int] = []
    subjects: list[str] = []
    window_ids: list[str] = []

    for path in trial_files:
        metadata = parse_filename(path)
        try:
            trial = load_trial(path)
        except Exception:
            continue

        starts = _window_starts_seconds(len(trial))
        if len(starts) == 0:
            continue

        trial_values = trial[SIGNAL_KEYS].to_numpy(dtype=float)
        source_times = np.arange(len(trial), dtype=float) / WINDOW_CONTRACT.source_rate_hz

        for window_index, start_seconds in enumerate(starts):
            window_values = extract_contract_window_values(
                trial_values, source_times, float(start_seconds)
            )
            window_values = align_window_values(window_values, SIGNAL_KEYS)
            windows.append(window_values.astype(np.float32))
            labels.append(int(metadata["fall_event"]))
            subjects.append(str(metadata["subject_id"]))
            window_ids.append(
                f"{metadata['activity_code']}_{metadata['subject_id']}_"
                f"R{metadata['trial']}_W{window_index:04d}"
            )

    if not windows:
        raise RuntimeError("No valid SisFall raw windows were generated")

    order = np.lexsort(
        (
            [wid.split("_W")[-1] for wid in window_ids],
            [wid.split("_R")[1].split("_")[0] for wid in window_ids],
            [wid.split("_")[1] for wid in window_ids],
            subjects,
        )
    )
    X = np.stack([windows[i] for i in order], axis=0)
    y = np.array([labels[i] for i in order], dtype=np.int32)
    groups = np.array([subjects[i] for i in order])
    sorted_ids = [window_ids[i] for i in order]
    return X, y, groups, sorted_ids


def load_raw_windows(
    root: Path | str = "data/raw/sisfall",
    *,
    cache: Path = CACHE_PATH,
    rebuild: bool = False,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Return (X, y, groups) with X shape (N, 125, 6)."""
    root = Path(root)
    cache = Path(cache)

    if cache.exists() and not rebuild:
        data = np.load(cache)
        return data["X"], data["y"], data["groups"]

    X, y, groups, window_ids = _build_raw_arrays(root)
    cache.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(cache, X=X, y=y, groups=groups, window_ids=window_ids)
    meta = {
        "n_windows": int(len(y)),
        "n_subjects": int(len(set(groups.tolist()))),
        "shape": list(X.shape),
        "signals": SIGNAL_KEYS,
        "cache": str(cache),
    }
    METADATA_PATH.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    return X, y, groups


def align_with_feature_csv(
    X: np.ndarray,
    y: np.ndarray,
    groups: np.ndarray,
    feature_csv: Path | str,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Reorder raw windows to match rows in sisfall_windows_features.csv.gz."""
    df = pd.read_csv(feature_csv)
    cache = np.load(CACHE_PATH)
    window_ids = cache["window_ids"].tolist()
    id_to_index = {wid: idx for idx, wid in enumerate(window_ids)}

    indices = []
    for wid in df["window_id"]:
        if wid not in id_to_index:
            raise KeyError(f"window_id {wid} missing from raw window cache")
        indices.append(id_to_index[wid])

    idx = np.array(indices, dtype=int)
    return X[idx], y[idx], groups[idx]
