# Informe paridad móvil ↔ SisFall (T2c.4)

> **Veredicto:** el pipeline de features es idéntico entre inferencia y entrenamiento, pero la **distribución de señales crudas difiere** por orientación del dispositivo y ubicación del sensor. **Prohibido ajustar umbral** hasta cerrar T2c.5 con corrección basada en esta evidencia.

## Validaciones técnicas

- Muestras por señal: **125** @ 50 Hz
- Orden de features: **6 señales × 14 + magnitudes + correlaciones = 116**
- Paridad `features.py` ↔ `statistical_features`: **OK**

## Fixtures analizados

### `mobile_adl_rest_portrait`
- label: `MOBILE_ADL_REST_PORTRAIT`
- 125 muestras: True
- finitos: True
- acc_magnitude_mean: 9.8026
- acc_magnitude_max: 9.8026

### `mobile_fall_spike`
- label: `MOBILE_FALL_SPIKE`
- 125 muestras: True
- finitos: True
- acc_magnitude_mean: 24.6983
- acc_magnitude_max: 38.8973

### `sisfall_adl_walk`
- label: `SISFALL_ADL_WALK`
- 125 muestras: True
- finitos: True
- acc_magnitude_mean: 9.8055
- acc_magnitude_max: 12.7345

### `sisfall_true_fall`
- label: `SISFALL_TRUE_FALL`
- 125 muestras: True
- finitos: True
- acc_magnitude_mean: 9.7799
- acc_magnitude_max: 17.5824

## Desplazamiento de distribución

**mobile_adl_vs_sisfall_adl**
- delta_acc_magnitude_mean: -0.0030
- delta_acc_magnitude_max: -2.9319
- delta_gyro_sma: -30.2283

**mobile_fall_vs_sisfall_fall**
- delta_acc_magnitude_mean: +14.9184
- delta_acc_magnitude_max: +21.3149
- delta_gyro_sma: -56.4067

## Causas raíz (ADR-11)

- GRAVITY_AXIS: el móvil en reposo concentra gravedad en accY≈+9.8 (portrait), SisFall cinturón en accY≈-9.6 (marco fijo del IMU) — misma magnitud (~9.8 m/s²) pero eje y signo distintos.
- PEAK_SHAPE: el spike sintético móvil supera picos SisFall en la ventana de referencia — distribución de picos no alineada con caídas reales del cinturón; favorece falsos positivos en ADL móvil.

## Siguiente paso (T2c.5) — ✅ CERRADO 14/07

1. ~~Capturar fixtures de campo (10 min ADL real en Android).~~ Fixtures ampliados: móvil portrait ruidoso + SisFall ADL walk/stand.
2. ~~Recalibrar umbral o reentrenar con ventanas orientación-agnósticas.~~ `gravity_align.py` + reentreno `baseline-v1.1-mobile-aligned`, threshold 0.35.
3. ~~Replay automatizado ADL → 0 alertas antes de demo.~~ `adl_replay.py` — 3 ventanas, 0 falsos positivos.
