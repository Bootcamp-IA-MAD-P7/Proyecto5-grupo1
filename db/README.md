# Base de datos — Fall-Sentinel

PostgreSQL local vía `docker-compose.yml` en la raíz del repo.

```
db/
└── init/           # Scripts SQL ejecutados al crear el volumen (solo 1ª vez)
    └── 01_schema.sql   # Tabla app_versions (OTA / versiones APK)
```

**Quién lee la DB hoy:** solo los endpoints `/app/latest-version` y `/app/register-version` en `Backend/api/main.py` (vía `api/db.py` + `DATABASE_URL`).  
`/predict` **no** usa base de datos todavía. Supabase legacy queda desactivado si `DATABASE_URL` está configurada.

Reset completo (borra datos):

```bash
docker compose down -v
make up
```
