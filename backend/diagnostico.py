"""
Diagnóstico rápido para entender el rendimiento del modelo guardado:

  1. Feature importance del modelo ya guardado en model.pkl (segundos)
  2. Validación Leave-One-Subject-Out (LOSO): entrena dejando UN sujeto
     entero afuera cada vez, y evalúa solo en ese sujeto. Se repite para
     los 38 sujetos. Da una estimación mucho más honesta de cómo
     generalizaría el modelo a una persona que nunca vio, que un solo
     split 70/15/15.

     IMPORTANTE: el LOSO usa el MISMO conjunto de features y el MISMO
     tipo de modelo (RF o XGBoost, con los mismos hiperparámetros que
     train_model.py) que el .pkl que le pasaste en --model. Si entrenaste
     con --drop-shortcut-features, el LOSO también se entrena sin esas
     columnas. Antes esto no era así: el LOSO recalculaba features desde
     el CSV ignorando el modelo cargado, así que baseline y ablation daban
     siempre el mismo resultado (bug corregido).

  3. Desglose de accuracy/recall por age_group (adult vs elderly), tanto
     en el split simple como en el LOSO agregado. Con solo 973 ensayos de
     mayores y 75 caídas entre ellos, el número agregado (38 sujetos,
     mayoría joven) puede ocultar que el modelo funciona peor justo en
     la población que más importa para un sistema real.

Uso:
    python diagnostico.py --data data/sisfall_dataset.csv --model model.pkl
    python diagnostico.py --data data/sisfall_dataset.csv --model model_ablation.pkl
"""

import argparse
import pickle
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import LeaveOneGroupOut
from sklearn.metrics import average_precision_score, f1_score, confusion_matrix, recall_score
from sklearn.preprocessing import OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from xgboost import XGBClassifier

TARGET = "fall_event"
GROUP_COL = "subject_id"
AGE_COL = "age_group"
# igual que en train_model.py: age_group fuera del modelo por el sesgo del
# dataset (14/15 adultos mayores sin ningún ensayo de caída)
CATEGORICAL_FEATURES = []
NON_FEATURE_COLS = {TARGET, GROUP_COL, "activity_code", "trial", "age_group"}

RANDOM_STATE = 42


def print_feature_importance(payload: dict):
    print("=" * 50)
    print("1) FEATURE IMPORTANCE DEL MODELO GUARDADO")
    print("=" * 50)

    pipeline = payload["model"]
    clf = pipeline.named_steps["clf"]
    preprocessor = pipeline.named_steps["prep"]

    num_names = payload["numeric_features"]
    if CATEGORICAL_FEATURES and "cat" in preprocessor.named_transformers_:
        cat_names = list(
            preprocessor.named_transformers_["cat"].get_feature_names_out(CATEGORICAL_FEATURES)
        )
    else:
        cat_names = []
    all_names = num_names + cat_names

    if not hasattr(clf, "feature_importances_"):
        print(f"  El modelo ({payload['model_name']}) no expone feature_importances_ "
              f"directamente (revisa manualmente).")
        return

    importances = sorted(zip(all_names, clf.feature_importances_), key=lambda x: -x[1])
    total_top2 = sum(imp for _, imp in importances[:2])

    print(f"Modelo: {payload['model_name']}")
    if payload.get("dropped_shortcut_features"):
        print(f"(ablation: excluye {payload.get('numeric_features') and 'features de magnitud máxima'})")
    print()
    for name, imp in importances[:10]:
        bar = "█" * int(imp * 50)
        print(f"  {name:30s} {imp:.3f}  {bar}")

    print(f"\n  → Las 2 features más importantes acaparan el {total_top2:.0%} de la importancia total.")
    if total_top2 > 0.5:
        print("  ⚠️  Esto sugiere que el modelo encontró un atajo simple (probablemente un")
        print("     umbral de magnitud de aceleración/giro) en vez de un patrón robusto.")


def make_classifier(model_name: str, ratio: float):
    """Recrea un clasificador nuevo (sin entrenar) con los mismos
    hiperparámetros que train_model.py, según qué modelo fue el mejor."""
    if model_name == "XGBoost":
        return XGBClassifier(
            n_estimators=300, max_depth=4, learning_rate=0.05,
            subsample=0.8, colsample_bytree=0.8, scale_pos_weight=ratio,
            random_state=RANDOM_STATE, eval_metric="aucpr", verbosity=0,
        )
    return RandomForestClassifier(
        n_estimators=300, max_depth=8, min_samples_leaf=3,
        class_weight="balanced", random_state=RANDOM_STATE, n_jobs=-1,
    )


def print_breakdown_by_age(y_true, y_pred, ages, label):
    print(f"\nDesglose por age_group ({label}):")
    df = pd.DataFrame({"y_true": y_true, "y_pred": y_pred, "age_group": list(ages)})
    for age, group in df.groupby("age_group"):
        n_pos = (group["y_true"] == 1).sum()
        if n_pos == 0:
            print(f"  {age:10s}  n={len(group):4d}  caídas_reales=0  (sin caídas, no se puede medir recall)")
            continue
        recall = recall_score(group["y_true"], group["y_pred"], pos_label=1, zero_division=0)
        acc = (group["y_true"] == group["y_pred"]).mean()
        cm = confusion_matrix(group["y_true"], group["y_pred"], labels=[0, 1])
        print(f"  {age:10s}  n={len(group):4d}  caídas_reales={n_pos:4d}  "
              f"accuracy={acc:.3f}  recall_caída={recall:.3f}  "
              f"FN={cm[1][0]:3d}  FP={cm[0][1]:3d}")


def run_loso(data_path: str, payload: dict):
    print("\n" + "=" * 50)
    print("2) VALIDACIÓN LEAVE-ONE-SUBJECT-OUT (LOSO)")
    print("=" * 50)

    df = pd.read_csv(data_path)

    # usa EXACTAMENTE las features del modelo cargado (respeta el ablation)
    numeric_features = payload["numeric_features"]
    features = numeric_features + CATEGORICAL_FEATURES
    model_name = payload["model_name"]

    if payload.get("dropped_shortcut_features"):
        print(f"⚠️  Ablation: LOSO entrenado SIN acc1_magnitude_max / gyro_magnitude_max")
    print(f"Modelo a replicar en cada fold: {model_name}")

    X = df[features]
    y = df[TARGET].astype(int)
    groups = df[GROUP_COL]
    ages = df[AGE_COL]

    neg, pos = (y == 0).sum(), (y == 1).sum()
    ratio = neg / pos if pos else 1.0

    preprocessor_transformers = [("num", "passthrough", numeric_features)]
    if CATEGORICAL_FEATURES:
        preprocessor_transformers.append(
            ("cat", OneHotEncoder(handle_unknown="ignore"), CATEGORICAL_FEATURES)
        )
    preprocessor = ColumnTransformer(preprocessor_transformers)

    logo = LeaveOneGroupOut()
    n_subjects = groups.nunique()
    print(f"Entrenando {n_subjects} veces (una por sujeto dejado afuera)...\n")

    per_subject_results = []
    all_y_true, all_y_pred, all_probs, all_ages = [], [], [], []

    for i, (train_idx, test_idx) in enumerate(logo.split(X, y, groups), 1):
        X_train, X_test = X.iloc[train_idx], X.iloc[test_idx]
        y_train, y_test = y.iloc[train_idx], y.iloc[test_idx]
        subject = groups.iloc[test_idx].iloc[0]

        clf = make_classifier(model_name, ratio)
        pipeline = Pipeline([("prep", preprocessor), ("clf", clf)])
        pipeline.fit(X_train, y_train)
        probs = pipeline.predict_proba(X_test)[:, 1]
        preds = (probs >= 0.5).astype(int)

        all_y_true.extend(y_test)
        all_y_pred.extend(preds)
        all_probs.extend(probs)
        all_ages.extend(ages.iloc[test_idx])

        acc = (preds == y_test.values).mean()
        per_subject_results.append({"subject": subject, "n_trials": len(y_test), "accuracy": acc})

        if i % 10 == 0 or i == n_subjects:
            print(f"  ...{i}/{n_subjects} sujetos evaluados")

    results_df = pd.DataFrame(per_subject_results)
    overall_pr_auc = average_precision_score(all_y_true, all_probs)
    overall_f1 = f1_score(all_y_true, all_y_pred, pos_label=1)

    print(f"\nResultado global LOSO (agregando todos los sujetos):")
    print(f"  PR-AUC:  {overall_pr_auc:.3f}")
    print(f"  F1:      {overall_f1:.3f}")
    print(f"  Matriz de confusión:\n{confusion_matrix(all_y_true, all_y_pred)}")

    print(f"\nAccuracy por sujeto (los peores 5, para ver si hay outliers):")
    print(results_df.sort_values("accuracy").head(5).to_string(index=False))

    print(f"\nAccuracy promedio por sujeto: {results_df['accuracy'].mean():.3f} "
          f"± {results_df['accuracy'].std():.3f}")

    # --- lo que realmente responde si el atajo perjudica a "elderly" ---
    print_breakdown_by_age(all_y_true, all_y_pred, all_ages, "LOSO agregado")

    print("\nInterpretación:")
    if overall_pr_auc > 0.95:
        print("  El modelo generaliza muy bien de forma agregada. Mira el desglose por")
        print("  age_group arriba: con tan pocas caídas de mayores en el dataset (75 en")
        print("  total), el recall en 'elderly' es la métrica que de verdad importa, y")
        print("  puede ser bastante peor que el número agregado aunque este sea alto.")
    elif overall_pr_auc > 0.75:
        print("  Generaliza razonablemente bien, pero hay una caída notable respecto al")
        print("  split simple — parte de ese resultado probablemente sí era optimismo")
        print("  por sujetos parecidos entre sí.")
    else:
        print("  Caída fuerte de rendimiento: el modelo dependía en buena parte de patrones")
        print("  específicos de los sujetos vistos en entrenamiento, no de un patrón")
        print("  universal de 'caída'.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", default="data/sisfall_dataset.csv")
    parser.add_argument("--model", default="model.pkl")
    args = parser.parse_args()

    with open(args.model, "rb") as f:
        payload = pickle.load(f)

    print_feature_importance(payload)
    run_loso(args.data, payload)


if __name__ == "__main__":
    main()