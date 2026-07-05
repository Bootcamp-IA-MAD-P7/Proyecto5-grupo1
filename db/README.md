# Base de datos — Fall-Sentinel

PostgreSQL vía Docker Compose. **QA en EC2 usa las mismas credenciales que dev** (ver `.env.example`).

| Variable | Dónde configurarla |
|---|---|
| `POSTGRES_USER` | `.env` / `.env.example` |
| `POSTGRES_PASSWORD` | `.env` / `.env.example` |
| `POSTGRES_DB` | `.env` / `.env.example` |

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

`DATABASE_URL` en el contenedor API: ver `.env.example` (host interno `db:5432`).

Para conectar desde tu PC (DBeaver, psql): ver `.env.qa.example`.

Deploy: `docker-compose.prod.yml` en `~/fallsentinel/` (defaults, sin secrets Postgres en CI).
