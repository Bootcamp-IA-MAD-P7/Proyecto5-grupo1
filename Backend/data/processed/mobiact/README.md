# DS-02 — MobiAct / MobiFall (procesado)

Espejo de `../../raw/mobiact/`:

```
processed/mobiact/
├── mobiact_v2.0/    ← CSV tabular, EDA, features
└── mobifall_v2.0/   ← idem para subset caídas
```

Generar artefactos solo tras:
1. Crudo validado en `raw/mobiact/`
2. Pipeline documentado en SDD (`2_spec.md` / `3_plan.md`)
3. Unión con SisFall → `../combined/` (nunca mezclar en crudo)
