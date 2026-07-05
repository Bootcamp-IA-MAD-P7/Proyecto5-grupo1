# DS-01 — SisFall (crudo)

Colocar aquí los archivos `.txt` originales de SisFall (uno por ensayo).
Patrón de nombre: `<CODE>_<SUBJECT>_R<TRIAL>.txt` (ej. `F05_SA01_R04.txt`).

Fuente oficial (frecuentemente caída): http://sisfall.imed.li/

**Mirrors si el enlace no responde:**
- Hugging Face: https://huggingface.co/datasets/Algo-rythmic/Sisfall_Dataset
- Google Drive: `gdown 1-E-TLd5_J-DDWZXkuYL-moMpoezlMn4Z` → descomprimir aquí

Procesar a CSV con:
`python ml/build_sisfall_dataset.py --root data/raw/sisfall --out data/processed/sisfall/sisfall_dataset.csv`
