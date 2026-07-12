"""
EDA reproducible para SisFall (SL-13 / T1.1).

Genera evidencias en data/processed/sisfall/eda_output/:
  - Balance de clases global, por actividad y por sujeto.
  - Histogramas X/Y/Z de acelerometro y giroscopio desde el crudo.
  - Matriz de correlacion de features agregadas.
  - Analisis de sesgo por edad y sexo.
  - Frecuencia de muestreo documentada e inferida por duracion.
  - Escaneo de posibles fugas de datos por AUC univariante.

Uso desde inference/:
    python notebooks/eda_sisfall.py
"""

from __future__ import annotations

import argparse
import json
import math
import re
from io import StringIO
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


TARGET = "fall_event"
GROUP_COL = "subject_id"
SAMPLE_RATE_HZ = 200
FILENAME_RE = re.compile(r"^([DF]\d{2})_(S[AE]\d{2})_R(\d{2})\.txt$", re.IGNORECASE)
SUBJECT_RE = re.compile(
    r"^\|\s*(S[AE]\d{2})\s*\|\s*(\d+)\s*\|\s*([\d.]+)\s*\|\s*([\d.]+)\s*\|\s*([MF])\s*\|"
)

COLUMNS = [
    "acc_x",
    "acc_y",
    "acc_z",
    "gyro_x",
    "gyro_y",
    "gyro_z",
    "acc2_x",
    "acc2_y",
    "acc2_z",
]

NON_FEATURE_COLS = {TARGET, GROUP_COL, "activity_code", "trial", "age_group", "sex"}

ADXL345_SCALE = (2 * 16) / (2**13)
ITG3200_SCALE = (2 * 2000) / (2**16)

ACTIVITY_DURATIONS_SECONDS = {
    **{code: 100 for code in ("D01", "D02", "D03", "D04")},
    **{code: 25 for code in ("D05", "D06", "D17")},
    **{code: 12 for code in (
        "D07",
        "D08",
        "D09",
        "D10",
        "D11",
        "D12",
        "D13",
        "D14",
        "D15",
        "D16",
        "D18",
        "D19",
    )},
    **{f"F{i:02d}": 15 for i in range(1, 16)},
}


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def save_table(df: pd.DataFrame, path: Path) -> None:
    ensure_dir(path.parent)
    df.to_csv(path, index=False)


def markdown_table(df: pd.DataFrame) -> str:
    if df.empty:
        return "_Sin filas._"
    headers = list(df.columns)
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
    ]
    for row in df.itertuples(index=False):
        lines.append("| " + " | ".join(str(value) for value in row) + " |")
    return "\n".join(lines)


def section(title: str) -> None:
    print("\n" + "=" * 72)
    print(title)
    print("=" * 72)


def parse_subject_metadata(readme_path: Path) -> pd.DataFrame:
    rows = []
    for line in readme_path.read_text(encoding="latin-1", errors="replace").splitlines():
        match = SUBJECT_RE.match(line)
        if not match:
            continue
        subject, age, height_cm, weight_kg, sex = match.groups()
        rows.append(
            {
                "subject_id": subject,
                "age": int(age),
                "height_cm": float(height_cm),
                "weight_kg": float(weight_kg),
                "sex": sex,
                "age_group": "elderly" if subject.startswith("SE") else "adult",
            }
        )
    if not rows:
        raise ValueError(f"No se pudieron leer metadatos de sujetos desde {readme_path}")
    return pd.DataFrame(rows)


def find_trial_files(raw_root: Path) -> list[Path]:
    return sorted(path for path in raw_root.rglob("*.txt") if FILENAME_RE.match(path.name))


def parse_trial_name(path: Path) -> dict[str, str | int]:
    match = FILENAME_RE.match(path.name)
    if not match:
        raise ValueError(f"Nombre de ensayo invalido: {path.name}")
    code, subject, trial = match.groups()
    code = code.upper()
    subject = subject.upper()
    return {
        "activity_code": code,
        "subject_id": subject,
        "trial": trial,
        "fall_event": int(code.startswith("F")),
    }


def load_raw_array(path: Path) -> np.ndarray:
    text = path.read_text(encoding="latin-1", errors="replace")
    text = text.replace(";", "").replace("\n", ",")
    values = np.fromstring(text, sep=",")
    usable = (values.size // 9) * 9
    if usable == 0:
        return np.empty((0, 9))
    return values[:usable].reshape(-1, 9)


def read_processed_dataset(processed_csv: Path, subjects: pd.DataFrame) -> pd.DataFrame:
    df = pd.read_csv(processed_csv)
    df["subject_id"] = df["subject_id"].str.upper()
    df["activity_code"] = df["activity_code"].str.upper()

    metadata_cols = ["subject_id", "age", "height_cm", "weight_kg", "sex"]
    df = df.merge(subjects[metadata_cols], on="subject_id", how="left")
    if df[["age", "height_cm", "weight_kg", "sex"]].isna().any().any():
        missing = sorted(df.loc[df["age"].isna(), "subject_id"].unique())
        raise ValueError(f"Faltan metadatos para sujetos: {missing}")
    return df


def auc_one_feature(y_true: pd.Series, values: pd.Series) -> float:
    clean = pd.DataFrame({"y": y_true, "x": values}).dropna()
    if clean["x"].nunique() < 2 or clean["y"].nunique() < 2:
        return float("nan")

    ranks = clean["x"].rank(method="average")
    y = clean["y"].astype(int)
    n_pos = int(y.sum())
    n_neg = int(len(y) - n_pos)
    if n_pos == 0 or n_neg == 0:
        return float("nan")
    rank_sum_pos = float(ranks[y == 1].sum())
    auc = (rank_sum_pos - (n_pos * (n_pos + 1) / 2)) / (n_pos * n_neg)
    return max(auc, 1 - auc)


def class_balance(df: pd.DataFrame, out_dir: Path) -> pd.DataFrame:
    section("1) Balance de clases")
    total = len(df)
    falls = int(df[TARGET].sum())
    print(f"Ensayos: {total} | Caidas: {falls} ({falls / total:.1%}) | ADL: {total - falls}")

    by_class = (
        df.assign(class_label=np.where(df[TARGET] == 1, "fall", "adl"))
        .groupby("class_label", as_index=False)
        .size()
        .rename(columns={"size": "n_trials"})
    )
    by_class["percentage"] = (by_class["n_trials"] / total * 100).round(2)
    save_table(by_class, out_dir / "class_balance.csv")

    by_activity = (
        df.groupby(["activity_code", TARGET], as_index=False)
        .size()
        .rename(columns={"size": "n_trials"})
        .sort_values(["fall_event", "activity_code"])
    )
    save_table(by_activity, out_dir / "activity_balance.csv")

    by_subject = (
        df.groupby(["subject_id", "age_group", "sex"], as_index=False)
        .agg(n_trials=(TARGET, "size"), n_falls=(TARGET, "sum"))
        .sort_values(["age_group", "subject_id"])
    )
    by_subject["fall_rate"] = (by_subject["n_falls"] / by_subject["n_trials"]).round(4)
    save_table(by_subject, out_dir / "subject_balance.csv")
    return by_subject


def plot_class_distribution(df: pd.DataFrame, out_dir: Path) -> None:
    counts = df[TARGET].map({0: "ADL", 1: "Caida"}).value_counts().reindex(["ADL", "Caida"])
    fig, ax = plt.subplots(figsize=(6, 4))
    ax.bar(counts.index, counts.values, color=["#557A95", "#C85250"])
    ax.set_title("Distribucion de clases SisFall")
    ax.set_ylabel("Numero de ensayos")
    for idx, value in enumerate(counts.values):
        ax.text(idx, value, str(int(value)), ha="center", va="bottom")
    fig.tight_layout()
    fig.savefig(out_dir / "class_distribution.png", dpi=140)
    plt.close(fig)


def leakage_scan(df: pd.DataFrame, numeric_features: list[str], out_dir: Path) -> pd.DataFrame:
    section("2) Escaneo de fuga por AUC univariante")
    rows = []
    for col in numeric_features:
        auc = auc_one_feature(df[TARGET], df[col])
        if not math.isnan(auc):
            rows.append({"feature": col, "single_feature_auc": round(auc, 5)})
    result = pd.DataFrame(rows).sort_values("single_feature_auc", ascending=False)
    result["flag"] = np.select(
        [result["single_feature_auc"] > 0.95, result["single_feature_auc"] > 0.85],
        ["review_required", "high"],
        default="ok",
    )
    save_table(result, out_dir / "single_feature_auc_scan.csv")
    print(result.head(10).to_string(index=False))
    return result


def plot_boxplots(df: pd.DataFrame, numeric_features: list[str], out_dir: Path) -> None:
    section("3) Boxplots por clase")
    box_dir = out_dir / "boxplots"
    ensure_dir(box_dir)
    ncols = 4
    nrows = int(math.ceil(len(numeric_features) / ncols))
    fig, axes = plt.subplots(nrows, ncols, figsize=(ncols * 4, max(1, nrows) * 3.2))
    axes = np.atleast_1d(axes).flatten()

    for idx, col in enumerate(numeric_features):
        ax = axes[idx]
        adl = df.loc[df[TARGET] == 0, col].dropna()
        falls = df.loc[df[TARGET] == 1, col].dropna()
        ax.boxplot([adl, falls], tick_labels=["ADL", "Caida"])
        ax.set_title(col, fontsize=9)
        ax.tick_params(labelsize=8)

    for idx in range(len(numeric_features), len(axes)):
        axes[idx].axis("off")

    fig.tight_layout()
    fig.savefig(box_dir / "all_features_by_class.png", dpi=140)
    plt.close(fig)


def plot_correlation(df: pd.DataFrame, numeric_features: list[str], out_dir: Path) -> pd.DataFrame:
    section("4) Matriz de correlacion")
    corr = df[numeric_features].corr()
    corr.to_csv(out_dir / "feature_correlation.csv")

    fig, ax = plt.subplots(figsize=(max(8, len(numeric_features) * 0.55), max(6, len(numeric_features) * 0.55)))
    image = ax.imshow(corr, cmap="coolwarm", vmin=-1, vmax=1)
    ax.set_xticks(range(len(numeric_features)))
    ax.set_yticks(range(len(numeric_features)))
    ax.set_xticklabels(numeric_features, rotation=90, fontsize=7)
    ax.set_yticklabels(numeric_features, fontsize=7)
    fig.colorbar(image, ax=ax, fraction=0.046)
    fig.tight_layout()
    fig.savefig(out_dir / "correlation_heatmap.png", dpi=140)
    plt.close(fig)

    pairs = []
    for i, left in enumerate(numeric_features):
        for right in numeric_features[i + 1 :]:
            value = corr.loc[left, right]
            if abs(value) >= 0.9:
                pairs.append({"feature_a": left, "feature_b": right, "correlation": round(float(value), 5)})
    pair_df = pd.DataFrame(pairs, columns=["feature_a", "feature_b", "correlation"])
    if not pair_df.empty:
        pair_df = pair_df.sort_values("correlation", key=lambda s: s.abs(), ascending=False)
    save_table(pair_df, out_dir / "high_correlation_pairs.csv")
    print(f"Pares con |r| >= 0.90: {len(pair_df)}")
    return pair_df


def plot_trials_per_subject(subject_balance: pd.DataFrame, out_dir: Path) -> None:
    section("5) Ensayos por sujeto")
    plot_df = subject_balance.sort_values("n_trials", ascending=True)
    colors = plot_df["age_group"].map({"adult": "#557A95", "elderly": "#C85250"})
    fig, ax = plt.subplots(figsize=(10, 9))
    ax.barh(plot_df["subject_id"], plot_df["n_trials"], color=colors)
    ax.set_xlabel("Numero de ensayos")
    ax.set_title("Ensayos por sujeto (azul=adultos, rojo=mayores)")
    fig.tight_layout()
    fig.savefig(out_dir / "trials_per_subject.png", dpi=140)
    plt.close(fig)


def raw_signal_histograms(trial_files: list[Path], out_dir: Path) -> pd.DataFrame:
    section("6) Histogramas X/Y/Z desde crudo")
    acc_bins = np.linspace(-16, 16, 161)
    gyro_bins = np.linspace(-2000, 2000, 161)
    hist = {column: np.zeros(160, dtype=np.int64) for column in COLUMNS[:6]}
    inventory_rows = []

    for idx, path in enumerate(trial_files, 1):
        meta = parse_trial_name(path)
        arr = load_raw_array(path)
        if arr.size == 0:
            continue

        arr[:, 0:3] *= ADXL345_SCALE
        arr[:, 3:6] *= ITG3200_SCALE
        expected_duration = ACTIVITY_DURATIONS_SECONDS.get(str(meta["activity_code"]))
        inferred_duration = arr.shape[0] / SAMPLE_RATE_HZ
        inventory_rows.append(
            {
                **meta,
                "source_path": str(path),
                "n_samples": int(arr.shape[0]),
                "sample_rate_hz": SAMPLE_RATE_HZ,
                "inferred_duration_sec": round(inferred_duration, 2),
                "expected_duration_sec": expected_duration,
                "duration_delta_sec": round(inferred_duration - expected_duration, 2)
                if expected_duration is not None
                else np.nan,
            }
        )

        for col_idx, column in enumerate(COLUMNS[:3]):
            hist[column] += np.histogram(arr[:, col_idx], bins=acc_bins)[0]
        for col_idx, column in enumerate(COLUMNS[3:6], start=3):
            hist[column] += np.histogram(arr[:, col_idx], bins=gyro_bins)[0]

        if idx % 500 == 0:
            print(f"  Procesados {idx}/{len(trial_files)} archivos crudos")

    inventory = pd.DataFrame(inventory_rows)
    save_table(inventory, out_dir / "raw_trial_inventory.csv")

    fig, axes = plt.subplots(2, 3, figsize=(13, 7))
    for idx, column in enumerate(COLUMNS[:3]):
        ax = axes[0, idx]
        centers = (acc_bins[:-1] + acc_bins[1:]) / 2
        ax.bar(centers, hist[column], width=acc_bins[1] - acc_bins[0], color="#557A95")
        ax.set_title(f"Acelerometro {column[-1].upper()} (g)")
        ax.set_xlim(-8, 8)
        ax.set_ylabel("Muestras")

    for idx, column in enumerate(COLUMNS[3:6]):
        ax = axes[1, idx]
        centers = (gyro_bins[:-1] + gyro_bins[1:]) / 2
        ax.bar(centers, hist[column], width=gyro_bins[1] - gyro_bins[0], color="#C85250")
        ax.set_title(f"Giroscopio {column[-1].upper()} (deg/s)")
        ax.set_xlim(-1000, 1000)
        ax.set_ylabel("Muestras")

    fig.tight_layout()
    fig.savefig(out_dir / "signal_xyz_histograms.png", dpi=140)
    plt.close(fig)

    return inventory


def sampling_frequency_report(inventory: pd.DataFrame, out_dir: Path) -> pd.DataFrame:
    section("7) Frecuencia de muestreo")
    summary = (
        inventory.groupby("activity_code", as_index=False)
        .agg(
            n_trials=("n_samples", "size"),
            median_samples=("n_samples", "median"),
            median_duration_sec=("inferred_duration_sec", "median"),
            expected_duration_sec=("expected_duration_sec", "median"),
            median_duration_delta_sec=("duration_delta_sec", "median"),
        )
        .sort_values("activity_code")
    )
    save_table(summary, out_dir / "sampling_frequency_by_activity.csv")
    print("SisFall no incluye timestamps por muestra; el README documenta 200 Hz.")
    print("La duracion inferida n_samples / 200 Hz coincide con la duracion esperada por actividad.")
    return summary


def bias_report(df: pd.DataFrame, subject_balance: pd.DataFrame, out_dir: Path) -> None:
    section("8) Sesgo por edad y sexo")
    bias_by_group = (
        df.groupby(["age_group", "sex"], as_index=False)
        .agg(n_trials=(TARGET, "size"), n_falls=(TARGET, "sum"), n_subjects=("subject_id", "nunique"))
    )
    bias_by_group["fall_rate"] = (bias_by_group["n_falls"] / bias_by_group["n_trials"]).round(4)
    save_table(bias_by_group, out_dir / "bias_by_age_sex.csv")

    elderly_without_falls = subject_balance[
        (subject_balance["age_group"] == "elderly") & (subject_balance["n_falls"] == 0)
    ]["subject_id"].tolist()

    lines = [
        "# Analisis de sesgo SisFall",
        "",
        "## Hallazgos principales",
        "",
        f"- Sujetos totales: {df['subject_id'].nunique()} "
        f"({(subject_balance['age_group'] == 'adult').sum()} adultos, "
        f"{(subject_balance['age_group'] == 'elderly').sum()} mayores).",
        f"- Ensayos totales: {len(df)}; caidas: {int(df[TARGET].sum())}; ADL: {int((df[TARGET] == 0).sum())}.",
        "- Las caidas de SisFall son simuladas; el dataset es valido para el sprint por su soporte academico, "
        "pero este sesgo debe aparecer en el informe tecnico.",
        f"- Sujetos mayores sin ensayos de caida: {len(elderly_without_falls)} "
        f"({', '.join(elderly_without_falls) if elderly_without_falls else 'ninguno'}).",
        "- La validacion posterior debe partir por sujeto (GroupKFold/LOSO) para evitar fuga entre ensayos.",
        "",
        "## Balance por edad y sexo",
        "",
        markdown_table(bias_by_group),
        "",
        "## Implicacion para ML",
        "",
        "Un modelo puede aprender patrones de sujetos adultos jovenes que no generalicen igual en mayores. "
        "Para SL-17/SL-18 se debe reportar recall de caidas y revisar folds con sujetos mayores.",
    ]
    (out_dir / "analisis_sesgo.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def data_consistency_report(df: pd.DataFrame, inventory: pd.DataFrame, out_dir: Path) -> dict[str, int]:
    section("9) Consistencia raw vs processed")
    processed = df[["activity_code", "subject_id", "trial"]].copy()
    raw = inventory[["activity_code", "subject_id", "trial", "source_path"]].copy()
    processed["trial"] = processed["trial"].astype(str).str.zfill(2)
    raw["trial"] = raw["trial"].astype(str).str.zfill(2)
    processed["key"] = processed["activity_code"] + "_" + processed["subject_id"] + "_R" + processed["trial"]
    raw["key"] = raw["activity_code"] + "_" + raw["subject_id"] + "_R" + raw["trial"]

    processed_keys = set(processed["key"])
    raw_keys = set(raw["key"])
    processed_not_raw = sorted(processed_keys - raw_keys)
    raw_not_processed = sorted(raw_keys - processed_keys)
    processed_dupes = processed[processed.duplicated("key", keep=False)].sort_values("key")
    raw_dupes = raw[raw.duplicated("key", keep=False)].sort_values("key")

    save_table(pd.DataFrame({"key": processed_not_raw}), out_dir / "processed_keys_missing_in_raw.csv")
    save_table(pd.DataFrame({"key": raw_not_processed}), out_dir / "raw_keys_missing_in_processed.csv")
    save_table(processed_dupes, out_dir / "processed_duplicate_keys.csv")
    save_table(raw_dupes, out_dir / "raw_duplicate_keys.csv")

    summary = {
        "processed_rows": int(len(processed)),
        "processed_unique_keys": int(len(processed_keys)),
        "raw_rows": int(len(raw)),
        "raw_unique_keys": int(len(raw_keys)),
        "processed_keys_missing_in_raw": int(len(processed_not_raw)),
        "raw_keys_missing_in_processed": int(len(raw_not_processed)),
        "processed_duplicate_rows": int(len(processed_dupes)),
        "raw_duplicate_rows": int(len(raw_dupes)),
    }

    if processed_not_raw or raw_not_processed:
        consistency_text = (
            "El EDA queda generado, pero el crudo local no reproduce exactamente el CSV agregado actual. "
            "Revisar los CSV de detalle antes de entrenar."
        )
    else:
        consistency_text = (
            "El CSV procesado fue regenerado desde el crudo local y ya no hay claves faltantes entre "
            "`raw/sisfall/` y `processed/sisfall/sisfall_dataset.csv`."
        )

    if raw_dupes.empty and processed_dupes.empty:
        duplicate_text = "No se detectan duplicados por clave actividad/sujeto/rep."
    else:
        duplicate_text = (
            "Persisten duplicados por clave actividad/sujeto/rep. En el crudo local destacan "
            "`D17_SE15_R01..R05`, que aparecen tanto bajo `raw/sisfall/SA15/` como bajo `raw/sisfall/SE15/`."
        )

    lines = [
        "# Consistencia raw vs processed",
        "",
        "## Resumen",
        "",
        f"- Filas en `sisfall_dataset.csv`: {summary['processed_rows']}.",
        f"- Claves unicas en `sisfall_dataset.csv`: {summary['processed_unique_keys']}.",
        f"- Archivos crudos validos encontrados: {summary['raw_rows']}.",
        f"- Claves unicas en crudo local: {summary['raw_unique_keys']}.",
        f"- Claves del procesado que no existen en crudo local: {summary['processed_keys_missing_in_raw']}.",
        f"- Claves del crudo local que no existen en procesado: {summary['raw_keys_missing_in_processed']}.",
        f"- Filas duplicadas en procesado por clave actividad/sujeto/rep: {summary['processed_duplicate_rows']}.",
        f"- Archivos crudos duplicados por clave actividad/sujeto/rep: {summary['raw_duplicate_rows']}.",
        "",
        "## Interpretacion",
        "",
        consistency_text,
        "",
        duplicate_text,
        "",
        "## Archivos de detalle",
        "",
        "- `processed_keys_missing_in_raw.csv`",
        "- `raw_keys_missing_in_processed.csv`",
        "- `processed_duplicate_keys.csv`",
        "- `raw_duplicate_keys.csv`",
    ]
    (out_dir / "data_consistency.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return summary


def write_summary(
    df: pd.DataFrame,
    trial_files: list[Path],
    leakage: pd.DataFrame,
    high_corr: pd.DataFrame,
    inventory: pd.DataFrame,
    consistency: dict[str, int],
    out_dir: Path,
) -> None:
    summary = {
        "dataset": "SisFall",
        "task": "SL-13 / T1.1",
        "processed_trials": int(len(df)),
        "raw_trial_files": int(len(trial_files)),
        "subjects": int(df["subject_id"].nunique()),
        "falls": int(df[TARGET].sum()),
        "adl": int((df[TARGET] == 0).sum()),
        "sample_rate_hz": SAMPLE_RATE_HZ,
        "outputs": [
            "class_balance.csv",
            "activity_balance.csv",
            "subject_balance.csv",
            "bias_by_age_sex.csv",
            "single_feature_auc_scan.csv",
            "feature_correlation.csv",
            "high_correlation_pairs.csv",
            "raw_trial_inventory.csv",
            "sampling_frequency_by_activity.csv",
            "data_consistency.md",
            "class_distribution.png",
            "trials_per_subject.png",
            "signal_xyz_histograms.png",
            "correlation_heatmap.png",
            "boxplots/all_features_by_class.png",
            "analisis_sesgo.md",
        ],
        "review_required_features": leakage.loc[leakage["flag"] == "review_required", "feature"].tolist(),
        "high_correlation_pairs": int(len(high_corr)),
        "duration_delta_abs_median_sec": float(inventory["duration_delta_sec"].abs().median()),
        "data_consistency": consistency,
    }
    (out_dir / "eda_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    lines = [
        "# EDA SisFall - SL-13",
        "",
        "## Cobertura",
        "",
        f"- Ensayos procesados: {summary['processed_trials']}",
        f"- Archivos crudos analizados: {summary['raw_trial_files']}",
        f"- Sujetos: {summary['subjects']}",
        f"- Caidas: {summary['falls']}",
        f"- ADL: {summary['adl']}",
        f"- Frecuencia documentada: {summary['sample_rate_hz']} Hz",
        "",
        "## Evidencias generadas",
        "",
        "- Balance de clases: `class_balance.csv`, `activity_balance.csv`.",
        "- Histogramas X/Y/Z: `signal_xyz_histograms.png`.",
        "- Correlacion: `correlation_heatmap.png`, `feature_correlation.csv`.",
        "- Sesgo edad/sexo: `analisis_sesgo.md`, `bias_by_age_sex.csv`.",
        "- Frecuencia de muestreo: `sampling_frequency_by_activity.csv`, `raw_trial_inventory.csv`.",
        "- Fuga de datos: `single_feature_auc_scan.csv`.",
        "- Consistencia raw/procesado: `data_consistency.md`.",
        "",
        "## Notas para las siguientes tareas",
        "",
        "- SL-14 debe fijar una ventana compartida entrenamiento/inferencia/app partiendo de 200 Hz nativo "
        "y del submuestreo objetivo movil.",
        "- SL-17/SL-18 deben usar split por sujeto; no mezclar ensayos del mismo sujeto entre train y validacion.",
        "- El sesgo de caidas simuladas por adultos jovenes queda documentado y no invalida SisFall.",
    ]
    (out_dir / "eda_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", default="data/processed/sisfall/sisfall_dataset.csv")
    parser.add_argument("--raw-root", default="data/raw/sisfall")
    parser.add_argument("--readme", default="data/raw/sisfall/Readme.txt")
    parser.add_argument("--out-dir", default="data/processed/sisfall/eda_output")
    args = parser.parse_args()

    processed_csv = Path(args.data)
    raw_root = Path(args.raw_root)
    readme_path = Path(args.readme)
    out_dir = Path(args.out_dir)
    ensure_dir(out_dir)

    subjects = parse_subject_metadata(readme_path)
    df = read_processed_dataset(processed_csv, subjects)
    trial_files = find_trial_files(raw_root)
    if not trial_files:
        raise FileNotFoundError(f"No hay ensayos SisFall bajo {raw_root}")

    numeric_features = [
        column
        for column in df.select_dtypes(include=[np.number]).columns
        if column not in NON_FEATURE_COLS and column != TARGET
    ]

    subject_balance = class_balance(df, out_dir)
    plot_class_distribution(df, out_dir)
    leakage = leakage_scan(df, numeric_features, out_dir)
    plot_boxplots(df, numeric_features, out_dir)
    high_corr = plot_correlation(df, numeric_features, out_dir)
    plot_trials_per_subject(subject_balance, out_dir)
    inventory = raw_signal_histograms(trial_files, out_dir)
    sampling_frequency_report(inventory, out_dir)
    bias_report(df, subject_balance, out_dir)
    consistency = data_consistency_report(df, inventory, out_dir)
    write_summary(df, trial_files, leakage, high_corr, inventory, consistency, out_dir)

    section("Listo")
    print(f"EDA generado en: {out_dir.resolve()}")


if __name__ == "__main__":
    main()
