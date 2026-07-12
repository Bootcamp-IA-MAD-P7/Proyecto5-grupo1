# DS-02 — MobiAct / MobiFall (candidato)

- **Institución:** BMI — Biomedical Informatics Laboratory, Hellenic Mediterranean University (Grecia)
- **Página oficial:** https://bmi.hmu.gr/the-mobifall-and-mobiact-datasets-2/
- **MobiAct v2.0:** https://bmi.hmu.gr/the-mobiact-v2-0-dataset/
- **Contacto:** bmi@hmu.gr
- **Papers:** Vavoulas et al. (2016), Chatzaki et al. (2017), Vavoulas et al. (2014) — ver matriz en `../../README.md`

## Estructura en este repo

```
raw/mobiact/
├── mobiact_v2.0/    ← ADL + caídas, 66 sujetos, >3.200 ensayos (Samsung Galaxy S3)
└── mobifall_v2.0/   ← subset caídas, complemento MobiFall
```

Procesado espejo en `processed/mobiact/mobiact_v2.0/` y `mobifall_v2.0/`.

## Cómo descargarlo (oficial — cumple constitución §6)

**No hay enlace público ni `pip install`.** A diferencia de SisFall, BMI exige solicitud formal:

1. Enviar email a **bmi@hmu.gr** (asunto sugerido: *MobiAct/MobiFall dataset request — Fall-Sentinel research*)
2. Indicar: uso académico no comercial (Factoría F5 + máster IA sanitaria), institución, responsable del proyecto
3. Firmar el **Database Usage Agreement** que envían
4. Recibir los `.zip` por email o enlace privado
5. Extraer **sin modificar** en las carpetas de arriba

### Plantilla de email (copiar y adaptar)

```
To: bmi@hmu.gr
Subject: Request for MobiAct v2.0 and MobiFall v2.0 datasets — academic research

Dear Biomedical Informatics Laboratory,

We are students/researchers at Factoría F5 Madrid (Bootcamp IA) working on
Fall-Sentinel, a fall detection system using smartphone IMU data (Flutter + FastAPI).

We request access to MobiAct v2.0 and MobiFall v2.0 for non-commercial research
and educational purposes, under your Database Usage Agreement.

Project: Fall-Sentinel — Proyecto5 Grupo 1
Contact: [nombre] — [email institucional]
Use: EDA, cross-dataset validation with SisFall, academic report / TFM

We will cite the original publications in any deliverable.

Thank you,
[Equipo]
```

## Formato de los datos (cuando lleguen)

- **Dispositivo:** Samsung Galaxy S3, sensor en bolsillo del pantalón
- **Por ensayo:** 3 archivos `.txt` (acelerómetro, giroscopio, orientación)
- **Cabecera:** metadatos de sujeto, actividad y timestamp
- **MobiAct v2.0:** 4 tipos de caída + 12 ADL + escenario vida diaria, 66 sujetos

## Verificación tras descarga

```bash
# Desde Backend/data/raw/mobiact/
find mobiact_v2.0 -name "*.txt" | wc -l
find mobifall_v2.0 -name "*.txt" | wc -l
# Esperado: miles de archivos (3 por ensayo)
```

## Nota sobre mirrors no oficiales

Existen copias en GitHub (p. ej. mirrors comunitarios). **Preferir siempre la copia de BMI** con acuerdo firmado — encaja con los criterios de paper + consentimiento de la constitución del proyecto.

**Estado:** pendiente — solicitud a bmi@hmu.gr
