"""
T4.2 / ML-15 — CNN 1D sobre ventanas crudas vs mejor ensemble (XGBoost).

Split idéntico a compare_ensembles.py / train_model.py:
  GroupShuffleSplit 70/15/15 + LOSO agregado por subject_id.

Salidas:
  ml/models/cnn1d-v1.0.0.keras
  ml/artifacts/cnn1d_comparison.json
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import (
    average_precision_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)
from sklearn.model_selection import LeaveOneGroupOut, StratifiedGroupKFold
from sklearn.pipeline import Pipeline
from xgboost import XGBClassifier

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

from ml.training.raw_windows import align_with_feature_csv, load_raw_windows
from ml.training.train_model import (
    RANDOM_STATE,
    build_preprocessor,
    find_best_threshold,
    group_split,
    load_and_prepare,
)

ARTIFACTS_DIR = Path("ml/artifacts")
MODEL_PATH = Path("ml/models/cnn1d-v1.0.0.keras")
OUTPUT_PATH = ARTIFACTS_DIR / "cnn1d_comparison.json"
FEATURES_CSV = Path("data/processed/sisfall/sisfall_windows_features.csv.gz")
ENSEMBLE_BASELINE = ARTIFACTS_DIR / "ensemble_comparison.json"


def _sanitize(obj):
    if isinstance(obj, dict):
        return {k: _sanitize(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_sanitize(v) for v in obj]
    if isinstance(obj, (np.integer,)):
        return int(obj)
    if isinstance(obj, (np.floating,)):
        return float(obj)
    if isinstance(obj, (np.bool_, bool)):
        return bool(obj)
    return obj


def _standardize(train: np.ndarray, *others: np.ndarray) -> tuple[np.ndarray, ...]:
    mean = train.mean(axis=(0, 1), keepdims=True)
    std = train.std(axis=(0, 1), keepdims=True)
    std = np.where(std < 1e-6, 1.0, std)
    return tuple((arr - mean) / std for arr in (train, *others))


def _build_cnn1d(input_shape: tuple[int, int]):
    import tensorflow as tf

    tf.random.set_seed(RANDOM_STATE)
    reg = tf.keras.regularizers.l2(1e-4)
    inputs = tf.keras.Input(shape=input_shape)
    x = tf.keras.layers.Conv1D(32, 5, padding="same", activation="relu", kernel_regularizer=reg)(inputs)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.MaxPooling1D(2)(x)
    x = tf.keras.layers.Conv1D(64, 3, padding="same", activation="relu", kernel_regularizer=reg)(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.GlobalAveragePooling1D()(x)
    x = tf.keras.layers.Dense(32, activation="relu", kernel_regularizer=reg)(x)
    x = tf.keras.layers.Dropout(0.4)(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid")(x)
    model = tf.keras.Model(inputs, outputs)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=5e-4),
        loss="binary_crossentropy",
        metrics=[tf.keras.metrics.AUC(curve="PR", name="pr_auc")],
    )
    return model


def _class_weight(y: np.ndarray) -> dict[int, float]:
    neg, pos = (y == 0).sum(), (y == 1).sum()
    if pos == 0:
        return {0: 1.0, 1: 1.0}
    return {0: 1.0, 1: float(neg / pos)}


def _fit_cnn(model, X_train, y_train, X_val, y_val, *, epochs: int, batch_size: int):
    import tensorflow as tf

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_pr_auc",
            mode="max",
            patience=5,
            restore_best_weights=True,
        )
    ]
    model.fit(
        X_train,
        y_train,
        validation_data=(X_val, y_val),
        epochs=epochs,
        batch_size=batch_size,
        class_weight=_class_weight(y_train),
        callbacks=callbacks,
        verbose=0,
    )
    return model


def _predict_proba(model, X: np.ndarray) -> np.ndarray:
    return model.predict(X, verbose=0).reshape(-1)


def _metrics(y_true, probs, threshold: float) -> dict:
    preds = (probs >= threshold).astype(int)
    return {
        "threshold": threshold,
        "pr_auc": round(float(average_precision_score(y_true, probs)), 4),
        "precision_fall": round(
            float(precision_score(y_true, preds, pos_label=1, zero_division=0)), 4
        ),
        "recall_fall": round(
            float(recall_score(y_true, preds, pos_label=1, zero_division=0)), 4
        ),
        "f1_fall": round(float(f1_score(y_true, preds, pos_label=1, zero_division=0)), 4),
        "confusion_matrix": confusion_matrix(y_true, preds).tolist(),
        "classification_report": classification_report(
            y_true, preds, target_names=["No caída", "Caída"], output_dict=True
        ),
    }


def find_best_threshold_from_probs(probs: np.ndarray, y_val: np.ndarray) -> float:
    best_f1, best_thresh = 0.0, 0.5
    for thresh in np.arange(0.05, 0.95, 0.02):
        preds = (probs >= thresh).astype(int)
        f1 = f1_score(y_val, preds, pos_label=1, zero_division=0)
        if f1 > best_f1:
            best_f1, best_thresh = f1, thresh
    return round(float(best_thresh), 2)


def _subject_split(y: np.ndarray, groups: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    index = pd.DataFrame({"idx": np.arange(len(y))})
    y_series = pd.Series(y)
    groups_series = pd.Series(groups)

    train_idx, temp_idx = group_split(index, y_series, groups_series, 0.3, RANDOM_STATE)
    temp_groups = groups_series.iloc[temp_idx]
    val_idx_rel, test_idx_rel = group_split(
        index.iloc[temp_idx], y_series.iloc[temp_idx], temp_groups, 0.5, RANDOM_STATE
    )
    val_idx = temp_idx[val_idx_rel]
    test_idx = temp_idx[test_idx_rel]

    train_subjects = set(groups_series.iloc[train_idx])
    assert not (train_subjects & set(groups_series.iloc[val_idx]))
    assert not (train_subjects & set(groups_series.iloc[test_idx]))
    return train_idx, val_idx, test_idx


def _cv_pr_auc_cnn(
    X_train: np.ndarray,
    y_train: np.ndarray,
    groups_train: np.ndarray,
    *,
    epochs: int,
    batch_size: int,
) -> float:
    n_splits = min(5, len(np.unique(groups_train)))
    cv = StratifiedGroupKFold(n_splits=n_splits, shuffle=True, random_state=RANDOM_STATE)
    scores = []
    for fold_train, fold_val in cv.split(X_train, y_train, groups_train):
        X_tr, X_va = X_train[fold_train], X_train[fold_val]
        y_tr, y_va = y_train[fold_train], y_train[fold_val]
        X_tr_s, X_va_s = _standardize(X_tr, X_va)
        model = _build_cnn1d((X_train.shape[1], X_train.shape[2]))
        model = _fit_cnn(model, X_tr_s, y_tr, X_va_s, y_va, epochs=epochs, batch_size=batch_size)
        probs = _predict_proba(model, X_va_s)
        scores.append(average_precision_score(y_va, probs))
    return float(np.mean(scores))


def _cv_pr_auc_xgb(pipeline, X_train, y_train, groups_train) -> float:
    n_splits = min(5, groups_train.nunique())
    cv = StratifiedGroupKFold(n_splits=n_splits, shuffle=True, random_state=RANDOM_STATE)
    from sklearn.model_selection import cross_val_score

    scores = cross_val_score(
        pipeline, X_train, y_train, groups=groups_train, cv=cv, scoring="average_precision"
    )
    return float(scores.mean())


def _run_loso(X: np.ndarray, y: np.ndarray, groups: np.ndarray, *, epochs: int) -> dict:
    logo = LeaveOneGroupOut()
    all_y, all_probs = [], []
    n_subjects = len(np.unique(groups))

    for i, (train_idx, test_idx) in enumerate(logo.split(X, y, groups), 1):
        if i % 5 == 0 or i == n_subjects:
            print(f"    LOSO CNN1D: {i}/{n_subjects}", flush=True)
        X_train, X_test = X[train_idx], X[test_idx]
        y_train = y[train_idx]
        X_tr, X_te = _standardize(X_train, X_test)
        split = max(1, int(len(X_tr) * 0.1))
        model = _build_cnn1d((X.shape[1], X.shape[2]))
        model = _fit_cnn(
            model,
            X_tr[:-split],
            y_train[:-split],
            X_tr[-split:],
            y_train[-split:],
            epochs=epochs,
            batch_size=128,
        )
        all_y.extend(y[test_idx].tolist())
        all_probs.extend(_predict_proba(model, X_te).tolist())

    preds = (np.array(all_probs) >= 0.5).astype(int)
    return {
        "pr_auc_loso": round(float(average_precision_score(all_y, all_probs)), 4),
        "f1_fall_loso": round(float(f1_score(all_y, preds, pos_label=1)), 4),
        "confusion_matrix_loso": confusion_matrix(all_y, preds).tolist(),
    }


def _load_xgboost_baseline(
    X_feat: pd.DataFrame,
    y: pd.Series,
    groups: pd.Series,
    train_idx: np.ndarray,
    val_idx: np.ndarray,
    test_idx: np.ndarray,
    numeric_features: list[str],
) -> dict:
    X_train, y_train = X_feat.iloc[train_idx], y.iloc[train_idx]
    X_val, y_val = X_feat.iloc[val_idx], y.iloc[val_idx]
    X_test, y_test = X_feat.iloc[test_idx], y.iloc[test_idx]

    neg, pos = (y_train == 0).sum(), (y_train == 1).sum()
    ratio = neg / pos if pos else 1.0
    pipeline = Pipeline(
        [
            ("prep", build_preprocessor(numeric_features)),
            (
                "clf",
                XGBClassifier(
                    n_estimators=300,
                    max_depth=4,
                    learning_rate=0.05,
                    subsample=0.8,
                    colsample_bytree=0.8,
                    scale_pos_weight=ratio,
                    random_state=RANDOM_STATE,
                    eval_metric="aucpr",
                    verbosity=0,
                ),
            ),
        ]
    )
    pipeline.fit(X_train, y_train)
    threshold = find_best_threshold(pipeline, X_val, y_val)
    test_probs = pipeline.predict_proba(X_test)[:, 1]
    test_metrics = _metrics(y_test.to_numpy(), test_probs, threshold)
    cv_pr = _cv_pr_auc_xgb(pipeline, X_train, y_train, groups.iloc[train_idx])
    test_metrics["cv_pr_auc_mean"] = round(cv_pr, 4)
    test_metrics["overfitting_gap_pp"] = round((cv_pr - test_metrics["pr_auc"]) * 100, 2)
    test_metrics["overfitting_ok"] = test_metrics["overfitting_gap_pp"] < 5.0
    return test_metrics


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="data/raw/sisfall")
    parser.add_argument("--data", default=str(FEATURES_CSV))
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--loso-epochs", type=int, default=12)
    parser.add_argument("--batch-size", type=int, default=256)
    parser.add_argument("--rebuild-cache", action="store_true")
    parser.add_argument("--skip-loso", action="store_true")
    args = parser.parse_args()

    print("Cargando ventanas crudas SisFall...")
    X_raw, y_raw, groups_raw = load_raw_windows(args.root, rebuild=args.rebuild_cache)
    X_raw, y_raw, groups_raw = align_with_feature_csv(
        X_raw, y_raw, groups_raw, args.data
    )
    y = y_raw.astype(int)
    groups = groups_raw

    X_feat, y_feat, groups_feat, numeric_features = load_and_prepare(args.data)
    assert len(y_feat) == len(y), "Feature CSV and raw windows length mismatch"

    print(f"Ventanas: {len(y)} | Caídas: {y.sum()} | Sujetos: {len(np.unique(groups))}")

    train_idx, val_idx, test_idx = _subject_split(y, groups)

    X_train, X_val, X_test = X_raw[train_idx], X_raw[val_idx], X_raw[test_idx]
    y_train, y_val, y_test = y[train_idx], y[val_idx], y[test_idx]

    X_train, X_val, X_test = _standardize(X_train, X_val, X_test)

    print("\n=== CNN 1D ===")
    model = _build_cnn1d((X_train.shape[1], X_train.shape[2]))
    model = _fit_cnn(
        model,
        X_train,
        y_train,
        X_val,
        y_val,
        epochs=args.epochs,
        batch_size=args.batch_size,
    )

    threshold = find_best_threshold_from_probs(_predict_proba(model, X_val), y_val)
    test_probs = _predict_proba(model, X_test)

    cv_pr = _cv_pr_auc_cnn(
        X_raw[train_idx], y_train, groups[train_idx], epochs=min(args.epochs, 15), batch_size=args.batch_size
    )
    test_metrics = _metrics(y_test, test_probs, threshold)
    overfit_gap = round((cv_pr - test_metrics["pr_auc"]) * 100, 2)
    test_metrics["cv_pr_auc_mean"] = round(cv_pr, 4)
    test_metrics["overfitting_gap_pp"] = overfit_gap
    test_metrics["overfitting_ok"] = overfit_gap < 5.0

    print(f"  Test PR-AUC: {test_metrics['pr_auc']:.3f}")
    print(f"  Recall caída: {test_metrics['recall_fall']:.3f}")
    print(f"  Overfitting: {overfit_gap} pp")

    loso_metrics = (
        {"pr_auc_loso": None, "f1_fall_loso": None}
        if args.skip_loso
        else _run_loso(X_raw, y, groups, epochs=args.loso_epochs)
    )

    xgb_metrics = _load_xgboost_baseline(
        X_feat, y_feat, groups_feat, train_idx, val_idx, test_idx, numeric_features
    )

    baseline_loso = None
    if ENSEMBLE_BASELINE.exists():
        baseline_loso = json.loads(ENSEMBLE_BASELINE.read_text())["best_pr_auc_loso"]

    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    model.save(MODEL_PATH)

    report = {
        "task": "T4.2 / ML-15",
        "model_type": "CNN1D",
        "model_path": str(MODEL_PATH),
        "raw_window_shape": [125, 6],
        "split": "GroupShuffleSplit 70/15/15 + LOSO",
        "n_windows": int(len(y)),
        "n_subjects": int(len(np.unique(groups))),
        "cnn1d": {**test_metrics, **loso_metrics},
        "xgboost_same_split": xgb_metrics,
        "ensemble_baseline_loso": baseline_loso,
        "winner_loso": (
            "CNN1D"
            if loso_metrics.get("pr_auc_loso")
            and baseline_loso
            and loso_metrics["pr_auc_loso"] > baseline_loso
            else "XGBoost"
        ),
    }

    ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(
        json.dumps(_sanitize(report), indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"\n✅ Modelo guardado en {MODEL_PATH}")
    print(f"✅ Comparativa guardada en {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
