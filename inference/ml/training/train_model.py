"""
Script de entrenamiento del modelo de detección de caídas, sobre el
dataset generado por build_sisfall_window_features.py (una fila por ventana,
con features estadísticas de la señal + metadata del sujeto).

Diferencias clave respecto al pipeline con datos sintéticos:
  - Split por SUJETO (GroupShuffleSplit), no por fila al azar. Si el mismo
    subject_id aparece en train y en test, el modelo puede memorizar el
    "estilo de movimiento" de esa persona en vez de aprender el patrón
    general de caída, e infla las métricas de forma optimista.
  - Sin SMOTE: aquí las filas son resúmenes estadísticos de ensayos reales,
    no lecturas de sensor crudas, así que interpolar entre ellas es aún
    menos interpretable físicamente. Nos apoyamos en class_weight.
  - Selección de umbral en validation, métricas finales en test (una sola
    vez), igual que antes.
  - Flag --drop-shortcut-features: excluye las magnitudes maximas
    del entrenamiento, para probar por ablation si el
    modelo depende de un atajo simple de magnitud en vez de un patrón
    robusto (ver diagnostico.py, sección de feature importance).

Uso (desde la raíz de inference/):
    python -m ml.training.train_model --data data/processed/sisfall/sisfall_windows_features.csv.gz
    python -m ml.training.train_model --data data/processed/sisfall/sisfall_windows_features.csv.gz --drop-shortcut-features
Genera: ml/models/model.pkl (baseline) o ml/models/model_ablation.pkl (con el flag activado).
"""

import argparse
import pickle
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import GroupShuffleSplit, StratifiedGroupKFold, cross_val_score
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    f1_score,
    average_precision_score,
)
from sklearn.preprocessing import OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from xgboost import XGBClassifier

MODEL_PATH = "ml/models/model.pkl"
ABLATION_MODEL_PATH = "ml/models/model_ablation.pkl"
TARGET = "fall_event"
GROUP_COL = "subject_id"
# age_group se deja fuera del modelo a propósito: en SisFall, 14 de 15
# adultos mayores no simularon NINGUNA caída (por seguridad), así que esta
# columna codifica el sesgo del diseño experimental, no un patrón real de
# caída. Incluirla le daría al modelo un atajo falso ("mayor = no cae"),
# justo lo opuesto de lo que importa en un sistema real para esta población.
CATEGORICAL_FEATURES = []
# columnas que no son features (metadata / identificadores)
NON_FEATURE_COLS = {
    TARGET,
    GROUP_COL,
    "activity_code",
    "trial",
    "age_group",
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

# Features sospechosas de ser un "atajo" del modelo (ver diagnostico.py):
# AUC individual muy alto (>0.9) y acaparan >50% de la importancia total
# en XGBoost. Puede ser señal física real del impacto, o un artefacto de
# que SisFall usa caídas actuadas con picos más marcados que caídas reales.
SHORTCUT_FEATURES = ["acc1_magnitude_max", "gyro_magnitude_max", "acc_magnitude_max"]

RANDOM_STATE = 42


def load_and_prepare(path: str, drop_shortcut: bool = False) -> tuple:
    df = pd.read_csv(path)

    numeric_features = [
        c for c in df.columns
        if c not in NON_FEATURE_COLS and c not in CATEGORICAL_FEATURES
    ]

    if drop_shortcut:
        numeric_features = [f for f in numeric_features if f not in SHORTCUT_FEATURES]
        print(f"⚠️  Ablation: excluyendo {SHORTCUT_FEATURES}")

    features = numeric_features + CATEGORICAL_FEATURES
    X = df[features]
    y = df[TARGET].astype(int)
    groups = df[GROUP_COL]

    return X, y, groups, numeric_features


def build_preprocessor(numeric_features: list) -> ColumnTransformer:
    transformers = [("num", "passthrough", numeric_features)]
    if CATEGORICAL_FEATURES:
        transformers.append(("cat", OneHotEncoder(handle_unknown="ignore"), CATEGORICAL_FEATURES))
    return ColumnTransformer(transformers=transformers)


def group_split(X, y, groups, test_size, random_state):
    """Split que garantiza que ningún subject_id quede repartido entre
    los dos lados del split."""
    splitter = GroupShuffleSplit(n_splits=1, test_size=test_size, random_state=random_state)
    idx_a, idx_b = next(splitter.split(X, y, groups))
    return idx_a, idx_b


def find_best_threshold(model, X_val, y_val) -> float:
    """Busca el umbral que maximiza el F1 para la clase caída.
    Se llama solo con datos de VALIDATION, nunca con test."""
    probs = model.predict_proba(X_val)[:, 1]
    best_f1, best_thresh = 0, 0.5

    for thresh in np.arange(0.05, 0.95, 0.02):
        preds = (probs >= thresh).astype(int)
        f1 = f1_score(y_val, preds, pos_label=1, zero_division=0)
        if f1 > best_f1:
            best_f1, best_thresh = f1, thresh

    return round(best_thresh, 2)


def evaluate_on_test(name, model, X_test, y_test, threshold) -> tuple:
    probs = model.predict_proba(X_test)[:, 1]
    y_pred = (probs >= threshold).astype(int)
    pr_auc = average_precision_score(y_test, probs)

    print(f"\n{'='*40}")
    print(f"  {name}  (umbral fijado en validation: {threshold})")
    print('='*40)
    print(classification_report(y_test, y_pred, target_names=["No caída", "Caída"]))
    print("Matriz de confusión:")
    print(confusion_matrix(y_test, y_pred))
    print(f"PR-AUC (independiente del umbral): {pr_auc:.3f}")

    f1 = f1_score(y_test, y_pred, pos_label=1, zero_division=0)
    return f1, pr_auc


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--data",
        default="data/processed/sisfall/sisfall_windows_features.csv.gz",
        help="CSV generado por build_sisfall_window_features.py",
    )
    parser.add_argument("--drop-shortcut-features", action="store_true",
                         help="Excluye las features de magnitud maxima "
                              "para probar por ablation si el modelo depende "
                              "de un atajo. Guarda en model_ablation.pkl en "
                              "vez de model.pkl.")
    args = parser.parse_args()

    print("Cargando dataset...")
    X, y, groups, numeric_features = load_and_prepare(args.data, args.drop_shortcut_features)

    neg, pos = (y == 0).sum(), (y == 1).sum()
    ratio = neg / pos if pos else 1.0
    print(f"Total: {len(y)}  |  Caídas: {pos}  |  No caídas: {neg}  |  "
          f"Ratio: {ratio:.1f}  |  Sujetos: {groups.nunique()}")

    # --- Split por sujeto: train / validation / test ---
    train_idx, temp_idx = group_split(X, y, groups, test_size=0.3, random_state=RANDOM_STATE)
    X_train, y_train, g_train = X.iloc[train_idx], y.iloc[train_idx], groups.iloc[train_idx]
    X_temp, y_temp, g_temp = X.iloc[temp_idx], y.iloc[temp_idx], groups.iloc[temp_idx]

    val_idx, test_idx = group_split(X_temp, y_temp, g_temp, test_size=0.5, random_state=RANDOM_STATE)
    X_val, y_val = X_temp.iloc[val_idx], y_temp.iloc[val_idx]
    X_test, y_test = X_temp.iloc[test_idx], y_temp.iloc[test_idx]

    print(f"Train: {len(X_train)} ({g_train.nunique()} sujetos)  |  "
          f"Validation: {len(X_val)}  |  Test: {len(X_test)}")

    # verificación explícita de que no hay fuga de sujetos entre splits
    train_subjects = set(g_train)
    temp_subjects = set(g_temp)
    overlap = train_subjects & temp_subjects
    assert not overlap, f"¡Fuga de sujetos entre train y val/test!: {overlap}"

    preprocessor = build_preprocessor(numeric_features)

    rf_clf = RandomForestClassifier(
        n_estimators=300,
        max_depth=8,
        min_samples_leaf=3,
        class_weight="balanced",
        random_state=RANDOM_STATE,
        n_jobs=-1,
    )
    xgb_clf = XGBClassifier(
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

    models = {
        "Random Forest": Pipeline([("prep", preprocessor), ("clf", rf_clf)]),
        "XGBoost": Pipeline([("prep", preprocessor), ("clf", xgb_clf)]),
    }

    results = {}
    for name, pipeline in models.items():
        print(f"\nEntrenando {name}...")

        # CV estratificada Y agrupada: respeta las clases y nunca separa
        # a un mismo sujeto entre folds
        n_splits = min(5, g_train.nunique())
        cv = StratifiedGroupKFold(n_splits=n_splits, shuffle=True, random_state=RANDOM_STATE)
        cv_scores = cross_val_score(
            pipeline, X_train, y_train, groups=g_train, cv=cv, scoring="average_precision"
        )
        print(f"  PR-AUC en CV agrupada (train, {n_splits} folds): "
              f"{cv_scores.mean():.3f} ± {cv_scores.std():.3f}")

        pipeline.fit(X_train, y_train)

        threshold = find_best_threshold(pipeline, X_val, y_val)
        f1, pr_auc = evaluate_on_test(name, pipeline, X_test, y_test, threshold)
        results[name] = (pipeline, f1, pr_auc, threshold)

    best_name = max(results, key=lambda k: results[k][2])
    best_model, best_f1, best_pr_auc, best_threshold = results[best_name]
    print(f"\n✅ Mejor modelo: {best_name} "
          f"(PR-AUC: {best_pr_auc:.3f}, F1 caída: {best_f1:.3f})")

    payload = {
        "model": best_model,
        "model_name": best_name,
        "threshold": best_threshold,
        "numeric_features": numeric_features,
        "categorical_features": CATEGORICAL_FEATURES,
        "dropped_shortcut_features": args.drop_shortcut_features,
    }

    out_path = ABLATION_MODEL_PATH if args.drop_shortcut_features else MODEL_PATH
    with open(out_path, "wb") as f:
        pickle.dump(payload, f)

    print(f"Modelo guardado en {out_path}")


if __name__ == "__main__":
    main()
