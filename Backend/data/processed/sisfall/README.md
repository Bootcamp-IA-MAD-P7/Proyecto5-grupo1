# DS-01 - SisFall processed

Primary SL-16 / T1.3 artifacts:

- `sisfall_windows_features.csv.gz` - one row per SL-14 telemetry window, with
  deterministic metadata and statistical features.
- `feature_manifest.json` - reproducibility manifest: contract values, signal
  keys, feature list and row counts.

Additional artifacts:

- `sisfall_dataset.csv` - legacy trial-level table used by the initial EDA.
- `eda_output/` - EDA, boxplots and bias analysis.

Regenerate from `Backend/`:

```bash
python ml/build_sisfall_window_features.py \
  --root data/raw/sisfall \
  --out data/processed/sisfall/sisfall_windows_features.csv.gz \
  --manifest data/processed/sisfall/feature_manifest.json
python notebooks/eda_sisfall.py
```

Window contract:

- 2.5 s duration.
- 50 Hz target sample rate.
- 50% overlap, represented as 1250 ms temporal hop.
- 125 samples per required signal.
- Required signals: `accX`, `accY`, `accZ`, `gyroX`, `gyroY`, `gyroZ`.
