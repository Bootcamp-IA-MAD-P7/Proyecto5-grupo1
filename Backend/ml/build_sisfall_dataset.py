"""
Convierte los archivos crudos de SisFall (.txt, uno por ensayo) en un
dataset tabular: una fila por ensayo, con features estadísticas de la
señal completa y la etiqueta fall_event.

Por qué "una fila por ensayo" y no "una fila por timestamp":
  Cada .txt contiene una serie temporal completa (varios segundos a 200 Hz).
  Si usaras cada timestamp como una muestra independiente, filas casi
  idénticas del mismo ensayo terminarían repartidas entre train/val/test,
  generando fuga de datos severa. Resumir cada ensayo con estadísticas
  (media, máximo, std, etc.) es la forma correcta de tabularizar esto.

Uso (desde la raíz de Backend/):
    python ml/build_sisfall_dataset.py --root data/raw/sisfall --out data/processed/sisfall_dataset.csv

El script busca recursivamente cualquier .txt cuyo nombre siga el patrón
<CODE>_<SUBJECT>_R<TRIAL>.txt (p. ej. F05_SA01_R04.txt, D17_SE04_R02.txt),
sin importar la profundidad de carpetas.
"""

import argparse
import re
from pathlib import Path

import numpy as np
import pandas as pd

# --- Constantes de conversión bits -> unidades físicas (del README de SisFall) ---
# Acceleration [g] = [(2*Range) / (2^Resolution)] * AD
ADXL345 = dict(range_=16, resolution=13)   # acelerómetro 1 (columnas 1-3)
ITG3200 = dict(range_=2000, resolution=16)  # giroscopio     (columnas 4-6)
MMA8451Q = dict(range_=8, resolution=14)    # acelerómetro 2 (columnas 7-9)

FILENAME_RE = re.compile(r"^([DF]\d{2})_(S[AE]\d{2})_R(\d{2})\.txt$", re.IGNORECASE)

COLUMNS = [
    "acc1_x", "acc1_y", "acc1_z",   # ADXL345
    "gyro_x", "gyro_y", "gyro_z",   # ITG3200
    "acc2_x", "acc2_y", "acc2_z",   # MMA8451Q
]


def bits_to_units(raw: np.ndarray, range_: float, resolution: int) -> np.ndarray:
    """Aplica la fórmula del README: valor_fisico = [(2*Range)/(2^Resolution)] * AD"""
    scale = (2 * range_) / (2 ** resolution)
    return raw * scale


def find_trial_files(root: Path) -> list:
    files = [p for p in root.rglob("*.txt") if FILENAME_RE.match(p.name)]
    return sorted(files)


def parse_filename(path: Path) -> dict:
    m = FILENAME_RE.match(path.name)
    code, subject, trial = m.group(1).upper(), m.group(2).upper(), m.group(3)
    return {
        "activity_code": code,
        "subject_id": subject,
        "trial": trial,
        "is_fall": code.startswith("F"),
        "age_group": "elderly" if subject.startswith("SE") else "adult",
    }


def load_trial(path: Path) -> pd.DataFrame:
    """Lee un archivo de ensayo y devuelve las 9 columnas ya convertidas a
    unidades físicas (g para aceleración, °/s para velocidad angular).

    Cada línea de SisFall termina en ';' antes del salto de línea
    (p. ej. "-129,-83,-105,4,-16,-8,-166,-89,-113;"). Ese ';' NO es un
    separador de columna, es un terminador de línea — hay que quitarlo,
    no partir por él (si se parte por él se genera un 10º campo vacío
    por fila, que desalinea las 9 columnas).
    """
    raw_text = path.read_text(encoding="latin-1")
    raw_text = raw_text.replace(";", "")  # quita el terminador de cada línea

    from io import StringIO
    df = pd.read_csv(
        StringIO(raw_text), header=None, names=COLUMNS,
        sep=r"\s*,\s*", engine="python",
    ).apply(pd.to_numeric, errors="coerce").dropna()

    df["acc1_x"] = bits_to_units(df["acc1_x"], **ADXL345)
    df["acc1_y"] = bits_to_units(df["acc1_y"], **ADXL345)
    df["acc1_z"] = bits_to_units(df["acc1_z"], **ADXL345)

    df["gyro_x"] = bits_to_units(df["gyro_x"], **ITG3200)
    df["gyro_y"] = bits_to_units(df["gyro_y"], **ITG3200)
    df["gyro_z"] = bits_to_units(df["gyro_z"], **ITG3200)

    # acc2 (MMA8451Q) se lee para mantener la alineación de las 9 columnas
    # del archivo original, pero no se convierte ni se usa: está casi
    # perfectamente correlacionado con acc1 (ver EDA) y no aporta info nueva.

    df["acc1_magnitude"] = np.sqrt(df.acc1_x**2 + df.acc1_y**2 + df.acc1_z**2)
    df["gyro_magnitude"] = np.sqrt(df.gyro_x**2 + df.gyro_y**2 + df.gyro_z**2)

    return df


def summarize_trial(df: pd.DataFrame) -> dict:
    """Resume un ensayo completo en un único vector de features.

    Decisiones tras el EDA:
      - Solo se usa acc1 (ADXL345), el sensor de referencia usado por los
        propios autores de SisFall. acc2 (MMA8451Q) mide el mismo
        movimiento y está casi perfectamente correlacionado con acc1
        (r=0.96-1.00 en nuestro EDA) -- no aporta información nueva y solo
        diluye la interpretabilidad del feature importance.
      - No se incluye *_range: es igual a max - min, y resultó tener
        correlación r=1.00 con *_max (redundante).
      - No se incluye n_samples: es la duración del archivo, un artefacto
        del diseño experimental (cada tipo de actividad tiene una duración
        fija predefinida), no una propiedad física de una caída. Tenía
        AUC individual sospechosamente alto en el EDA.
    """
    feats = {}
    for col in ["acc1_magnitude", "gyro_magnitude"]:
        s = df[col]
        feats[f"{col}_mean"] = s.mean()
        feats[f"{col}_std"] = s.std()
        feats[f"{col}_max"] = s.max()
        feats[f"{col}_min"] = s.min()

    # jerk: derivada de la aceleración, indicador clásico de un impacto brusco
    jerk = df["acc1_magnitude"].diff().abs()
    feats["acc1_jerk_max"] = jerk.max()
    feats["acc1_jerk_mean"] = jerk.mean()

    return feats


def build_dataset(root: Path) -> pd.DataFrame:
    trial_files = find_trial_files(root)
    if not trial_files:
        raise FileNotFoundError(
            f"No se encontraron archivos con el patrón <CODE>_<SUBJECT>_R<TRIAL>.txt "
            f"bajo {root}. Revisa que la ruta apunte a la carpeta que contiene "
            f"(directa o indirectamente) los .txt de SisFall."
        )

    print(f"Encontrados {len(trial_files)} archivos de ensayo. Procesando...")

    rows = []
    skipped = 0
    for i, path in enumerate(trial_files, 1):
        meta = parse_filename(path)
        try:
            trial_df = load_trial(path)
            if trial_df.empty:
                skipped += 1
                continue
            feats = summarize_trial(trial_df)
        except Exception as e:
            print(f"  ⚠️  Error leyendo {path.name}: {e}")
            skipped += 1
            continue

        row = {**meta, **feats}
        row["fall_event"] = int(meta["is_fall"])
        rows.append(row)

        if i % 500 == 0:
            print(f"  ...{i}/{len(trial_files)} procesados")

    if skipped:
        print(f"  ⚠️  {skipped} archivos se omitieron por errores de lectura/vacíos")

    if not rows:
        raise RuntimeError(
            "Ningún archivo se pudo parsear correctamente. Revisa un archivo "
            "de ejemplo manualmente (abrir con un editor de texto) para "
            "confirmar el formato real de las líneas."
        )

    out = pd.DataFrame(rows).drop(columns=["is_fall"])
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, help="Carpeta raíz de SisFall (busca recursivamente)")
    parser.add_argument("--out", default="data/processed/sisfall_dataset.csv", help="Ruta del CSV de salida")
    args = parser.parse_args()

    root = Path(args.root)
    if not root.exists():
        raise FileNotFoundError(f"La ruta {root} no existe")

    df = build_dataset(root)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out_path, index=False)

    n_falls = df["fall_event"].sum()
    n_total = len(df)
    print(f"\n✅ Dataset generado: {n_total} ensayos totales")
    print(f"   Caídas: {n_falls}  |  No caídas: {n_total - n_falls}  |  "
          f"Ratio: {(n_total - n_falls) / max(n_falls, 1):.1f}")
    print(f"   Sujetos: {df['subject_id'].nunique()} "
          f"({(df.age_group == 'elderly').sum()} ensayos de adultos mayores, "
          f"{(df.age_group == 'adult').sum()} de adultos jóvenes)")
    print(f"   Guardado en: {out_path}")


if __name__ == "__main__":
    main()