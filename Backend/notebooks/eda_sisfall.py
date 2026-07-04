"""
EDA del dataset de detección de caídas (SisFall agregado por ensayo),
para correr ANTES de entrenar cualquier modelo.

Genera:
  - Resumen de balance de clases (global, por sujeto, por age_group)
  - Detector automático de posibles fugas: para cada feature numérica,
    calcula qué tan bien separa por sí sola "caída" de "no caída" (AUC de
    una sola variable). Un AUC individual sospechosamente alto (>0.95) es
    la señal que hubiera detectado el problema de n_samples antes de
    entrenar nada.
  - Boxplots de cada feature por clase (fall_event) -> data/processed/eda_output/boxplots/
  - Matriz de correlación entre features -> data/processed/eda_output/correlation_heatmap.png
  - Conteo de ensayos por sujeto -> data/processed/eda_output/trials_per_subject.png
  - Chequeo de valores atípicos / fuera de rango físico plausible

Uso (desde la raíz de Backend/):
    python notebooks/eda_sisfall.py --data data/processed/sisfall_dataset.csv
"""

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")  # no requiere entorno gráfico
import matplotlib.pyplot as plt
from sklearn.metrics import roc_auc_score

TARGET = "fall_event"
GROUP_COL = "subject_id"
CATEGORICAL_FEATURES = ["age_group"]
NON_FEATURE_COLS = {TARGET, GROUP_COL, "activity_code", "trial"}

OUT_DIR = Path("data/processed/eda_output")


def section(title: str):
    print("\n" + "=" * 60)
    print(title)
    print("=" * 60)


def class_balance(df: pd.DataFrame):
    section("1) BALANCE DE CLASES")

    n_total = len(df)
    n_fall = df[TARGET].sum()
    print(f"Total ensayos: {n_total}  |  Caídas: {n_fall} ({n_fall/n_total:.1%})  |  "
          f"No caídas: {n_total - n_fall} ({(n_total-n_fall)/n_total:.1%})")

    print(f"\nEnsayos por sujeto (min/mediana/max): "
          f"{df.groupby(GROUP_COL).size().min()} / "
          f"{df.groupby(GROUP_COL).size().median():.0f} / "
          f"{df.groupby(GROUP_COL).size().max()}")

    print("\nBalance de clase por age_group:")
    print(df.groupby("age_group")[TARGET].agg(["count", "sum", "mean"])
          .rename(columns={"count": "n_ensayos", "sum": "n_caidas", "mean": "%_caidas"})
          .assign(**{"%_caidas": lambda x: (x["%_caidas"] * 100).round(1)}))

    # sujetos con 0 caídas -> importante saberlo antes del split por sujeto
    caidas_por_sujeto = df.groupby(GROUP_COL)[TARGET].sum()
    sin_caidas = caidas_por_sujeto[caidas_por_sujeto == 0]
    if len(sin_caidas):
        print(f"\n⚠️  {len(sin_caidas)} sujeto(s) SIN ningún ensayo de caída: "
              f"{list(sin_caidas.index)}")
        print("    Esto es normal si son personas mayores a quienes no se les pidió")
        print("    simular caídas por seguridad, pero afecta el split por sujeto:")
        print("    si caen todos del lado de test/val, esos folds pierden señal.")


def leakage_scan(df: pd.DataFrame, numeric_features: list):
    section("2) DETECTOR DE POSIBLES FUGAS (AUC de una sola variable)")
    print("Para cada feature, ¿qué tan bien separa 'caída' de 'no caída' ÉL SOLO?")
    print("Un AUC >0.95 es sospechoso: puede ser señal física real muy fuerte,")
    print("o un artefacto del diseño experimental (como pasó con n_samples).\n")

    y = df[TARGET]
    scores = []
    for col in numeric_features:
        vals = df[col]
        if vals.nunique() < 2 or vals.isna().all():
            continue
        try:
            auc = roc_auc_score(y, vals.fillna(vals.median()))
            auc = max(auc, 1 - auc)  # AUC invariante a la dirección
        except ValueError:
            continue
        scores.append((col, auc))

    scores.sort(key=lambda x: -x[1])
    for col, auc in scores:
        flag = "  ⚠️ SOSPECHOSO" if auc > 0.95 else ("  ⚠ alto" if auc > 0.85 else "")
        bar = "█" * int(auc * 40)
        print(f"  {col:28s} AUC={auc:.3f}  {bar}{flag}")

    sospechosos = [c for c, a in scores if a > 0.95]
    if sospechosos:
        print(f"\n⚠️  Revisar manualmente si estas features tienen sentido físico como")
        print(f"    predictor de caída, o si son un artefacto del experimento: {sospechosos}")
    else:
        print("\nNinguna feature individual separa sospechosamente bien las clases.")

    return scores


def plot_boxplots(df: pd.DataFrame, numeric_features: list, out_dir: Path):
    section("3) BOXPLOTS POR CLASE")
    box_dir = out_dir / "boxplots"
    box_dir.mkdir(parents=True, exist_ok=True)

    n = len(numeric_features)
    ncols = 4
    nrows = int(np.ceil(n / ncols))
    fig, axes = plt.subplots(nrows, ncols, figsize=(ncols * 4, nrows * 3.5))
    axes = axes.flatten()

    for i, col in enumerate(numeric_features):
        ax = axes[i]
        data_fall = df.loc[df[TARGET] == 1, col].dropna()
        data_nofall = df.loc[df[TARGET] == 0, col].dropna()
        ax.boxplot([data_nofall, data_fall], tick_labels=["No caída", "Caída"])
        ax.set_title(col, fontsize=9)
        ax.tick_params(labelsize=8)

    for j in range(i + 1, len(axes)):
        axes[j].axis("off")

    fig.tight_layout()
    out_path = box_dir / "all_features_by_class.png"
    fig.savefig(out_path, dpi=120)
    plt.close(fig)
    print(f"Guardado: {out_path}")


def plot_correlation(df: pd.DataFrame, numeric_features: list, out_dir: Path):
    section("4) MATRIZ DE CORRELACIÓN ENTRE FEATURES")
    corr = df[numeric_features].corr()

    fig, ax = plt.subplots(figsize=(max(8, len(numeric_features) * 0.5),
                                     max(6, len(numeric_features) * 0.5)))
    im = ax.imshow(corr, cmap="coolwarm", vmin=-1, vmax=1)
    ax.set_xticks(range(len(numeric_features)))
    ax.set_yticks(range(len(numeric_features)))
    ax.set_xticklabels(numeric_features, rotation=90, fontsize=7)
    ax.set_yticklabels(numeric_features, fontsize=7)
    fig.colorbar(im)
    fig.tight_layout()
    out_path = out_dir / "correlation_heatmap.png"
    fig.savefig(out_path, dpi=120)
    plt.close(fig)
    print(f"Guardado: {out_path}")

    # pares muy correlacionados (redundantes)
    pairs = []
    for i in range(len(numeric_features)):
        for j in range(i + 1, len(numeric_features)):
            c = corr.iloc[i, j]
            if abs(c) > 0.9:
                pairs.append((numeric_features[i], numeric_features[j], c))
    if pairs:
        print("\nPares de features muy redundantes (|correlación| > 0.9):")
        for a, b, c in sorted(pairs, key=lambda x: -abs(x[2])):
            print(f"  {a}  <->  {b}   (r={c:.2f})")


def plot_trials_per_subject(df: pd.DataFrame, out_dir: Path):
    section("5) ENSAYOS POR SUJETO")
    counts = df.groupby([GROUP_COL, "age_group"]).size().reset_index(name="n_ensayos")
    counts = counts.sort_values("n_ensayos", ascending=False)

    fig, ax = plt.subplots(figsize=(10, 6))
    colors = counts["age_group"].map({"adult": "steelblue", "elderly": "indianred"})
    ax.barh(counts[GROUP_COL], counts["n_ensayos"], color=colors)
    ax.set_xlabel("Número de ensayos")
    ax.set_title("Ensayos por sujeto (azul=adulto, rojo=adulto mayor)")
    fig.tight_layout()
    out_path = out_dir / "trials_per_subject.png"
    fig.savefig(out_path, dpi=120)
    plt.close(fig)
    print(f"Guardado: {out_path}")


def outlier_scan(df: pd.DataFrame, numeric_features: list):
    section("6) VALORES ATÍPICOS (fuera de ±4 desviaciones estándar)")
    any_found = False
    for col in numeric_features:
        vals = df[col].dropna()
        mean, std = vals.mean(), vals.std()
        if std == 0:
            continue
        z = (vals - mean).abs() / std
        n_out = (z > 4).sum()
        if n_out > 0:
            any_found = True
            print(f"  {col}: {n_out} valores atípicos "
                  f"(rango normal ~[{mean-4*std:.2f}, {mean+4*std:.2f}])")
    if not any_found:
        print("  No se detectaron outliers extremos (>4 std) en ninguna feature.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", default="data/processed/sisfall_dataset.csv")
    args = parser.parse_args()

    OUT_DIR.mkdir(exist_ok=True)

    df = pd.read_csv(args.data)
    numeric_features = [
        c for c in df.columns
        if c not in NON_FEATURE_COLS and c not in CATEGORICAL_FEATURES
    ]

    class_balance(df)
    leakage_scan(df, numeric_features)
    plot_boxplots(df, numeric_features, OUT_DIR)
    plot_correlation(df, numeric_features, OUT_DIR)
    plot_trials_per_subject(df, OUT_DIR)
    outlier_scan(df, numeric_features)

    section("LISTO")
    print(f"Gráficas guardadas en: {OUT_DIR.resolve()}")


if __name__ == "__main__":
    main()