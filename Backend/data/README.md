# Datasets — Fall-Sentinel

**Política del equipo:** todos los datasets van **en el repositorio**. Al clonar, cada miembro tiene los mismos datos sin pasos extra.

**Criterios de calidad:** ver `.specify/memory/constitucion_factoria.md` §6 (paper + consentimiento + citación en la comunidad). Fuentes sin soporte académico verificable se descartan.

## Convención de carpetas (obligatoria)

`raw/`, `processed/` y `feedback/` comparten **la misma estructura por fuente**:

```
data/
├── raw/
│   ├── sisfall/          # DS-01 — activo
│   └── mobiact/          # DS-02 — candidato
├── processed/
│   ├── sisfall/
│   ├── mobiact/
│   └── combined/         # uniones documentadas (futuro)
└── feedback/             # telemetría desde la app (runtime)
```

Regla: **un dataset = una carpeta con el mismo nombre en raw y processed**. No mezclar fuentes en la raíz de `processed/`.

## Inventario

| ID | Fuente | Crudo | Procesado | Estado |
|---|---|---|---|---|
| **DS-01** | SisFall | `raw/sisfall/` | `processed/sisfall/` | Activo — crudo descargado |
| **DS-02** | MobiAct / MobiFall | `raw/mobiact/` | `processed/mobiact/` | Candidato — pendiente descarga |
| ~~DS-02~~ | ~~Kaggle zara2099~~ | ~~`raw/kaggle/`~~ | — | **Dado de baja** (sin soporte académico) |

## Evaluación académica de fuentes (2026-07-05)

Referencia: [PMC5539544](https://pmc.ncbi.nlm.nih.gov/articles/PMC5539544/), [PMC7738812](https://pmc.ncbi.nlm.nih.gov/articles/PMC7738812/)

| Dataset | Paper | Ética | Citación | Nivel máster / paper | Decisión |
|---|---|---|---|---|---|
| **SisFall** | Sucerquia et al., *Sensors* 2017 | Comité bioética UdeA | Benchmark estándar IMU | ✅ Sí — base principal | **Mantener DS-01** |
| **MobiAct** | Vavoulas et al., IEEE/Sensors 2016 | Institucional HMU | Citado con SisFall (JMIR 2024) | ✅ Sí — complemento smartphone | **Candidato DS-02** |
| **UniMiB SHAR** | Micucci et al., 2017 | Univ. Milano | Alta en wearables | ✅ Sí — alternativa | Reserva |
| **FARSEEING** | Klenk et al., AAL project | Consorcio EU | Único con caídas reales mayores | ✅ Gold standard clínico | Acceso restringido (~22 públicos) |
| **PhysioNet LTMM** | PhysioNet 2016 | 71 mayores reales | PhysioNet index | ⚠️ Riesgo de caída, no eventos | Complemento futuro |
| **Kaggle zara2099** | ❌ No | ❌ No documentado | ❌ No en revisiones | ❌ No | **Descartado** |

### ¿Descartar SisFall?

**No.** Es simulado, pero cumple los tres criterios constitucionales. La limitación (caídas casi solo de jóvenes) se documenta como **sesgo conocido** (`processed/sisfall/eda_output/analisis_sesgo.md`), no como motivo de exclusión.

### Estrategia recomendada

1. **DS-01 SisFall** — entrenamiento y validación LOSO (IMU cintura, 200 Hz)
2. **DS-02 MobiAct** — generalización cross-dataset (smartphone, alineado con Flutter)
3. **`processed/combined/`** — unión homogeneizada solo tras EDA de ambos y SDD aprobado
4. **Feedback app** — vía `data/feedback/` para datos propios a medio plazo

## DS-01 — SisFall

- **Crudo:** `raw/sisfall/` — archivos `<CODE>_<SUBJECT>_R<TRIAL>.txt` (38 carpetas por sujeto)
- **Procesado:** `processed/sisfall/sisfall_dataset.csv`

```bash
cd Backend
python ml/build_sisfall_dataset.py --root data/raw/sisfall --out data/processed/sisfall/sisfall_dataset.csv
python notebooks/eda_sisfall.py
```

- **Paper:** https://doi.org/10.3390/s17010198
- **Mirrors:** `raw/sisfall/README.md`

## DS-02 — MobiAct (candidato)

- **URL:** https://bmi.hmu.gr/the-mobifall-and-mobiact-datasets-2/
- **Crudo:** `raw/mobiact/` — pendiente
- **Procesado:** `processed/mobiact/` — reservado

## Kaggle — dado de baja

El dataset `zara2099/real-time-patient-fall-detection-data` fue eliminado por no cumplir §6 de la constitución: sin paper, sin consentimiento documentado, sin citación en la literatura de detección de caídas. Ver `raw/kaggle/DEPRECATED.md`.

## Regenerar processed desde crudo

Solo cuando el equipo lo decida en SDD — no regenerar automáticamente:

```bash
python ml/build_sisfall_dataset.py --root data/raw/sisfall --out data/processed/sisfall/sisfall_dataset.csv
python notebooks/eda_sisfall.py
python ml/train_model.py
```
