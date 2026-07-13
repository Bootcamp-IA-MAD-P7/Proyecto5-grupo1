# Frontend — Fall Detector Tester

App móvil Flutter para detección de caídas: monitorización de sensores, predicción vía API y auto-actualización OTA (Android).

## Estructura

```
Frontend/
├── lib/                         # Código Dart compartido
│   ├── main.dart                # Entrada, tema, chequeo de actualizaciones
│   ├── models/
│   │   └── prediction_result.dart
│   ├── screens/
│   │   ├── home_screen.dart     # Monitorización en tiempo real
│   │   └── result_screen.dart   # Resultado / alerta de caída
│   ├── services/
│   │   ├── api_service.dart     # Predicción (mock o API local/AWS)
│   │   └── update_service.dart  # Auto-actualización OTA Android
│   └── widgets/
│       └── update_dialog.dart   # Diálogo de nueva versión
├── android/                     # Plataforma principal (release + Firebase)
├── ios/
├── web/
├── linux/
├── macos/
├── windows/
├── pubspec.yaml
└── analysis_options.yaml
```

> Ejecutar todos los comandos `flutter` desde la **raíz de `Frontend/`**.

## Inicio rápido

```bash
flutter pub get
flutter run
```

Dispositivo concreto:

```bash
flutter devices
flutter run -d <device_id>
```

## Conexión con Backend

La URL de la API se configura con **`--dart-define=API_BASE_URL`** (ver `lib/config/app_config.dart`).

| Entorno | URL base | Comando |
|---|---|---|
| **QA — EC2** | http://34.235.130.33:8005 | `cp .env.qa.example .env.qa && make flutter-qa` |
| **Local — móvil físico** | http://\<IP-LAN\>:8080 | `make flutter-phone` (desde raíz del repo) |
| **Local — emulador** | http://10.0.2.2:8080 | `make flutter-local` |
| **Mock offline** | — | `_useMock = true` en servicios |

Build **debug** permite HTTP (`android/app/src/debug/AndroidManifest.xml`).

## Auto-actualización (Android)

- `UpdateService` consulta `GET /app/latest-version` al arrancar.
- `UpdateDialog` descarga el APK desde GitHub Releases e instala.
- Firma release: `android/key.properties` (local) o secrets en CI (`.github/workflows/android.yml`).

## Identificadores

| Campo | Valor |
|---|---|
| Nombre visible | SentiLife |
| Package ID | `com.sentilife.app` |
| Proyecto pubspec | `sentilife` |
