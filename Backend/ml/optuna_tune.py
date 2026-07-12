"""
SL-42 / T2.2 — Optuna sobre el mejor ensemble + guardar modelo optimizado.

Usa el resultado de compare_ensembles.json para elegir el algoritmo base
y optimiza hiperparámetros maximizando PR-AUC en validation (split por sujeto).

Salida:
  - ml/model_tuned.pkl
  - ml/artifacts/optuna_study.json
  - Actualiza ml/registry/registry.json (CANDIDATE)
"""

from __future__ import annotations

import argparse
import json
import pickle
from pathlib import Path

import numpy as np
import optuna
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.metrics import average_precision_score, f1_score
from sklearn.model_selection import StratifiedGroupKFold
from sklearn.pipeline import Pipeline
from xgboost import XGBClassifier

from train_model import (
    GROUP_COL,
    RANDOM_STATE,
    TARGET,
    build_preprocessor,
    find_best_threshold,
    group_split,
    load_and_prepare,
)

ARTIFACTS_DIR = Path("ml/artifacts")
COMPARISON_PATH = ARTIFACTS_DIR / "ensemble_comparison.json"
STUDY_PATH = ARTIFACTS_DIR / "optuna_study.json"
TUNED_MODEL_PATH = Path("ml/model_tuned.pkl")
REGISTRY_PATH = Path("ml/registry/registry.json")


def _load_best_algorithm() -> str:
    if COMPARISON_PATH.exists():
        data = json.loads(COMPARISON_PATH.read_text(encoding="utf-8"))
        return data.get("best_model_loso", "XGBoost")
    return "XGBoost"


def _build_clf(name: str, trial: optuna.Trial, ratio: float):
    if name == "Random Forest":
        return RandomForestClassifier(
            n_estimators=trial.suggest_int("n_estimators", 100, 500),
            max_depth=trial.suggest_int("max_depth", 4, 12),
            min_samples_leaf=trial.suggest_int("min_samples_leaf", 1, 8),
            class_weight="balanced",
            random_state=RANDOM_STATE,
            n_jobs=-1,
        )
    if name == "Gradient Boosting":
        return GradientBoostingClassifier(
            n_estimators=trial.suggest_int("n_estimators", 100, 500),
            max_depth=trial.suggest_int("max_depth", 2, 8),
            learning_rate=trial.suggest_float("learning_rate", 0.01, 0.2, log=True),
            subsample=trial.suggest_float("subsample", 0.6, 1.0),
            random_state=RANDOM_STATE,
        )
    return XGBClassifier(
        n_estimators=trial.suggest_int("n_estimators", 100, 500),
        max_depth=trial.suggest_int("max_depth", 2, 8),
        learning_rate=trial.suggest_float("learning_rate", 0.01, 0.2, log=True),
        subsample=trial.suggest_float("subsample", 0.6, 1.0),
        colsample_bytree=trial.suggest_float("colsample_bytree", 0.6, 1.0),
        scale_pos_weight=ratio,
        random_state=RANDOM_STATE,
        eval_metric="aucpr",
        verbosity=0,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", default="data/processed/sisfall/sisfall_windows_features.csv.gz")
    parser.add_argument("--trials", type=int, default=30)
    parser.add_argument("--algorithm", default=None, help="Override best from SL-41")
    args = parser.parse_args()

    algorithm = args.algorithm or _load_best_algorithm()
    print(f"Algoritmo base: {algorithm}")

    X, y, groups, numeric_features = load_and_prepare(args.data)
    neg, pos = (y == 0).sum(), (y == 1).sum()
    ratio = neg / pos if pos else 1.0

    train_idx, temp_idx = group_split(X, y, groups, test_size=0.3, random_state=RANDOM_STATE)
    X_train, y_train, g_train = X.iloc[train_idx], y.iloc[train_idx], groups.iloc[train_idx]
    X_temp, y_temp, g_temp = X.iloc[temp_idx], y.iloc[temp_idx], groups.iloc[temp_idx]
    val_idx, test_idx = group_split(X_temp, y_temp, g_temp, test_size=0.5, random_state=RANDOM_STATE)
    X_val, y_val = X_temp.iloc[val_idx], y_temp.iloc[val_idx]
    X_test, y_test = X_temp.iloc[test_idx], y_temp.iloc[test_idx]

    preprocessor = build_preprocessor(numeric_features)
    n_splits = min(5, g_train.nunique())
    cv = StratifiedGroupKFold(n_splits=n_splits, shuffle=True, random_state=RANDOM_STATE)

    def objective(trial: optuna.Trial) -> float:
        clf = _build_clf(algorithm, trial, ratio)
        pipeline = Pipeline([("prep", preprocessor), ("clf", clf)])
        scores = []
        for tr, va in cv.split(X_train, y_train, g_train):
            pipeline.fit(X_train.iloc[tr], y_train.iloc[tr])
            probs = pipeline.predict_proba(X_train.iloc[va])[:, 1]
            scores.append(average_precision_score(y_train.iloc[va], probs))
        return float(np.mean(scores))

    study = optuna.create_study(direction="maximize", study_name="sentilife-fall-detection")
    study.optimize(objective, n_trials=args.trials, show_progress_bar=True)

    best_clf = _build_clf(algorithm, optuna.trial.FixedTrial(study.best_params), ratio)
    best_pipeline = Pipeline([("prep", preprocessor), ("clf", best_clf)])
    best_pipeline.fit(X_train, y_train)
    threshold = find_best_threshold(best_pipeline, X_val, y_val)

    probs_test = best_pipeline.predict_proba(X_test)[:, 1]
    preds_test = (probs_test >= threshold).astype(int)
    pr_auc_test = average_precision_score(y_test, probs_test)
    f1_test = f1_score(y_test, preds_test, pos_label=1, zero_division=0)

    payload = {
        "model": best_pipeline,
        "model_name": algorithm,
        "threshold": threshold,
        "numeric_features": numeric_features,
        "categorical_features": [],
        "dropped_shortcut_features": False,
        "optuna_best_params": study.best_params,
        "optuna_best_cv_pr_auc": study.best_value,
    }
    with open(TUNED_MODEL_PATH, "wb") as f:
        pickle.dump(payload, f)

    study_report = {
        "task": "SL-42 / T2.2",
        "algorithm": algorithm,
        "n_trials": args.trials,
        "best_params": study.best_params,
        "best_cv_pr_auc": round(study.best_value, 4),
        "test_pr_auc": round(pr_auc_test, 4),
        "test_f1_fall": round(f1_test, 4),
        "threshold": threshold,
        "model_path": str(TUNED_MODEL_PATH),
    }
    ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
    STUDY_PATH.write_text(json.dumps(study_report, indent=2), encoding="utf-8")

    # Actualizar registry con CANDIDATE
    REGISTRY_PATH.parent.mkdir(parents=True, exist_ok=True)
    registry = {
        "active": "xgboost-v1.0.0",
        "models": [
            {
                "id": "xgboost-v1.0.0",
                "path": "ml/model.pkl",
                "algorithm": "XGBoost",
                "status": "ACTIVE",
                "metrics": {"pr_auc_test": 0.901, "recall_fall_test": 0.832},
                "trainedAt": "2026-07-12",
            },
            {
                "id": "tuned-v1.0.0",
                "path": str(TUNED_MODEL_PATH),
                "algorithm": algorithm,
                "status": "CANDIDATE",
                "metrics": {
                    "pr_auc_test": round(pr_auc_test, 4),
                    "test_f1_fall": round(f1_test, 4),
                    "cv_pr_auc": round(study.best_value, 4),
                },
                "trainedAt": "2026-07-12",
                "optuna_params": study.best_params,
            },
        ],
    }
    REGISTRY_PATH.write_text(json.dumps(registry, indent=2), encoding="utf-8")

    print(f"\n✅ Optuna completado: CV PR-AUC={study.best_value:.3f}")
    print(f"   Test PR-AUC={pr_auc_test:.3f}  F1 caída={f1_test:.3f}")
    print(f"   Modelo guardado: {TUNED_MODEL_PATH}")
    print(f"   Registry actualizado: {REGISTRY_PATH}")


if __name__ == "__main__":
    main()
