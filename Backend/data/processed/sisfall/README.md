# DS-01 — SisFall (procesado)

- `sisfall_dataset.csv` — una fila por ensayo (generado desde `../../raw/sisfall/`)
- `eda_output/` — EDA, boxplots, análisis de sesgo

Regenerar:

```bash
cd Backend
python ml/build_sisfall_dataset.py --root data/raw/sisfall --out data/processed/sisfall/sisfall_dataset.csv
python notebooks/eda_sisfall.py
```
