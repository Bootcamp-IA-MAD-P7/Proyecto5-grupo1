"""Retrain fall detector with SisFall + production feedback — T4.4 / ML-19.

Rebuilds SisFall window features (gravity-aligned), optionally augments the
training set with labelled windows from ``data/feedback/``, trains XGBoost,
computes real metrics (recall, precision, F1, overfitting) and writes a
versioned artifact registered as CANDIDATE.

Run from inference/:
    python -m ml.training.retrain_feedback
"""

from __future__ import annotations

import json
import pickle
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from sklearn.metrics import (
    average_precision_score,
    f1_score,
    precision_score,
    recall_score,
)
from sklearn.model_selection import GroupShuffleSplit
from sklearn.pipeline import Pipeline
from xgboost import XGBClassifier

BACKEND_ROOT = Path(__file__).resolve().parents[2]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from api.inference.features import extract_features
from ml.evaluation.adl_replay import (
    FIXTURES_DIR as ADL_FIXTURES_DIR,
    _discover_adl_fixtures,
    _predict_window,
    run_adl_replay,
)
from ml.pipeline.build_sisfall_window_features import build_window_features, write_outputs
from ml.training.retrain_t2c5 import (
    FEATURES_OUT,
    MANIFEST_OUT,
    OPTUNA_PARAMS,
    REGISTRY_OUT,
    SISFALL_ROOT,
    _find_threshold_with_adl_gate,
    _load_optuna_params,
    _metrics_at_threshold,
    _split_by_subject,
)
from ml.training.train_model import (
    CATEGORICAL_FEATURES,
    GROUP_COL,
    NON_FEATURE_COLS,
    RANDOM_STATE,
    TARGET,
    build_preprocessor,
)

FEEDBACK_DIR = BACKEND_ROOT / "data" / "feedback"
MODELS_DIR = BACKEND_ROOT / "ml" / "models"
METRICS_OUT = BACKEND_ROOT / "ml" / "artifacts" / "retrain_metrics.json"


def _parse_samples_json(raw: str) -> dict[str, list[float]] | None:
    if not raw or not isinstance(raw, str):
        return None
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return None
    if isinstance(payload, dict) and "samples" in payload:
        payload = payload["samples"]
    if not isinstance(payload, dict):
        return None
    required = ("accX", "accY", "accZ", "gyroX", "gyroY", "gyroZ")
    if not all(sig in payload for sig in required):
        return None
    if any(len(payload[sig]) != 125 for sig in required):
        return None
    return {sig: [float(v) for v in payload[sig]] for sig in required}


def _label_to_fall_event(label: str) -> int | None:
    normalized = (label or "").strip().upper()
    if normalized in {"TRUE_FALL", "FALL", "1", "TRUE"}:
        return 1
    if normalized in {"FALSE_ALARM", "NO_FALL", "0", "FALSE"}:
        return 0
    return None


def load_feedback_rows_from_payload(
    feedback_rows: list[dict[str, Any]] | None,
) -> tuple[pd.DataFrame | None, dict[str, Any]]:
    """Build feature rows from HTTP POST /train feedback_rows (T4d.2)."""
    meta: dict[str, Any] = {
        "files": [],
        "total_records": 0,
        "true_fall": 0,
        "false_alarm": 0,
        "augmented_windows": 0,
        "source": "http_payload",
    }
    rows: list[dict[str, Any]] = []

    if not feedback_rows:
        return None, meta

    meta["total_records"] = len(feedback_rows)

    for idx, row in enumerate(feedback_rows):
        fall_event = _label_to_fall_event(str(row.get("label", "")))
        if fall_event is None:
            continue
        if fall_event == 1:
            meta["true_fall"] += 1
        else:
            meta["false_alarm"] += 1

        samples_raw = row.get("samples")
        if not isinstance(samples_raw, dict):
            continue

        samples = _parse_samples_json(json.dumps(samples_raw))
        if samples is None:
            continue

        feat = extract_features(
            samples["accX"],
            samples["accY"],
            samples["accZ"],
            samples["gyroX"],
            samples["gyroY"],
            samples["gyroZ"],
        )
        feat[TARGET] = fall_event
        person_id = row.get("monitored_person_id", f"feedback-{idx}")
        feat[GROUP_COL] = f"feedback-{person_id}"
        rows.append(feat)
        meta["augmented_windows"] += 1

    if not rows:
        return None, meta
    return pd.DataFrame(rows), meta


def load_feedback_records(feedback_dir: Path = FEEDBACK_DIR) -> tuple[pd.DataFrame | None, dict[str, Any]]:
    """Load feedback CSVs; build feature rows when ``samples_json`` is present."""
    meta: dict[str, Any] = {
        "files": [],
        "total_records": 0,
        "true_fall": 0,
        "false_alarm": 0,
        "augmented_windows": 0,
        "source": "csv",
    }
    rows: list[dict[str, Any]] = []

    if not feedback_dir.exists():
        return None, meta

    for csv_path in sorted(feedback_dir.glob("*.csv")):
        df = pd.read_csv(csv_path)
        meta["files"].append(csv_path.name)
        meta["total_records"] += len(df)

        label_col = "label" if "label" in df.columns else "feedback_label"
        if label_col not in df.columns:
            continue

        for idx, row in df.iterrows():
            fall_event = _label_to_fall_event(str(row[label_col]))
            if fall_event is None:
                continue
            if fall_event == 1:
                meta["true_fall"] += 1
            else:
                meta["false_alarm"] += 1

            if "samples_json" not in df.columns:
                continue

            samples = _parse_samples_json(str(row["samples_json"]))
            if samples is None:
                continue

            feat = extract_features(
                samples["accX"],
                samples["accY"],
                samples["accZ"],
                samples["gyroX"],
                samples["gyroY"],
                samples["gyroZ"],
            )
            feat[TARGET] = fall_event
            feat[GROUP_COL] = f"feedback-{row.get('monitored_person_id', idx)}"
            rows.append(feat)
            meta["augmented_windows"] += 1

    if not rows:
        return None, meta
    return pd.DataFrame(rows), meta


def _merge_feedback(
    base_df: pd.DataFrame,
    feedback_df: pd.DataFrame | None,
    numeric_features: list[str],
) -> pd.DataFrame:
    if feedback_df is None or feedback_df.empty:
        return base_df

    missing = [c for c in numeric_features if c not in feedback_df.columns]
    for col in missing:
        feedback_df[col] = 0.0

    extra_cols = [c for c in base_df.columns if c not in feedback_df.columns]
    for col in extra_cols:
        if col == TARGET:
            continue
        if col == GROUP_COL:
            continue
        feedback_df[col] = base_df[col].iloc[0] if col in base_df.columns else None

    combined = pd.concat([base_df, feedback_df[base_df.columns]], ignore_index=True)
    return combined


def _current_active_recall(registry_path: Path = REGISTRY_OUT) -> tuple[str, float]:
    if not registry_path.exists():
        return "unknown", 0.0
    data = json.loads(registry_path.read_text(encoding="utf-8"))
    active_id = data.get("active", "")
    for entry in data.get("models", []):
        if entry.get("id") == active_id:
            metrics = entry.get("metrics", {})
            recall = metrics.get("recall_fall_test", metrics.get("recall", 0.0))
            return active_id, float(recall)
    return active_id or "unknown", 0.0


def _register_candidate(
    model_id: str,
    artifact_path: Path,
    threshold: float,
    metrics: dict[str, float],
    feedback_meta: dict[str, Any],
) -> None:
    registry = json.loads(REGISTRY_OUT.read_text(encoding="utf-8"))
    registry["models"] = [m for m in registry.get("models", []) if m.get("id") != model_id]
    registry["models"].append(
        {
            "id": model_id,
            "path": str(artifact_path.relative_to(BACKEND_ROOT)),
            "algorithm": "XGBoost",
            "status": "CANDIDATE",
            "metrics": {
                "recall_fall_test": metrics["recall"],
                "precision_fall_test": metrics["precision"],
                "f1_fall_test": metrics["f1"],
                "pr_auc_test": metrics.get("pr_auc", 0.0),
                "overfitting": metrics["overfitting"],
                "feedback_records": feedback_meta.get("total_records", 0),
                "feedback_augmented_windows": feedback_meta.get("augmented_windows", 0),
            },
            "threshold": threshold,
            "trainedAt": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            "gravity_alignment": "align_to_sisfall_reference_before_features",
        }
    )
    REGISTRY_OUT.write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")


def run_retrain(
    *,
    skip_feature_build: bool = False,
    feedback_rows: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Train a new model and return metrics for POST /train (T4.4 / T4d.2)."""
    if skip_feature_build and FEATURES_OUT.exists():
        df = pd.read_csv(FEATURES_OUT)
        manifest = json.loads(MANIFEST_OUT.read_text(encoding="utf-8"))
    else:
        df, manifest = build_window_features(SISFALL_ROOT)
        write_outputs(df, manifest, FEATURES_OUT, MANIFEST_OUT)

    numeric_features = manifest["feature_columns"]
    if feedback_rows:
        feedback_df, feedback_meta = load_feedback_rows_from_payload(feedback_rows)
    else:
        feedback_df, feedback_meta = load_feedback_records()
    df = _merge_feedback(df, feedback_df, numeric_features)

    previous_version, current_recall = _current_active_recall()

    train_df, val_df, test_df = _split_by_subject(df)
    x_train, y_train = train_df[numeric_features], train_df[TARGET]
    x_val, y_val = val_df[numeric_features], val_df[TARGET]
    x_test, y_test = test_df[numeric_features], test_df[TARGET]

    params = _load_optuna_params()
    clf = XGBClassifier(
        **params,
        objective="binary:logistic",
        eval_metric="logloss",
        random_state=RANDOM_STATE,
        n_jobs=-1,
    )
    preprocessor = build_preprocessor(numeric_features)
    pipeline = Pipeline([("prep", preprocessor), ("clf", clf)])
    pipeline.fit(x_train, y_train)

    threshold = _find_threshold_with_adl_gate(pipeline, x_val, y_val, numeric_features)

    train_probs = pipeline.predict_proba(x_train)[:, 1]
    val_probs = pipeline.predict_proba(x_val)[:, 1]
    test_probs = pipeline.predict_proba(x_test)[:, 1]

    train_metrics = _metrics_at_threshold(y_train.to_numpy(), train_probs, threshold)
    val_metrics = _metrics_at_threshold(y_val.to_numpy(), val_probs, threshold)
    test_metrics = _metrics_at_threshold(y_test.to_numpy(), test_probs, threshold)

    overfitting = max(0.0, train_metrics["recall_fall"] - test_metrics["recall_fall"])

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    model_id = f"xgboost-retrain-{timestamp}"
    artifact_path = MODELS_DIR / f"retrain-{timestamp}.pkl"

    payload = {
        "model": pipeline,
        "model_name": model_id,
        "threshold": threshold,
        "numeric_features": numeric_features,
        "categorical_features": CATEGORICAL_FEATURES,
        "gravity_alignment": "align_to_sisfall_reference_before_features",
    }
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    with open(artifact_path, "wb") as handle:
        pickle.dump(payload, handle)

    adl = run_adl_replay(model_path=artifact_path)

    result_metrics = {
        "recall": test_metrics["recall_fall"],
        "precision": test_metrics["precision_fall"],
        "f1": test_metrics["f1_fall"],
        "pr_auc": test_metrics["pr_auc"],
        "overfitting": overfitting,
        "threshold": threshold,
        "train_recall": train_metrics["recall_fall"],
        "test_recall": test_metrics["recall_fall"],
        "validation_recall": val_metrics["recall_fall"],
        "current_recall": current_recall,
        "previous_version": previous_version,
        "adl_false_positives": adl.adl_false_positives,
        "feedback": feedback_meta,
        "feature_windows": int(len(df)),
    }

    _register_candidate(
        model_id,
        artifact_path,
        threshold,
        result_metrics,
        feedback_meta,
    )

    metrics_doc = {
        "task": "T4.4",
        "model_id": model_id,
        "artifact_uri": str(artifact_path.relative_to(BACKEND_ROOT)),
        "algorithm": "XGBoost",
        "optuna_params": params,
        "train": train_metrics,
        "validation": val_metrics,
        "test": test_metrics,
        "overfitting": overfitting,
        "adl_replay": {
            "total_windows": adl.total_windows,
            "false_positives": adl.adl_false_positives,
        },
        "feedback": feedback_meta,
        "previous_version": previous_version,
        "current_recall": current_recall,
    }
    METRICS_OUT.parent.mkdir(parents=True, exist_ok=True)
    METRICS_OUT.write_text(json.dumps(metrics_doc, indent=2) + "\n", encoding="utf-8")

    return {
        "version": model_id,
        "algorithm": "XGBoost",
        "recall": result_metrics["recall"],
        "precision": result_metrics["precision"],
        "f1": result_metrics["f1"],
        "overfitting": overfitting,
        "artifact_uri": str(artifact_path.relative_to(BACKEND_ROOT)),
        "metrics": result_metrics,
    }


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--skip-feature-build",
        action="store_true",
        help="Reuse existing sisfall_windows_features.csv.gz",
    )
    args = parser.parse_args()

    print("=== T4.4 retrain: SisFall + feedback ===")
    result = run_retrain(skip_feature_build=args.skip_feature_build)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
