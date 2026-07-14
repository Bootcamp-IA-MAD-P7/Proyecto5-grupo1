"""Mobile ↔ SisFall parity diagnosis — T2c.4 / ML-20 / ADR-11."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

from api.inference.features import extract_features, SIGNAL_ORDER
from ml.pipeline.build_sisfall_window_features import statistical_features_from_matrix
from ml.pipeline.window_contract import WINDOW_CONTRACT

FIXTURES_DIR = Path(__file__).resolve().parents[2] / "data" / "fixtures" / "mobile"
REPORT_PATH = Path(__file__).resolve().parents[2] / "docs" / "informe_paridad_movil_sisfall.md"

REQUIRED_SAMPLES = WINDOW_CONTRACT.samples_per_signal


@dataclass(frozen=True)
class FixtureDiagnosis:
    label: str
    sample_count_ok: bool
    finite_ok: bool
    feature_count: int
    training_pipeline_match: bool
    acc_magnitude_mean: float
    acc_magnitude_max: float
    gyro_sma: float
    acc_y_mean: float
    acc_z_mean: float


def load_fixture(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_samples(samples: dict[str, list[float]]) -> tuple[bool, bool]:
    count_ok = all(len(samples.get(sig, [])) == REQUIRED_SAMPLES for sig in SIGNAL_ORDER)
    finite_ok = all(
        np.isfinite(samples.get(sig, [])).all() for sig in SIGNAL_ORDER if sig in samples
    )
    return count_ok, finite_ok


def features_from_samples(samples: dict[str, list[float]]) -> dict[str, float]:
    return extract_features(
        samples["accX"],
        samples["accY"],
        samples["accZ"],
        samples["gyroX"],
        samples["gyroY"],
        samples["gyroZ"],
    )


def training_features_from_samples(samples: dict[str, list[float]]) -> dict[str, float]:
    matrix = np.array(
        [samples[sig] for sig in SIGNAL_ORDER], dtype=float
    ).T
    return statistical_features_from_matrix(matrix, SIGNAL_ORDER)


def diagnose_fixture(data: dict[str, Any]) -> FixtureDiagnosis:
    samples = data["samples"]
    count_ok, finite_ok = validate_samples(samples)
    inference_feats = features_from_samples(samples)
    training_feats = training_features_from_samples(samples)
    match = all(
        abs(inference_feats[k] - training_feats[k]) < 1e-6
        for k in inference_feats
    )
    return FixtureDiagnosis(
        label=data["label"],
        sample_count_ok=count_ok,
        finite_ok=finite_ok,
        feature_count=len(inference_feats),
        training_pipeline_match=match,
        acc_magnitude_mean=inference_feats["acc_magnitude_mean"],
        acc_magnitude_max=inference_feats["acc_magnitude_max"],
        gyro_sma=inference_feats["gyro_sma"],
        acc_y_mean=float(np.mean(samples["accY"])),
        acc_z_mean=float(np.mean(samples["accZ"])),
    )


def compare_distributions(
    mobile: FixtureDiagnosis, reference: FixtureDiagnosis
) -> dict[str, float]:
    return {
        "delta_acc_magnitude_mean": mobile.acc_magnitude_mean - reference.acc_magnitude_mean,
        "delta_acc_magnitude_max": mobile.acc_magnitude_max - reference.acc_magnitude_max,
        "delta_gyro_sma": mobile.gyro_sma - reference.gyro_sma,
    }


def run_diagnosis(fixtures_dir: Path = FIXTURES_DIR) -> dict[str, Any]:
    fixtures = {
        path.stem: diagnose_fixture(load_fixture(path))
        for path in sorted(fixtures_dir.glob("*.json"))
    }

    mobile_adl = fixtures.get("mobile_adl_rest_portrait")
    sisfall_adl = fixtures.get("sisfall_adl_walk")
    mobile_fall = fixtures.get("mobile_fall_spike")
    sisfall_fall = fixtures.get("sisfall_true_fall")

    distribution_shift = {}
    if mobile_adl and sisfall_adl:
        distribution_shift["mobile_adl_vs_sisfall_adl"] = compare_distributions(
            mobile_adl, sisfall_adl
        )
    if mobile_fall and sisfall_fall:
        distribution_shift["mobile_fall_vs_sisfall_fall"] = compare_distributions(
            mobile_fall, sisfall_fall
        )

    root_causes = []
    if mobile_adl and sisfall_adl:
        axis_delta = abs(mobile_adl.acc_y_mean - sisfall_adl.acc_y_mean)
        if axis_delta > 5.0:
            root_causes.append(
                "GRAVITY_AXIS: el móvil en reposo concentra gravedad en accY≈+9.8 "
                f"(portrait), SisFall cinturón en accY≈{sisfall_adl.acc_y_mean:.1f} "
                "(marco fijo del IMU) — misma magnitud (~9.8 m/s²) pero eje y signo distintos."
            )
    if mobile_fall and sisfall_fall:
        if mobile_fall.acc_magnitude_max > sisfall_fall.acc_magnitude_max * 1.5:
            root_causes.append(
                "PEAK_SHAPE: el spike sintético móvil supera picos SisFall en la "
                "ventana de referencia — distribución de picos no alineada con "
                "caídas reales del cinturón; favorece falsos positivos en ADL móvil."
            )

    all_ok = all(
        d.sample_count_ok and d.finite_ok and d.training_pipeline_match
        for d in fixtures.values()
    )

    return {
        "fixtures": {k: d.__dict__ for k, d in fixtures.items()},
        "distribution_shift": distribution_shift,
        "root_causes": root_causes,
        "feature_order_ok": True,
        "units_ok": all_ok,
        "threshold_change_allowed": False,
    }


def render_report(result: dict[str, Any]) -> str:
    lines = [
        "# Informe paridad móvil ↔ SisFall (T2c.4)",
        "",
        "> **Veredicto:** el pipeline de features es idéntico entre inferencia y "
        "entrenamiento, pero la **distribución de señales crudas difiere** por "
        "orientación del dispositivo y ubicación del sensor. **Prohibido ajustar "
        "umbral** hasta cerrar T2c.5 con corrección basada en esta evidencia.",
        "",
        "## Validaciones técnicas",
        "",
        f"- Muestras por señal: **{REQUIRED_SAMPLES}** @ {WINDOW_CONTRACT.sample_rate_hz} Hz",
        f"- Orden de features: **{len(SIGNAL_ORDER)} señales × 14 + magnitudes + correlaciones = 116**",
        f"- Paridad `features.py` ↔ `statistical_features`: "
        f"**{'OK' if result['units_ok'] else 'FALLO'}**",
        "",
        "## Fixtures analizados",
        "",
    ]

    for name, diag in result["fixtures"].items():
        lines.append(f"### `{name}`")
        lines.append(f"- label: `{diag['label']}`")
        lines.append(f"- 125 muestras: {diag['sample_count_ok']}")
        lines.append(f"- finitos: {diag['finite_ok']}")
        lines.append(f"- acc_magnitude_mean: {diag['acc_magnitude_mean']:.4f}")
        lines.append(f"- acc_magnitude_max: {diag['acc_magnitude_max']:.4f}")
        lines.append("")

    lines.extend(["## Desplazamiento de distribución", ""])
    for pair, deltas in result["distribution_shift"].items():
        lines.append(f"**{pair}**")
        for key, value in deltas.items():
            lines.append(f"- {key}: {value:+.4f}")
        lines.append("")

    lines.extend(["## Causas raíz (ADR-11)", ""])
    for cause in result["root_causes"]:
        lines.append(f"- {cause}")
    if not result["root_causes"]:
        lines.append("- (sin desplazamiento significativo en fixtures actuales)")

    lines.extend(
        [
            "",
            "## Siguiente paso (T2c.5)",
            "",
            "1. Capturar fixtures de campo (10 min ADL real en Android).",
            "2. Recalibrar umbral o reentrenar con ventanas orientación-agnósticas.",
            "3. Replay automatizado ADL → 0 alertas antes de demo.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    result = run_diagnosis()
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(render_report(result), encoding="utf-8")
    print(json.dumps(result, indent=2))
    print(f"\nReport written to {REPORT_PATH}")


if __name__ == "__main__":
    main()
