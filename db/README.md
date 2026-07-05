# Base de datos — Fall-Sentinel

PostgreSQL vía Docker Compose. **QA en EC2 usa las mismas credenciales que dev.**

| Variable | Valor (dev y QA) |
|---|---|
| `POSTGRES_USER` | `fallsentinel` |
| `POSTGRES_PASSWORD` | `fallsentinel123` |
| `POSTGRES_DB` | `fallsentinel` |

## Local

`docker-compose.yml` en la raíz del repo.

```
db/
└── init/
    └── 01_schema.sql   # Tabla app_versions (OTA)
```

**Quién lee la DB:** `/app/latest-version` y `/app/register-version` (`api/db.py`).  
`/predict` no usa DB.

Reset:

```bash
docker compose down -v && make up
```

## QA (EC2)

| Entorno | Host | Puerto host |
|---|---|---|
| API (red Docker) | `db` | 5432 interno |
| Debug externo | `34.235.130.33` | **5435** |

`DATABASE_URL` en el contenedor API:

```
postgresql://fallsentinel:fallsentinel123@db:5432/fallsentinel
```

Para conectar desde tu PC (DBeaver, psql): ver `.env.qa.example` → `QA_DATABASE_URL`.

Deploy: `docker-compose.prod.yml` en `~/fallsentinel/` (defaults, sin secrets Postgres en CI).
