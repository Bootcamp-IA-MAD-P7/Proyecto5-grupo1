# SL-14 / T1.2 - Telemetry Window Contract v1.0.0

This document is the human-readable contract for SentiLife telemetry windows.
The machine-readable source of truth is `contracts/window_contract.json`.

## Scope

The same window definition must be used by:

- Flutter when capturing and sending sensor data.
- Spring Boot when validating `POST /api/v1/telemetry/windows`.
- FastAPI when validating and preprocessing `/predict`.
- ML training and feature generation.

Any change to this contract requires updating this file, the JSON contract,
tests, and the SDD documents that reference SL-14/T1.2.

## Fixed Window

| Field | Value |
|---|---|
| Schema version | `1.0.0` |
| Duration | `2500 ms` |
| Sample rate | `50 Hz` |
| Samples per required signal | `125` |
| Overlap | `50%` |
| Hop | `1250 ms` |

`windowEnd` must equal `windowStart + 2500 ms`.

## Required Signals

All required arrays must exist and must contain exactly 125 finite numeric
values:

| Key | Unit |
|---|---|
| `accX` | `m/s^2` |
| `accY` | `m/s^2` |
| `accZ` | `m/s^2` |
| `gyroX` | `deg/s` |
| `gyroY` | `deg/s` |
| `gyroZ` | `deg/s` |

Optional context is allowed but cannot be required for prediction:

| Key | Unit |
|---|---|
| `heartRate` | `bpm` |
| `roomTemp` | `celsius` |
| `roomLight` | `lux` |

## Payload Shape

Flutter sends windows to Spring Boot:

```json
{
  "monitoredPersonId": "uuid",
  "deviceId": "android-f8a3",
  "windowStart": "2026-07-08T10:15:00.000Z",
  "windowEnd": "2026-07-08T10:15:02.500Z",
  "sampleRateHz": 50,
  "samples": {
    "accX": [0.12],
    "accY": [9.71],
    "accZ": [0.33],
    "gyroX": [1.2],
    "gyroY": [0.4],
    "gyroZ": [2.1]
  },
  "context": {
    "heartRate": 74,
    "roomTemp": 22.5,
    "roomLight": 310
  }
}
```

The arrays above are abbreviated for readability. Real payloads must contain
125 values in every required signal.

Spring Boot forwards the same required signal arrays to FastAPI `/predict`
without user-identifying data. Subject features may be added separately as
defined in `2_spec.md` section 6.8.

## Preprocessing Rules

- SisFall native 200 Hz data is resampled to 50 Hz with linear interpolation.
- Mobile data is emitted at the closest available cadence and normalized to
  exactly 50 Hz windows before sending.
- Acceleration remains in `m/s^2`; gyroscope remains in `deg/s`.
- Gravity is preserved. Do not high-pass it away before this contract changes.
- Payloads stay in physical units. Any scaling or normalization belongs inside
  the model pipeline and must be identical in training and inference.
- A window with missing required signals, fewer than 125 samples in any required
  signal, `NaN`, or infinite values is invalid.
- If a capture buffer has extra samples, trim or resample to exactly 125 samples
  before persistence/inference.

## Acceptance Checklist

- Python can import `Backend/ml/window_contract.py` and validate the JSON.
- Flutter constants in `Frontend/lib/config/window_contract.dart` match the JSON.
- Tests cover the fixed values, required signal keys, optional context keys, and
  validation/preprocessing rules.
- `4_task.md` marks T1.2 complete (ventana v1.0.0).

