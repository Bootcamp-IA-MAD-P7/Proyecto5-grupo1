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
│   │   ├── api_service.dart     # Predicción (mock o API Render)
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

| Modo | Configuración | Uso |
|---|---|---|
| API real | `_useMock = false` en `lib/services/api_service.dart` | Producción (actual) |
| Mock local | `_useMock = true` | Desarrollo offline |

API desplegada: `https://proyecto5-grupo1.onrender.com`

## Auto-actualización (Android)

- `UpdateService` consulta `GET /app/latest-version` al arrancar.
- `UpdateDialog` descarga el APK desde GitHub Releases e instala.
- Firma release: `android/key.properties` (local) o secrets en CI (`.github/workflows/android.yml`).

## Identificadores

| Campo | Valor |
|---|---|
| Nombre visible | Fall Detector Tester |
| Package ID | `com.jzelada.proyecto_flutter` |
| Proyecto pubspec | `proyecto_flutter` |
