"""Retrain fall detector with gravity-aligned features — T2c.5.

Rebuilds SisFall window features (gravity alignment in pipeline), retrains
XGBoost with Optuna best hyperparameters, calibrates threshold on validation,
writes versioned metrics and replaces ``ml/models/model.pkl``.

Run from inference/:
    python -m ml.training.retrain_t2c5
"""

from __future__ import annotations

import json
import pickle
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.metrics import (
    average_precision_score,
    classification_report,
    confusion_matrix,
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

from ml.evaluation.adl_replay import (
    FIXTURES_DIR as ADL_FIXTURES_DIR,
    _discover_adl_fixtures,
    _predict_window,
    run_adl_replay,
)
from ml.pipeline.build_sisfall_window_features import build_window_features, write_outputs
from ml.training.train_model import (
    CATEGORICAL_FEATURES,
    GROUP_COL,
    NON_FEATURE_COLS,
    RANDOM_STATE,
    TARGET,
    build_preprocessor,
    find_best_threshold,
)

SISFALL_ROOT = BACKEND_ROOT / "data" / "raw" / "sisfall"
FEATURES_OUT = BACKEND_ROOT / "data" / "processed" / "sisfall" / "sisfall_windows_features.csv.gz"
MANIFEST_OUT = BACKEND_ROOT / "data" / "processed" / "sisfall" / "feature_manifest.json"
MODEL_OUT = BACKEND_ROOT / "ml" / "models" / "model.pkl"
METRICS_OUT = BACKEND_ROOT / "ml" / "artifacts" / "t2c5_metrics.json"
REGISTRY_OUT = BACKEND_ROOT / "ml" / "registry" / "registry.json"
OPTUNA_PARAMS = BACKEND_ROOT / "ml" / "artifacts" / "optuna_study.json"

MODEL_ID = "xgboost-v1.1.0-mobile-aligned"
MODEL_VERSION = "baseline-v1.1-mobile-aligned"


def _load_optuna_params() -> dict:
    if OPTUNA_PARAMS.exists():
        payload = json.loads(OPTUNA_PARAMS.read_text(encoding="utf-8"))
        return payload["best_params"]
    return {
        "n_estimators": 221,
        "max_depth": 8,
        "learning_rate": 0.0503,
        "subsample": 0.6687,
        "colsample_bytree": 0.8903,
    }


def _split_by_subject(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    numeric_features = [
        c for c in df.columns if c not in NON_FEATURE_COLS and c not in CATEGORICAL_FEATURES
    ]
    X = df[numeric_features]
    y = df[TARGET]
    groups = df[GROUP_COL]

    splitter = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=RANDOM_STATE)
    train_idx, test_idx = next(splitter.split(X, y, groups))
    train_df = df.iloc[train_idx]
    test_df = df.iloc[test_idx]

    splitter_val = GroupShuffleSplit(n_splits=1, test_size=0.15, random_state=RANDOM_STATE)
    train_sub_idx, val_idx = next(
        splitter_val.split(train_df[numeric_features], train_df[TARGET], train_df[GROUP_COL])
    )
    val_df = train_df.iloc[val_idx]
    train_df = train_df.iloc[train_sub_idx]
    return train_df, val_df, test_df


def _adl_gate_passes(model, numeric_features: list[str], threshold: float) -> bool:
    bundle = {
        "model": model,
        "numeric_features": numeric_features,
        "threshold": threshold,
    }
    for _, payload in _discover_adl_fixtures(ADL_FIXTURES_DIR):
        if _predict_window(payload, bundle)[0]:
            return False
    return True


def _find_threshold_with_adl_gate(
    model, x_val, y_val, numeric_features: list[str]
) -> float:
    probs = model.predict_proba(x_val)[:, 1]
    best_f1, best_thresh = 0.0, 0.5

    for thresh in np.arange(0.05, 0.95, 0.02):
        rounded = round(float(thresh), 2)
        if not _adl_gate_passes(model, numeric_features, rounded):
            continue
        preds = (probs >= rounded).astype(int)
        f1 = f1_score(y_val, preds, pos_label=1, zero_division=0)
        if f1 > best_f1:
            best_f1, best_thresh = f1, rounded

    if best_f1 > 0:
        return best_thresh
    return find_best_threshold(model, x_val, y_val)


def _metrics_at_threshold(y_true, probs, threshold: float) -> dict[str, float]:
    preds = (probs >= threshold).astype(int)
    return {
        "threshold": threshold,
        "precision_fall": float(precision_score(y_true, preds, pos_label=1, zero_division=0)),
        "recall_fall": float(recall_score(y_true, preds, pos_label=1, zero_division=0)),
        "f1_fall": float(f1_score(y_true, preds, pos_label=1, zero_division=0)),
        "pr_auc": float(average_precision_score(y_true, probs)),
        "false_positives": int(((preds == 1) & (y_true == 0)).sum()),
        "false_negatives": int(((preds == 0) & (y_true == 1)).sum()),
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

    print("=== T2c.5 retrain: gravity-aligned SisFall features ===")
    if args.skip_feature_build and FEATURES_OUT.exists():
        df = pd.read_csv(FEATURES_OUT)
        manifest = json.loads(MANIFEST_OUT.read_text(encoding="utf-8"))
        print(f"Reusing features: {len(df)} windows")
    else:
        df, manifest = build_window_features(SISFALL_ROOT)
        write_outputs(df, manifest, FEATURES_OUT, MANIFEST_OUT)
        print(f"Features: {len(df)} windows → {FEATURES_OUT}")

    numeric_features = manifest["feature_columns"]
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
    val_probs = pipeline.predict_proba(x_val)[:, 1]
    test_probs = pipeline.predict_proba(x_test)[:, 1]

    val_metrics = _metrics_at_threshold(y_val.to_numpy(), val_probs, threshold)
    test_metrics = _metrics_at_threshold(y_test.to_numpy(), test_probs, threshold)

    print("\nValidation metrics:")
    print(json.dumps(val_metrics, indent=2))
    print("\nTest metrics:")
    print(classification_report(y_test, (test_probs >= threshold).astype(int), target_names=["No caída", "Caída"]))
    print(confusion_matrix(y_test, (test_probs >= threshold).astype(int)))
    print(json.dumps(test_metrics, indent=2))

    payload = {
        "model": pipeline,
        "model_name": MODEL_VERSION,
        "threshold": threshold,
        "numeric_features": numeric_features,
        "categorical_features": CATEGORICAL_FEATURES,
        "gravity_alignment": "align_to_sisfall_reference_before_features",
    }
    MODEL_OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(MODEL_OUT, "wb") as handle:
        pickle.dump(payload, handle)
    print(f"\nModel saved → {MODEL_OUT}")

    adl = run_adl_replay(model_path=MODEL_OUT)
    print(f"ADL replay: {adl.total_windows} windows, false positives={adl.adl_false_positives}")

    metrics_doc = {
        "task": "T2c.5",
        "model_id": MODEL_ID,
        "model_version": MODEL_VERSION,
        "model_path": str(MODEL_OUT.relative_to(BACKEND_ROOT)),
        "gravity_alignment": payload["gravity_alignment"],
        "optuna_params": params,
        "validation": val_metrics,
        "test": test_metrics,
        "adl_replay": {
            "total_windows": adl.total_windows,
            "false_positives": adl.adl_false_positives,
            "windows": [w.__dict__ for w in adl.windows],
        },
        "feature_windows": int(len(df)),
    }
    METRICS_OUT.parent.mkdir(parents=True, exist_ok=True)
    METRICS_OUT.write_text(json.dumps(metrics_doc, indent=2) + "\n", encoding="utf-8")
    print(f"Metrics → {METRICS_OUT}")

    registry = json.loads(REGISTRY_OUT.read_text(encoding="utf-8"))
    registry["active"] = MODEL_ID
    registry["models"] = [
        m for m in registry.get("models", []) if m.get("id") != MODEL_ID
    ]
    registry["models"].append(
        {
            "id": MODEL_ID,
            "path": "ml/models/model.pkl",
            "algorithm": "XGBoost",
            "status": "ACTIVE",
            "metrics": {
                "pr_auc_test": test_metrics["pr_auc"],
                "recall_fall_test": test_metrics["recall_fall"],
                "f1_fall_test": test_metrics["f1_fall"],
                "precision_fall_test": test_metrics["precision_fall"],
                "adl_false_positives": adl.adl_false_positives,
            },
            "threshold": threshold,
            "trainedAt": "2026-07-14",
            "gravity_alignment": payload["gravity_alignment"],
        }
    )
    for model in registry["models"]:
        if model["id"] != MODEL_ID and model.get("status") == "ACTIVE":
            model["status"] = "CANDIDATE"
    REGISTRY_OUT.write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")
    print(f"Registry active → {MODEL_ID}")

    if adl.adl_false_positives > 0:
        raise SystemExit("ADL replay failed: false positives on normal activity")


if __name__ == "__main__":
    main()
