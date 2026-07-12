"""
SL-41 / T2.1 — Comparativa de ensembles con validación por sujeto.

Compara Random Forest, Gradient Boosting y XGBoost usando:
  - StratifiedGroupKFold en train (PR-AUC)
  - Split por sujeto train/val/test
  - Leave-One-Subject-Out (LOSO) agregado

Salida: ml/artifacts/ensemble_comparison.json
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.metrics import (
    average_precision_score,
    classification_report,
    confusion_matrix,
    f1_score,
)
from sklearn.model_selection import (
    GroupShuffleSplit,
    LeaveOneGroupOut,
    StratifiedGroupKFold,
    cross_val_score,
)
from sklearn.pipeline import Pipeline
from xgboost import XGBClassifier

from train_model import (
    CATEGORICAL_FEATURES,
    GROUP_COL,
    NON_FEATURE_COLS,
    RANDOM_STATE,
    TARGET,
    build_preprocessor,
    find_best_threshold,
    group_split,
    load_and_prepare,
)

ARTIFACTS_DIR = Path("ml/artifacts")
OUTPUT_PATH = ARTIFACTS_DIR / "ensemble_comparison.json"


def _make_models(ratio: float) -> dict[str, Pipeline]:
    preprocessor_placeholder = build_preprocessor([])

    rf = RandomForestClassifier(
        n_estimators=300,
        max_depth=8,
        min_samples_leaf=3,
        class_weight="balanced",
        random_state=RANDOM_STATE,
        n_jobs=-1,
    )
    gb = GradientBoostingClassifier(
        n_estimators=80,
        max_depth=3,
        learning_rate=0.1,
        subsample=0.8,
        random_state=RANDOM_STATE,
    )
    xgb = XGBClassifier(
        n_estimators=300,
        max_depth=4,
        learning_rate=0.05,
        subsample=0.8,
        colsample_bytree=0.8,
        scale_pos_weight=ratio,
        random_state=RANDOM_STATE,
        eval_metric="aucpr",
        verbosity=0,
    )
    return {
        "Random Forest": rf,
        "Gradient Boosting": gb,
        "XGBoost": xgb,
    }


def _evaluate_test(name: str, pipeline: Pipeline, X_test, y_test, threshold: float) -> dict:
    probs = pipeline.predict_proba(X_test)[:, 1]
    preds = (probs >= threshold).astype(int)
    pr_auc = average_precision_score(y_test, probs)
    f1 = f1_score(y_test, preds, pos_label=1, zero_division=0)
    recall = (preds[y_test == 1] == 1).mean() if (y_test == 1).any() else 0.0
    cm = confusion_matrix(y_test, preds).tolist()
    return {
        "model": name,
        "threshold": threshold,
        "pr_auc_test": round(pr_auc, 4),
        "f1_fall_test": round(f1, 4),
        "recall_fall_test": round(float(recall), 4),
        "confusion_matrix": cm,
        "classification_report": classification_report(
            y_test, preds, target_names=["No caída", "Caída"], output_dict=True
        ),
    }


def _run_loso(name: str, clf, preprocessor, X, y, groups, ratio: float) -> dict:
    logo = LeaveOneGroupOut()
    all_y_true, all_probs = [], []
    n_subjects = groups.nunique()

    for i, (train_idx, test_idx) in enumerate(logo.split(X, y, groups), 1):
        if i % 10 == 0 or i == n_subjects:
            print(f"    LOSO {name}: {i}/{n_subjects}", flush=True)
        X_train, X_test = X.iloc[train_idx], X.iloc[test_idx]
        y_train = y.iloc[train_idx]

        if name == "XGBoost":
            model = XGBClassifier(
                n_estimators=300, max_depth=4, learning_rate=0.05,
                subsample=0.8, colsample_bytree=0.8, scale_pos_weight=ratio,
                random_state=RANDOM_STATE, eval_metric="aucpr", verbosity=0,
            )
        elif name == "Gradient Boosting":
            model = GradientBoostingClassifier(
                n_estimators=80, max_depth=3, learning_rate=0.1,
                subsample=0.8, random_state=RANDOM_STATE,
            )
        else:
            model = RandomForestClassifier(
                n_estimators=300, max_depth=8, min_samples_leaf=3,
                class_weight="balanced", random_state=RANDOM_STATE, n_jobs=-1,
            )

        pipeline = Pipeline([("prep", preprocessor), ("clf", model)])
        pipeline.fit(X_train, y_train)
        probs = pipeline.predict_proba(X_test)[:, 1]
        all_y_true.extend(y.iloc[test_idx].tolist())
        all_probs.extend(probs.tolist())

    preds = (np.array(all_probs) >= 0.5).astype(int)
    return {
        "pr_auc_loso": round(average_precision_score(all_y_true, all_probs), 4),
        "f1_fall_loso": round(f1_score(all_y_true, preds, pos_label=1), 4),
        "confusion_matrix_loso": confusion_matrix(all_y_true, preds).tolist(),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--data",
        default="data/processed/sisfall/sisfall_windows_features.csv.gz",
    )
    parser.add_argument(
        "--quick",
        action="store_true",
        help="Solo CV+test; LOSO solo en el mejor modelo (más rápido)",
    )
    args = parser.parse_args()

    print("Cargando dataset...")
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
    models = _make_models(ratio)
    n_splits = min(5, g_train.nunique())
    cv = StratifiedGroupKFold(n_splits=n_splits, shuffle=True, random_state=RANDOM_STATE)

    results = []
    for name, clf in models.items():
        print(f"\n=== {name} ===")
        pipeline = Pipeline([("prep", preprocessor), ("clf", clf)])

        cv_scores = cross_val_score(
            pipeline, X_train, y_train, groups=g_train, cv=cv, scoring="average_precision"
        )
        print(f"  CV PR-AUC: {cv_scores.mean():.3f} ± {cv_scores.std():.3f}")

        pipeline.fit(X_train, y_train)
        threshold = find_best_threshold(pipeline, X_val, y_val)
        test_metrics = _evaluate_test(name, pipeline, X_test, y_test, threshold)
        loso_metrics = (
            {"pr_auc_loso": None, "f1_fall_loso": None, "confusion_matrix_loso": None}
            if args.quick
            else _run_loso(name, clf, preprocessor, X, y, groups, ratio)
        )

        overfit_gap = round((cv_scores.mean() - test_metrics["pr_auc_test"]) * 100, 2)
        entry = {
            **test_metrics,
            **loso_metrics,
            "cv_pr_auc_mean": round(cv_scores.mean(), 4),
            "cv_pr_auc_std": round(cv_scores.std(), 4),
            "overfitting_gap_pp": overfit_gap,
            "overfitting_ok": overfit_gap < 5.0,
        }
        results.append(entry)
        print(f"  Test PR-AUC: {test_metrics['pr_auc_test']:.3f}")
        if loso_metrics["pr_auc_loso"] is not None:
            print(f"  LOSO PR-AUC: {loso_metrics['pr_auc_loso']:.3f}")
        print(f"  Overfitting: {overfit_gap} pp")

    best = max(results, key=lambda r: r["pr_auc_test"])
    if args.quick:
        print(f"\nLOSO solo para el mejor ({best['model']})...")
        best_loso = _run_loso(
            best["model"],
            models[best["model"]],
            preprocessor,
            X,
            y,
            groups,
            ratio,
        )
        for entry in results:
            if entry["model"] == best["model"]:
                entry.update(best_loso)
        best = max(results, key=lambda r: r.get("pr_auc_loso") or r["pr_auc_test"])

    report = {
        "task": "SL-41 / T2.1",
        "dataset": args.data,
        "n_windows": len(y),
        "n_subjects": int(groups.nunique()),
        "split": "GroupShuffleSplit 70/15/15 + LOSO",
        "models": results,
        "best_model_loso": best["model"],
        "best_pr_auc_loso": best.get("pr_auc_loso") or best["pr_auc_test"],
    }

    ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\n✅ Comparativa guardada en {OUTPUT_PATH}")
    print(f"   Mejor modelo: {best['model']} PR-AUC LOSO={best.get('pr_auc_loso')}")


if __name__ == "__main__":
    main()
