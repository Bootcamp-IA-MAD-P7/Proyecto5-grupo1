# Firebase / FCM — SentiLife

Guía para configurar push notifications en **local**, **QA (EC2)** y **GitHub Actions**.

Proyecto Firebase del equipo: **proyectoflutter-8a229**

| Dato | Valor |
|---|---|
| Project ID | `proyectoflutter-8a229` |
| App ID (Android SentiLife) | `1:551135695634:android:151b8a23dbb4e7aaf9d9cb` |
| Sender ID | `551135695634` |
| Package Android | `com.sentilife.app` |

---

## 1. Archivos necesarios (carpeta `secrets/`)

La carpeta `secrets/` está en `.gitignore`. **Nunca commitear estos archivos.**

```
Proyecto5-grupo1/
└── secrets/
    ├── google-services.json                          ← App Flutter (recibir push)
    └── *-firebase-adminsdk-*.json    ← Backend Java (enviar push; nombre puede variar)
```

| Archivo | Origen en Firebase Console | Quién lo usa |
|---|---|---|
| `google-services.json` | Project settings → General → app Android → Download | Flutter (`make flutter-local` / `make flutter-qa`) |
| `*-firebase-adminsdk-*.json` | Project settings → **Service accounts** → **Generar nueva clave privada** | Backend Java (`make up` / EC2) |

> **No necesitas** el certificado push **web** (VAPID). Es solo para navegadores.

---

## 2. Variables de entorno local (`.env`)

Copia y edita:

```bash
cp .env.example .env
```

Bloque Firebase mínimo:

```bash
GOOGLE_SERVICES_JSON_PATH=./secrets/google-services.json
FIREBASE_SERVICE_ACCOUNT_PATH=./secrets/sentilife-a7767-firebase-adminsdk-fbsvc-6015549a37.json
```

Opcional (identificadores públicos — ya vienen en `google-services.json`):

```bash
FIREBASE_PROJECT_ID=proyectoflutter-8a229
FIREBASE_APP_ID=1:551135695634:android:151b8a23dbb4e7aaf9d9cb
FIREBASE_MESSAGING_SENDER_ID=551135695634
```

Flutter en móvil físico (misma WiFi):

```bash
API_HOST=192.168.x.x    # IP LAN de tu PC
DEVICE=XXXXXXXX         # adb devices
```

### Aplicar configuración

```bash
bash scripts/setup-firebase.sh   # copia JSON → frontend + backend/config
make up                          # backend con FCM habilitado
make flutter-local               # emulador
# o
make flutter-phone               # móvil físico
```

### Verificar que funciona

**Backend** (logs al arrancar):

```
[FCM] Firebase Admin SDK initialized successfully
```

**Flutter** (log debug al abrir app):

```
[FCM] Firebase inicializado correctamente
```

**Flujo manual:**

1. Login **CAREGIVER** → registra token (`POST /devices/push-token`)
2. Simular caída / crear alerta → push en el móvil
3. Tap en notificación → `AlertDetailScreen`

---

## 3. Variables QA (`.env.qa`)

```bash
cp .env.qa.example .env.qa
```

Apunta al EC2 y reutiliza los mismos archivos Firebase:

```bash
API_BASE_URL=http://34.235.130.33:8005
GOOGLE_SERVICES_JSON_PATH=./secrets/google-services.json
FIREBASE_SERVICE_ACCOUNT_PATH=./secrets/sentilife-a7767-firebase-adminsdk-fbsvc-6015549a37.json
```

```bash
make flutter-qa
```

> El backend en EC2 recibe la cuenta de servicio vía CI (secret `FIREBASE_SERVICE_ACCOUNT`). No hace falta subir el JSON a mano al servidor si el deploy automático está activo.

---

## 4. GitHub Actions — Secrets obligatorios

Configurar en: **GitHub repo → Settings → Secrets and variables → Actions**

### Firebase (push FCM)

| Secret | Valor a pegar | Workflow |
|---|---|---|
| `GOOGLE_SERVICES_JSON` | Contenido **completo** del archivo `secrets/google-services.json` | `android.yml` — build APK |
| `FIREBASE_SERVICE_ACCOUNT` | Contenido **completo** del archivo `*-firebase-adminsdk-*.json` | `ci.yml` (EC2) + `android.yml` (App Distribution) |
| `FIREBASE_APP_ID` | `1:551135695634:android:151b8a23dbb4e7aaf9d9cb` | `android.yml` — Firebase App Distribution |

**Cómo copiar el contenido para los secrets:**

```bash
# Desde la raíz del repo:
cat secrets/google-services.json          # → pegar en GOOGLE_SERVICES_JSON
cat secrets/*-firebase-adminsdk-*.json   # → pegar en FIREBASE_SERVICE_ACCOUNT
```

### Infra / deploy (ya deberían existir)

| Secret | Uso | Workflow |
|---|---|---|
| `EC2_HOST` | `34.235.130.33` | `ci.yml`, `android.yml` |
| `EC2_USER` | `ubuntu` o `ec2-user` | `ci.yml` |
| `EC2_SSH_KEY` | Clave PEM privada SSH | `ci.yml` |
| `DOCKER_USERNAME` | Usuario Docker Hub | `ci.yml` |
| `DOCKER_PASSWORD` | Token Docker Hub | `ci.yml` |
| `JWT_SECRET` | JWT producción (≥64 chars) | `ci.yml` deploy EC2 |
| `POSTGRES_USER` | `fallsentinel` | `ci.yml` deploy EC2 |
| `POSTGRES_PASSWORD` | Password prod Postgres | `ci.yml` deploy EC2 |
| `POSTGRES_DB` | `fallsentinel` | `ci.yml` deploy EC2 |

### Android release (APK firmado)

| Secret | Uso | Workflow |
|---|---|---|
| `KEYSTORE_BASE64` | Keystore release en base64 | `android.yml` |
| `KEYSTORE_PASSWORD` | Password del keystore | `android.yml` |
| `KEY_PASSWORD` | Password de la key | `android.yml` |
| `KEY_ALIAS` | Alias de la key | `android.yml` |
| `GH_PAT` | Personal Access Token para crear GitHub Release | `android.yml` |

---

## 5. Qué hace cada pieza

```
┌─────────────────┐     registerPushToken      ┌──────────────────┐
│  App Flutter    │ ─────────────────────────► │  Backend Java    │
│  (google-svc)   │                            │  (service acct)  │
└────────┬────────┘                            └────────┬─────────┘
         │                                              │
         │         FCM push (caída detectada)           │
         │ ◄────────────────────────────────────────────┘
         │
         ▼
   AlertDetailScreen (tap en notificación)
```

| Componente | Archivo / secret | Rol |
|---|---|---|
| Flutter recibe push | `google-services.json` | Token FCM + notificaciones en el móvil |
| Backend envía push | `firebase-adminsdk-*.json` | Firebase Admin SDK en Java |
| EC2 deploy | secret `FIREBASE_SERVICE_ACCOUNT` | Copia JSON a `~/sentilife/backend/config/` |
| APK CI | secret `GOOGLE_SERVICES_JSON` | Escribe `android/app/google-services.json` en build |

---

## 6. Checklist rápido

- [x] Proyecto Firebase `proyectoflutter-8a229` creado
- [x] App Android `com.sentilife.app` registrada
- [x] `secrets/google-services.json` descargado
- [x] `secrets/*-firebase-adminsdk-*.json` descargado
- [ ] `.env` con rutas Firebase configuradas
- [ ] `bash scripts/setup-firebase.sh` sin warnings
- [ ] `make up` → log `[FCM] Firebase Admin SDK initialized successfully`
- [ ] Secrets GitHub: `GOOGLE_SERVICES_JSON`, `FIREBASE_SERVICE_ACCOUNT`, `FIREBASE_APP_ID`

---

## 7. Troubleshooting

| Síntoma | Causa probable | Solución |
|---|---|---|
| `[FCM] Firebase not initialized` en backend | Falta service account en `backend/config/` | `bash scripts/setup-firebase.sh` + `make up` |
| `[FCM] Firebase no disponible` en Flutter | Falta `google-services.json` en build | `bash scripts/setup-firebase.sh` + rebuild app |
| Push no llega pero alertas en lista sí | Backend sin FCM o token no registrado | Login CAREGIVER de nuevo; revisar logs backend |
| Build Android CI falla Firebase | Secret `GOOGLE_SERVICES_JSON` mal formado | Pegar JSON completo, una sola línea o multiline válido |

---

## Referencias

- Spec contrato push: `.specify/specs/factoria/2_spec.md` §6.4
- Script setup: `scripts/setup-firebase.sh`
- Tareas: T2.16 (push Flutter), T2.22 (registro token)
