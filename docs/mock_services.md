# Mock Services — Guía de uso

> **Estado:** T0.10 ✅ completada · rama `feature/mocks`

## ¿Qué son?

Servicios Dart en `Frontend/lib/services/` que implementan exactamente los contratos de `2_spec.md §6` con datos en memoria (`_useMock = true`). Permiten al frontend desarrollar las tres pantallas de perfil **sin esperar a que el backend Java esté listo**.

Cuando el backend Java esté disponible, basta con poner `_useMock = false` en cada servicio — las firmas de métodos y los modelos de datos son idénticos.

## Servicios disponibles

| Archivo | Contrato spec | Datos mock incluidos |
|---|---|---|
| `auth_service.dart` | §6.1 | 3 usuarios: caregiver / monitored / IT_ADMIN |
| `monitored_service.dart` | §6.2 | 2 personas: Manuel Pérez (consent ACTIVE) + Carmen López (PENDING) |
| `telemetry_service.dart` | §6.3 | Clasificación por umbrales (accel > 15 m/s² o gyro > 300 °/s) |
| `alerts_service.dart` | §6.5 | 3 alertas: PENDING + CONFIRMED + DISMISSED |
| `devices_service.dart` | §6.4 | 2 códigos: SL-84F2K9 → person-001, SL-77X3M1 → person-002 |
| `admin_service.dart` | §6.6 | Historial, export, usuarios, retrain con simulación de progreso |

Excepciones compartidas: `services/exceptions.dart` (`ApiException`, `AuthException`, `DeviceException`, `TelemetryException`, `AdminException`).

## Credenciales mock

| Email | Password | Rol |
|---|---|---|
| `caregiver@test.com` | `Test1234!` | CAREGIVER |
| `monitored@test.com` | `Test1234!` | MONITORED |
| `admin@test.com` | `Test1234!` | IT_ADMIN |

## Ejemplo de uso en una pantalla

```dart
import '../services/auth_service.dart';
import '../services/alerts_service.dart';

// Login
final auth = AuthService();
final tokens = await auth.login(
  email: 'caregiver@test.com',
  password: 'Test1234!',
);
print(tokens.user.role); // UserRole.caregiver

// Listar alertas pendientes
final alerts = AlertsService();
final result = await alerts.list(status: AlertStatus.pending);
print(result.content.length); // 1

// Confirmar una alerta
final updated = await alerts.review(
  'uuid-alert-001',
  status: AlertStatus.confirmed,
  comment: 'Caída real confirmada',
);
print(updated.status); // AlertStatus.confirmed
```

## Ejecutar los tests

```bash
cd Frontend
flutter test test/mock_services_test.dart --reporter expanded
```

**32 tests** — resultado esperado: `+32: All tests passed!`

Los tests cubren:
- Happy path de cada endpoint
- Errores con código HTTP correcto (401, 404, 409)
- Detección de caída por acelerómetro alto Y por giroscopio alto
- Vinculación de dispositivo con ambos códigos de pairing
- Simulación del ciclo completo de reentrenamiento (idle → running → completed)

## Cómo pasar al backend real

En cada servicio, cambia la constante `_useMock`:

```dart
// Antes (mock)
static const bool _useMock = true;

// Después (backend Java real)
static const bool _useMock = false;
```

El token JWT real se debe inyectar en `_headers()` de cada servicio desde la sesión activa del usuario (pendiente implementar `AuthSession` como singleton o provider).

## Estructura de archivos

```
Frontend/lib/
├── models/
│   ├── user.dart               # User, AuthTokens, UserRole
│   ├── monitored_person.dart   # MonitoredPerson, ConsentStatus, PagedResponse<T>
│   ├── alert.dart              # Alert, AlertStatus
│   └── retrain_status.dart     # RetrainJobStatus, RetrainDetails
├── services/
│   ├── exceptions.dart         # Excepciones compartidas
│   ├── auth_service.dart
│   ├── monitored_service.dart
│   ├── telemetry_service.dart
│   ├── alerts_service.dart
│   ├── devices_service.dart
│   └── admin_service.dart
└── test/
    └── mock_services_test.dart # 32 tests unitarios
```
