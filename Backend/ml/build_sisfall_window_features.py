"""Build reproducible SisFall window-level statistical features.

SL-16 / T1.3 consumes the SL-14 window contract and turns raw SisFall trials
into one row per telemetry window. The output is intended to be the canonical
training table for the next ML tasks: every row has deterministic window
metadata plus statistical features extracted from the exact signals expected by
the inference contract.

Run from Backend/:
    python ml/build_sisfall_window_features.py \
        --root data/raw/sisfall \
        --out data/processed/sisfall/sisfall_windows_features.csv.gz \
        --manifest data/processed/sisfall/feature_manifest.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from io import StringIO
from pathlib import Path

import numpy as np
import pandas as pd

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from ml.window_contract import WINDOW_CONTRACT


STANDARD_GRAVITY = 9.80665

ADXL345 = {"range_": 16, "resolution": 13}
ITG3200 = {"range_": 2000, "resolution": 16}

FILENAME_RE = re.compile(
    r"^([DF]\d{2})_(S[AE]\d{2})_R(\d{2})\.txt$", re.IGNORECASE
)

RAW_COLUMNS = [
    "acc_raw_x",
    "acc_raw_y",
    "acc_raw_z",
    "gyro_raw_x",
    "gyro_raw_y",
    "gyro_raw_z",
    "acc2_raw_x",
    "acc2_raw_y",
    "acc2_raw_z",
]

REQUIRED_SIGNAL_COLUMNS = {
    "accX": "accX",
    "accY": "accY",
    "accZ": "accZ",
    "gyroX": "gyroX",
    "gyroY": "gyroY",
    "gyroZ": "gyroZ",
}


def bits_to_units(raw: pd.Series, *, range_: float, resolution: int) -> pd.Series:
    scale = (2 * range_) / (2**resolution)
    return raw * scale


def find_trial_files(root: Path) -> list[Path]:
    return sorted(path for path in root.rglob("*.txt") if FILENAME_RE.match(path.name))


def parse_filename(path: Path) -> dict[str, object]:
    match = FILENAME_RE.match(path.name)
    if not match:
        raise ValueError(f"Unexpected SisFall file name: {path.name}")

    activity_code, subject_id, trial = match.groups()
    activity_code = activity_code.upper()
    subject_id = subject_id.upper()
    return {
        "activity_code": activity_code,
        "subject_id": subject_id,
        "trial": trial,
        "age_group": "elderly" if subject_id.startswith("SE") else "adult",
        "fall_event": int(activity_code.startswith("F")),
        "source_file": path.name,
    }


def load_trial(path: Path) -> pd.DataFrame:
    raw_text = path.read_text(encoding="latin-1").replace(";", "")
    df = pd.read_csv(
        StringIO(raw_text),
        header=None,
        names=RAW_COLUMNS,
        sep=r"\s*,\s*",
        engine="python",
    )
    df = df.apply(pd.to_numeric, errors="coerce").dropna()

    acc_x_g = bits_to_units(df["acc_raw_x"], **ADXL345)
    acc_y_g = bits_to_units(df["acc_raw_y"], **ADXL345)
    acc_z_g = bits_to_units(df["acc_raw_z"], **ADXL345)

    converted = pd.DataFrame(
        {
            "accX": acc_x_g * STANDARD_GRAVITY,
            "accY": acc_y_g * STANDARD_GRAVITY,
            "accZ": acc_z_g * STANDARD_GRAVITY,
            "gyroX": bits_to_units(df["gyro_raw_x"], **ITG3200),
            "gyroY": bits_to_units(df["gyro_raw_y"], **ITG3200),
            "gyroZ": bits_to_units(df["gyro_raw_z"], **ITG3200),
        }
    )
    return converted.reset_index(drop=True)


def _window_starts_seconds(n_source_samples: int) -> np.ndarray:
    contract = WINDOW_CONTRACT
    sample_duration = (contract.samples_per_signal - 1) / contract.sample_rate_hz
    last_source_time = (n_source_samples - 1) / contract.source_rate_hz
    latest_start = last_source_time - sample_duration
    if latest_start < 0:
        return np.array([], dtype=float)

    hop_seconds = contract.hop_ms / 1000
    # Add a tiny epsilon so exact-duration trials keep their final window.
    return np.arange(0, latest_start + 1e-9, hop_seconds)


def extract_contract_window(trial: pd.DataFrame, start_seconds: float) -> pd.DataFrame:
    source_times = np.arange(len(trial), dtype=float) / WINDOW_CONTRACT.source_rate_hz
    trial_values = trial[list(WINDOW_CONTRACT.required_signal_keys)].to_numpy(dtype=float)
    window_values = extract_contract_window_values(
        trial_values, source_times, start_seconds
    )
    return pd.DataFrame(window_values, columns=WINDOW_CONTRACT.required_signal_keys)


def extract_contract_window_values(
    trial_values: np.ndarray, source_times: np.ndarray, start_seconds: float
) -> np.ndarray:
    contract = WINDOW_CONTRACT
    target_times = start_seconds + (
        np.arange(contract.samples_per_signal, dtype=float) / contract.sample_rate_hz
    )

    columns = [
        np.interp(target_times, source_times, trial_values[:, index])
        for index in range(trial_values.shape[1])
    ]
    window = np.column_stack(columns)
    if not np.isfinite(window).all():
        raise ValueError("Window contains NaN or infinite values after interpolation")
    if len(window) != contract.samples_per_signal:
        raise ValueError("Window does not match the SL-14 sample count")
    return window


def _safe_skew(values: np.ndarray) -> float:
    std = values.std(ddof=0)
    if std == 0:
        return 0.0
    centered = values - values.mean()
    return float(np.mean((centered / std) ** 3))


def _safe_kurtosis(values: np.ndarray) -> float:
    std = values.std(ddof=0)
    if std == 0:
        return 0.0
    centered = values - values.mean()
    return float(np.mean((centered / std) ** 4) - 3.0)


def _safe_corr(left: np.ndarray, right: np.ndarray) -> float:
    if left.std(ddof=0) == 0 or right.std(ddof=0) == 0:
        return 0.0
    return float(np.corrcoef(left, right)[0, 1])


def statistical_features(window: pd.DataFrame) -> dict[str, float]:
    return statistical_features_from_matrix(
        window.to_numpy(dtype=float), list(window.columns)
    )


def statistical_features_from_matrix(
    window_values: np.ndarray, signals: list[str]
) -> dict[str, float]:
    features: dict[str, float] = {}

    for index, signal in enumerate(signals):
        values = window_values[:, index]
        q25, q75 = np.percentile(values, [25, 75])
        diff_abs = np.abs(np.diff(values))
        features[f"{signal}_mean"] = float(values.mean())
        features[f"{signal}_std"] = float(values.std(ddof=0))
        features[f"{signal}_min"] = float(values.min())
        features[f"{signal}_max"] = float(values.max())
        features[f"{signal}_median"] = float(np.median(values))
        features[f"{signal}_q25"] = float(q25)
        features[f"{signal}_q75"] = float(q75)
        features[f"{signal}_iqr"] = float(q75 - q25)
        features[f"{signal}_rms"] = float(np.sqrt(np.mean(values**2)))
        features[f"{signal}_energy"] = float(np.sum(values**2) / len(values))
        features[f"{signal}_skew"] = _safe_skew(values)
        features[f"{signal}_kurtosis"] = _safe_kurtosis(values)
        features[f"{signal}_diff_mean_abs"] = float(diff_abs.mean()) if len(diff_abs) else 0.0
        features[f"{signal}_diff_max_abs"] = float(diff_abs.max()) if len(diff_abs) else 0.0

    signal_index = {signal: index for index, signal in enumerate(signals)}
    acc = window_values[
        :, [signal_index["accX"], signal_index["accY"], signal_index["accZ"]]
    ]
    gyro = window_values[
        :, [signal_index["gyroX"], signal_index["gyroY"], signal_index["gyroZ"]]
    ]
    derived = {
        "acc_magnitude": np.linalg.norm(acc, axis=1),
        "gyro_magnitude": np.linalg.norm(gyro, axis=1),
    }
    for name, values in derived.items():
        q25, q75 = np.percentile(values, [25, 75])
        diff_abs = np.abs(np.diff(values))
        features[f"{name}_mean"] = float(values.mean())
        features[f"{name}_std"] = float(values.std(ddof=0))
        features[f"{name}_min"] = float(values.min())
        features[f"{name}_max"] = float(values.max())
        features[f"{name}_median"] = float(np.median(values))
        features[f"{name}_q25"] = float(q25)
        features[f"{name}_q75"] = float(q75)
        features[f"{name}_iqr"] = float(q75 - q25)
        features[f"{name}_rms"] = float(np.sqrt(np.mean(values**2)))
        features[f"{name}_energy"] = float(np.sum(values**2) / len(values))
        features[f"{name}_diff_mean_abs"] = float(diff_abs.mean()) if len(diff_abs) else 0.0
        features[f"{name}_diff_max_abs"] = float(diff_abs.max()) if len(diff_abs) else 0.0

    features["acc_sma"] = float(np.sum(np.abs(acc)) / len(window_values))
    features["gyro_sma"] = float(np.sum(np.abs(gyro)) / len(window_values))
    features["acc_xy_corr"] = _safe_corr(acc[:, 0], acc[:, 1])
    features["acc_xz_corr"] = _safe_corr(acc[:, 0], acc[:, 2])
    features["acc_yz_corr"] = _safe_corr(acc[:, 1], acc[:, 2])
    features["gyro_xy_corr"] = _safe_corr(gyro[:, 0], gyro[:, 1])
    features["gyro_xz_corr"] = _safe_corr(gyro[:, 0], gyro[:, 2])
    features["gyro_yz_corr"] = _safe_corr(gyro[:, 1], gyro[:, 2])

    return features


def build_window_features(root: Path) -> tuple[pd.DataFrame, dict[str, object]]:
    trial_files = find_trial_files(root)
    if not trial_files:
        raise FileNotFoundError(f"No SisFall trial files found under {root}")

    rows: list[dict[str, object]] = []
    skipped_files = 0
    skipped_short_trials = 0

    for index, path in enumerate(trial_files, start=1):
        metadata = parse_filename(path)
        try:
            trial = load_trial(path)
        except Exception as exc:
            print(f"WARN skipping {path.name}: {exc}")
            skipped_files += 1
            continue

        starts = _window_starts_seconds(len(trial))
        if len(starts) == 0:
            skipped_short_trials += 1
            continue

        signal_keys = list(WINDOW_CONTRACT.required_signal_keys)
        trial_values = trial[signal_keys].to_numpy(dtype=float)
        source_times = np.arange(len(trial), dtype=float) / WINDOW_CONTRACT.source_rate_hz
        for window_index, start_seconds in enumerate(starts):
            window_values = extract_contract_window_values(
                trial_values, source_times, float(start_seconds)
            )
            row = {
                **metadata,
                "window_id": (
                    f"{metadata['activity_code']}_{metadata['subject_id']}_"
                    f"R{metadata['trial']}_W{window_index:04d}"
                ),
                "window_index": window_index,
                "window_start_ms": int(round(start_seconds * 1000)),
                "window_end_ms": int(round(start_seconds * 1000 + WINDOW_CONTRACT.duration_ms)),
                "source_start_sample": int(round(start_seconds * WINDOW_CONTRACT.source_rate_hz)),
                "source_end_sample": int(
                    round(
                        (
                            start_seconds
                            + WINDOW_CONTRACT.duration_ms / 1000
                        )
                        * WINDOW_CONTRACT.source_rate_hz
                    )
                ),
                "sample_rate_hz": WINDOW_CONTRACT.sample_rate_hz,
                "samples_per_signal": WINDOW_CONTRACT.samples_per_signal,
            }
            row.update(statistical_features_from_matrix(window_values, signal_keys))
            rows.append(row)

        if index % 500 == 0:
            print(f"  processed {index}/{len(trial_files)} trials", flush=True)

    if not rows:
        raise RuntimeError("No valid SisFall windows were generated")

    df = pd.DataFrame(rows).sort_values(
        ["subject_id", "activity_code", "trial", "window_index"]
    )
    feature_columns = [
        column
        for column in df.columns
        if column
        not in {
            "activity_code",
            "subject_id",
            "trial",
            "age_group",
            "fall_event",
            "source_file",
            "window_id",
            "window_index",
            "window_start_ms",
            "window_end_ms",
            "source_start_sample",
            "source_end_sample",
            "sample_rate_hz",
            "samples_per_signal",
        }
    ]
    manifest = {
        "task": "SL-16 / T1.3",
        "source_dataset": "SisFall",
        "script": "Backend/ml/build_sisfall_window_features.py",
        "window_contract_schema_version": "1.0.0",
        "source_rate_hz": WINDOW_CONTRACT.source_rate_hz,
        "sample_rate_hz": WINDOW_CONTRACT.sample_rate_hz,
        "duration_ms": WINDOW_CONTRACT.duration_ms,
        "hop_ms": WINDOW_CONTRACT.hop_ms,
        "samples_per_signal": WINDOW_CONTRACT.samples_per_signal,
        "required_signals": list(WINDOW_CONTRACT.required_signal_keys),
        "feature_count": len(feature_columns),
        "feature_columns": feature_columns,
        "trial_files_found": len(trial_files),
        "trial_files_skipped": skipped_files,
        "short_trials_skipped": skipped_short_trials,
        "windows": int(len(df)),
        "subjects": int(df["subject_id"].nunique()),
        "fall_windows": int(df["fall_event"].sum()),
        "adl_windows": int((df["fall_event"] == 0).sum()),
    }
    return df, manifest


def write_outputs(df: pd.DataFrame, manifest: dict[str, object], out: Path, manifest_out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out, index=False)
    manifest_out.parent.mkdir(parents=True, exist_ok=True)
    manifest_out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default="data/raw/sisfall", help="SisFall raw root")
    parser.add_argument(
        "--out",
        default="data/processed/sisfall/sisfall_windows_features.csv.gz",
        help="Window-level feature CSV output",
    )
    parser.add_argument(
        "--manifest",
        default="data/processed/sisfall/feature_manifest.json",
        help="Feature manifest JSON output",
    )
    args = parser.parse_args()

    root = Path(args.root)
    if not root.exists():
        raise FileNotFoundError(f"SisFall raw root does not exist: {root}")

    df, manifest = build_window_features(root)
    write_outputs(df, manifest, Path(args.out), Path(args.manifest))

    print("OK SisFall window feature dataset generated")
    print(f"   windows: {manifest['windows']}")
    print(f"   fall windows: {manifest['fall_windows']}")
    print(f"   ADL windows: {manifest['adl_windows']}")
    print(f"   subjects: {manifest['subjects']}")
    print(f"   feature columns: {manifest['feature_count']}")
    print(f"   saved CSV: {args.out}")
    print(f"   saved manifest: {args.manifest}")


if __name__ == "__main__":
    main()
