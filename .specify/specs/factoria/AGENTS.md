> **NOTA TEMPORAL — Eliminar cuando el SDD esté completo**
>
> Este archivo es **material de referencia previo** a la metodología SDD formal de `.specify/`.
> Léelo al redactar `1_intent.md`, `2_spec.md`, `3_plan.md` y `4_task.md` en esta misma carpeta.
> Una vez su contenido esté integrado en esos cuatro archivos, **elimina este documento**.

# AGENTS.md
Instrucciones y reglas para agentes de IA que trabajen en este proyecto.

## Estructura del repositorio

| Carpeta | Contenido |
|---|---|
| `Frontend/` | App Flutter (`lib/`: models, screens, services, widgets; plataformas `android/`, `ios/`, etc.) |
| `Backend/` | FastAPI, ML, notebooks Kaggle (`notebooks/`), datasets (`data/`) |
| `docs/` | Documentación operativa y daily standups (`docs/daily/`) |
| `.specify/` | Orquestación IA y especificaciones SDD (`specs/factoria/`) |

---

## Regla: Cambiar el nombre de la aplicación

Cuando se pida cambiar el nombre visible de la app, **debes actualizar todos los archivos siguientes**. No es suficiente cambiar solo uno. Todas las rutas son relativas a `Frontend/`.

| Plataforma | Archivo | Campo |
|---|---|---|
| Android | `Frontend/android/app/src/main/AndroidManifest.xml` | `android:label` |
| Web | `Frontend/web/manifest.json` | `name`, `short_name`, `description` |
| Web | `Frontend/web/index.html` | `<title>`, meta `description`, `apple-mobile-web-app-title` |
| Windows | `Frontend/windows/CMakeLists.txt` | `BINARY_NAME` |
| Linux | `Frontend/linux/CMakeLists.txt` | `BINARY_NAME`, `APPLICATION_ID` |
| macOS | `Frontend/macos/Runner/Configs/AppInfo.xcconfig` | `PRODUCT_NAME`, `PRODUCT_BUNDLE_IDENTIFIER` |
| iOS | `Frontend/ios/Runner/Info.plist` | `CFBundleDisplayName`, `CFBundleName` |
| General | `Frontend/pubspec.yaml` | `description` |

### Notas
- El código en `Frontend/lib/` es compartido y no contiene el nombre de la app.
- El `package ID` (`com.organizacion.app`) es distinto al nombre visible y tiene sus propios campos en cada plataforma.
- Para proyectos nuevos, usar `flutter create --org com.organizacion nombre_app` dentro de `Frontend/` para evitar tener que cambiar esto manualmente.
- Los scripts de EDA van en `Backend/notebooks/`; entrenamiento en `Backend/ml/`; datasets crudos en `Backend/data/raw/`.

---

## Regla: Lógica de clasificación de caídas

La lógica de clasificación existe en dos sitios. Si se modifica una, hay que actualizar la otra:

| Entorno | Archivo | Uso |
|---|---|---|
| Backend (producción) | `Backend/api/main.py` → función `classify()` | Llamada real desde Flutter |
| Flutter (desarrollo) | `Frontend/lib/services/api_service.dart` → función `_classify()` | Mock local cuando `_useMock = true` |

Cuando se integre el modelo ML real, reemplazar `classify()` en `Backend/api/main.py`. El mock de Flutter puede mantenerse para desarrollo offline.
