import 'package:flutter_test/flutter_test.dart';
import 'package:sentilife/config/window_contract.dart';
import 'package:sentilife/models/alert.dart';
import 'package:sentilife/models/monitored_person.dart';
import 'package:sentilife/models/retrain_status.dart';
import 'package:sentilife/models/user.dart';
import 'package:sentilife/services/admin_service.dart';
import 'package:sentilife/services/alerts_service.dart';
import 'package:sentilife/services/auth_service.dart';
import 'package:sentilife/services/devices_service.dart';
import 'package:sentilife/services/exceptions.dart';
import 'package:sentilife/services/monitored_service.dart';
import 'package:sentilife/services/telemetry_service.dart';

void main() {
  // ── AuthService ────────────────────────────────────────────────────────────
  group('AuthService (mock)', () {
    final auth = AuthService(useMock: true);

    test('login con credenciales válidas devuelve tokens y usuario', () async {
      final tokens = await auth.login(
        email: 'caregiver@test.com',
        password: 'Test1234!',
      );
      expect(tokens.accessToken, isNotEmpty);
      expect(tokens.user.role, UserRole.caregiver);
      expect(tokens.user.email, 'caregiver@test.com');
    });

    test('login con contraseña incorrecta lanza AuthException 401', () async {
      expect(
        () => auth.login(email: 'caregiver@test.com', password: 'wrong'),
        throwsA(isA<AuthException>().having((e) => e.status, 'status', 401)),
      );
    });

    test('login con rol MONITORED devuelve rol correcto', () async {
      final tokens = await auth.login(
        email: 'monitored@test.com',
        password: 'Test1234!',
      );
      expect(tokens.user.role, UserRole.monitored);
    });

    test('login con rol IT_ADMIN devuelve rol correcto', () async {
      final tokens = await auth.login(
        email: 'admin@test.com',
        password: 'Test1234!',
      );
      expect(tokens.user.role, UserRole.itAdmin);
    });

    test('register devuelve usuario con datos correctos', () async {
      final user = await auth.register(
        email: 'nuevo@test.com',
        password: 'Pass1234!',
        fullName: 'Nuevo Usuario',
        role: UserRole.caregiver,
      );
      expect(user.email, 'nuevo@test.com');
      expect(user.role, UserRole.caregiver);
    });

    test('refresh con token válido devuelve nuevos tokens', () async {
      final tokens = await auth.login(
        email: 'caregiver@test.com',
        password: 'Test1234!',
      );
      final refreshed = await auth.refresh(tokens.refreshToken);
      expect(refreshed.accessToken, isNotEmpty);
      expect(refreshed.user.email, 'caregiver@test.com');
    });

    test('refresh con token inválido lanza AuthException 401', () async {
      expect(
        () => auth.refresh('token-invalido'),
        throwsA(isA<AuthException>().having((e) => e.status, 'status', 401)),
      );
    });
  });

  // ── MonitoredService ───────────────────────────────────────────────────────
  group('MonitoredService (mock)', () {
    final service = MonitoredService();

    test('list devuelve personas del cuidador', () async {
      final result = await service.list();
      expect(result.content, isNotEmpty);
      expect(result.content.first.fullName, 'Manuel Pérez');
    });

    test('get por ID devuelve la persona correcta', () async {
      final person = await service.get('uuid-person-001');
      expect(person.id, 'uuid-person-001');
      expect(person.consentStatus, ConsentStatus.active);
    });

    test('get con ID inexistente lanza ApiException 404', () async {
      expect(
        () => service.get('id-inexistente'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });

    test('create añade persona a la lista', () async {
      final before = await service.list();
      await service.create(
        fullName: 'Prueba Test',
        birthDate: '1950-01-01',
        sex: 'F',
        weightKg: 60.0,
        heightCm: 160.0,
      );
      final after = await service.list();
      expect(after.totalElements, before.totalElements + 1);
    });

    test('nueva persona tiene consentimiento PENDING', () async {
      final person = await service.create(
        fullName: 'Sin Consent',
        birthDate: '1955-06-15',
        sex: 'M',
        weightKg: 70.0,
        heightCm: 170.0,
      );
      expect(person.consentStatus, ConsentStatus.pending);
      expect(person.pairingCode, isNotNull);
    });

    test('delete elimina la persona de la lista', () async {
      await service.create(
        fullName: 'Para Borrar',
        birthDate: '1960-01-01',
        sex: 'F',
        weightKg: 55.0,
        heightCm: 162.0,
      );
      final before = await service.list();
      final toDelete = before.content.last;
      await service.delete(toDelete.id);
      final after = await service.list();
      expect(after.totalElements, before.totalElements - 1);
      expect(after.content.any((p) => p.id == toDelete.id), isFalse);
    });

    test('acceptConsent completa sin error', () async {
      await expectLater(
        service.acceptConsent('uuid-person-001'),
        completes,
      );
    });

    test('revokeConsent completa sin error', () async {
      await expectLater(
        service.revokeConsent('uuid-person-001'),
        completes,
      );
    });
  });

  // ── AlertsService ──────────────────────────────────────────────────────────
  group('AlertsService (mock)', () {
    final service = AlertsService();

    test('list devuelve alertas', () async {
      final result = await service.list();
      expect(result.content, isNotEmpty);
    });

    test('list filtra por status PENDING', () async {
      final result = await service.list(status: AlertStatus.pending);
      expect(result.content.every((a) => a.status == AlertStatus.pending), isTrue);
    });

    test('review confirma una alerta', () async {
      final updated = await service.review(
        'uuid-alert-001',
        status: AlertStatus.confirmed,
        comment: 'Caída real',
      );
      expect(updated.status, AlertStatus.confirmed);
    });

    test('review con ID inexistente lanza ApiException 404', () async {
      expect(
        () => service.review('no-existe', status: AlertStatus.dismissed),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });
  });

  // ── TelemetryService ───────────────────────────────────────────────────────
  group('TelemetryService (mock)', () {
    final service = TelemetryService();
    final windowEnd = DateTime.now();
    final windowStart = windowEnd.subtract(
      const Duration(milliseconds: WindowContract.durationMs),
    );

    test('sendWindow sin caída devuelve fallDetected false', () async {
      final result = await service.sendWindow(
        monitoredPersonId: 'uuid-person-001',
        deviceId: 'android-test-001',
        windowStart: windowStart,
        windowEnd: windowEnd,
        sampleRateHz: WindowContract.sampleRateHz,
        samples: {
          'accX': List.filled(WindowContract.samplesPerSignal, 0.1),
          'accY': List.filled(WindowContract.samplesPerSignal, 0.2),
          'accZ': List.filled(WindowContract.samplesPerSignal, 9.8),
          'gyroX': List.filled(WindowContract.samplesPerSignal, 0.5),
          'gyroY': List.filled(WindowContract.samplesPerSignal, 0.3),
          'gyroZ': List.filled(WindowContract.samplesPerSignal, 0.1),
        },
      );
      expect(result.fallDetected, isFalse);
      expect(result.confidence, lessThan(0.5));
      expect(result.modelVersion, isNotEmpty);
    });

    test('sendWindow con aceleración alta detecta caída', () async {
      final result = await service.sendWindow(
        monitoredPersonId: 'uuid-person-001',
        deviceId: 'android-test-001',
        windowStart: windowStart,
        windowEnd: windowEnd,
        sampleRateHz: WindowContract.sampleRateHz,
        samples: {
          // > 15 m/s² → caída
          'accX': List.filled(WindowContract.samplesPerSignal, 20.0),
          'accY': List.filled(WindowContract.samplesPerSignal, 20.0),
          'accZ': List.filled(WindowContract.samplesPerSignal, 20.0),
          'gyroX': List.filled(WindowContract.samplesPerSignal, 0.0),
          'gyroY': List.filled(WindowContract.samplesPerSignal, 0.0),
          'gyroZ': List.filled(WindowContract.samplesPerSignal, 0.0),
        },
      );
      expect(result.fallDetected, isTrue);
      expect(result.confidence, greaterThan(0.5));
    });

    test('sendWindow con giroscopio alto detecta caída', () async {
      final result = await service.sendWindow(
        monitoredPersonId: 'uuid-person-001',
        deviceId: 'android-test-001',
        windowStart: windowStart,
        windowEnd: windowEnd,
        sampleRateHz: WindowContract.sampleRateHz,
        samples: {
          'accX': List.filled(WindowContract.samplesPerSignal, 0.1),
          'accY': List.filled(WindowContract.samplesPerSignal, 0.1),
          'accZ': List.filled(WindowContract.samplesPerSignal, 9.8),
          // > 300 °/s → caída
          'gyroX': List.filled(WindowContract.samplesPerSignal, 400.0),
          'gyroY': List.filled(WindowContract.samplesPerSignal, 0.0),
          'gyroZ': List.filled(WindowContract.samplesPerSignal, 0.0),
        },
      );
      expect(result.fallDetected, isTrue);
    });

    test('getStatus devuelve estado ACTIVE', () async {
      final status = await service.getStatus('uuid-person-001');
      expect(status.monitoringStatus, 'ACTIVE');
      expect(status.lastWindowAt, isNotNull);
    });
  });

  // ── DevicesService ─────────────────────────────────────────────────────────
  group('DevicesService (mock)', () {
    final service = DevicesService();

    test('pair con código válido devuelve token de dispositivo', () async {
      final result = await service.pair(
        pairingCode: 'SL-84F2K9',
        deviceId: 'android-test-001',
      );
      expect(result.monitoredPersonId, 'uuid-person-001');
      expect(result.deviceToken, isNotEmpty);
    });

    test('pair con segundo código válido vincula a persona correcta', () async {
      final result = await service.pair(
        pairingCode: 'SL-77X3M1',
        deviceId: 'android-test-002',
      );
      expect(result.monitoredPersonId, 'uuid-person-002');
    });

    test('pair con código inválido lanza DeviceException 404', () async {
      expect(
        () => service.pair(pairingCode: 'INVALID', deviceId: 'test'),
        throwsA(isA<DeviceException>().having((e) => e.status, 'status', 404)),
      );
    });

    test('registerPushToken completa sin error', () async {
      await expectLater(
        service.registerPushToken(
          fcmToken: 'fcm-token-test-123',
          deviceId: 'android-test-001',
        ),
        completes,
      );
    });
  });

  // ── AdminService ───────────────────────────────────────────────────────────
  group('AdminService (mock)', () {
    test('getHistory devuelve entradas del historial', () async {
      final service = AdminService();
      final result = await service.getHistory();
      expect(result.content, isNotEmpty);
      expect(result.content.any((e) => e.feedbackLabel != null), isTrue);
    });

    test('getUsers devuelve los 3 roles', () async {
      final service = AdminService();
      final result = await service.getUsers();
      final roles = result.content.map((u) => u.role).toSet();
      expect(roles, containsAll([UserRole.caregiver, UserRole.monitored, UserRole.itAdmin]));
    });

    test('startRetrain inicia el job', () async {
      final service = AdminService();
      await service.startRetrain();
      final status = await service.getRetrainStatus();
      expect(status.status, isNot(RetrainStatus.idle));
    });

    test('startRetrain dos veces lanza AdminException 409', () async {
      final service = AdminService();
      await service.startRetrain();
      expect(
        () => service.startRetrain(),
        throwsA(isA<AdminException>().having((e) => e.status, 'status', 409)),
      );
    });

    test('getRetrainStatus evoluciona a completed tras esperar', () async {
      final service = AdminService();
      await service.startRetrain();
      await Future.delayed(const Duration(seconds: 10));
      final status = await service.getRetrainStatus();
      expect(status.status, RetrainStatus.completed);
      expect(status.decision, 'promoted');
      expect(status.details?.newRecall, greaterThan(status.details!.currentRecall));
    });
  });
}
