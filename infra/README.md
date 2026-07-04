# Infraestructura local y despliegue

| Archivo | Propósito |
|---|---|
| `docker-compose.yml` | API + Postgres para desarrollo local |
| `.env.example` | Plantilla de variables de entorno |

## Desarrollo local

```bash
cp infra/.env.example infra/.env
# Editar infra/.env con tus credenciales
docker compose -f infra/docker-compose.yml up --build
```

## Producción

- **API:** Render — ver `render.yaml` en la raíz del repo
- **App Android:** GitHub Actions → Firebase + GitHub Releases
