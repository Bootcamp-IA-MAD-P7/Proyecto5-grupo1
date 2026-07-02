# AGENTS.md
Instrucciones y reglas para agentes de IA que trabajen en este proyecto Flutter.

---

## Regla: Cambiar el nombre de la aplicación

Cuando se pida cambiar el nombre visible de la app, **debes actualizar todos los archivos siguientes**. No es suficiente cambiar solo uno.

| Plataforma | Archivo | Campo |
|---|---|---|
| Android | `android/app/src/main/AndroidManifest.xml` | `android:label` |
| Web | `web/manifest.json` | `name`, `short_name`, `description` |
| Web | `web/index.html` | `<title>`, meta `description`, `apple-mobile-web-app-title` |
| Windows | `windows/CMakeLists.txt` | `BINARY_NAME` |
| Linux | `linux/CMakeLists.txt` | `BINARY_NAME`, `APPLICATION_ID` |
| macOS | `macos/Runner/Configs/AppInfo.xcconfig` | `PRODUCT_NAME`, `PRODUCT_BUNDLE_IDENTIFIER` |
| iOS | `ios/Runner/Info.plist` | `CFBundleDisplayName`, `CFBundleName` |
| General | `pubspec.yaml` | `description` |

### Notas
- El código en `lib/` es compartido y no contiene el nombre de la app.
- El `package ID` (`com.organizacion.app`) es distinto al nombre visible y tiene sus propios campos en cada plataforma.
- Para proyectos nuevos, usar `flutter create --org com.organizacion nombre_app` para evitar tener que cambiar esto manualmente.
