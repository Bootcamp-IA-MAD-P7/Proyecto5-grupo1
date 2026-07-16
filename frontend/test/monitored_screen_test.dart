import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentilife/l10n/generated/app_localizations.dart';
import 'package:sentilife/models/user.dart';
import 'package:sentilife/screens/monitored_screen.dart';
import 'package:sentilife/services/auth_session.dart';
import 'package:sentilife/services/devices_service.dart';
import 'package:sentilife/services/monitored_context_store.dart';
import 'package:sentilife/services/monitored_service.dart';
import 'package:sentilife/services/monitoring_coordinator_registry.dart';
import 'package:sentilife/services/sensor_capability_service.dart';
import 'package:sentilife/services/secure_token_storage.dart';
import 'package:sentilife/services/session_repository.dart';
import 'package:sentilife/services/telemetry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

SessionRepository _monitoredSession() {
  SessionRepository.resetForTests();
  final session = SessionRepository(storage: InMemorySecureTokenStorage());
  SessionRepository.useForTests(session);
  session.setSession(
    const AuthTokens(
      accessToken: 'test-token',
      refreshToken: 'refresh-token',
      expiresIn: 900,
      user: User(
        id: 'monitored-1',
        email: 'monitored@test.com',
        fullName: 'Manuel Pérez',
        role: UserRole.monitored,
      ),
    ),
  );
  return session;
}

Widget _buildMonitored({
  required MonitoredService monitoredService,
  DevicesService? devicesService,
  TelemetryService? telemetryService,
  MonitoredContextStore? contextStore,
  SensorCapabilityService? sensorCapabilityService,
}) {
  return MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MonitoredScreen(
      session: _monitoredSession(),
      onLocaleChanged: (_) {},
      monitoredService: monitoredService,
      devicesService: devicesService,
      telemetryService: telemetryService,
      contextStore: contextStore ?? MonitoredContextStore(),
      sensorCapabilityService: sensorCapabilityService ??
          _availableImuSensorService(),
    ),
  );
}

SensorCapabilityService _availableImuSensorService() {
  return _FakeSensorCapabilityService(
    const ImuCapabilityResult(
      accelerometerAvailable: true,
      gyroscopeAvailable: true,
    ),
  );
}

SensorCapabilityService _unavailableImuSensorService() {
  return _FakeSensorCapabilityService(
    const ImuCapabilityResult(
      accelerometerAvailable: false,
      gyroscopeAvailable: false,
    ),
  );
}

class _FakeSensorCapabilityService extends SensorCapabilityService {
  _FakeSensorCapabilityService(this.result);

  final ImuCapabilityResult result;

  @override
  Future<ImuCapabilityResult> checkImuAvailability() async => result;
}

Future<void> _pumpMonitoredScreen(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pump();
}

Map<String, dynamic> _linkedProfile({String consentStatus = 'ACTIVE'}) => {
      'id': 'person-1',
      'userId': 'uuid-monitored-user',
      'userEmail': 'monitored@test.com',
      'fullName': 'Manuel Pérez',
      'birthDate': '1948-03-12',
      'age': 78,
      'sex': 'M',
      'weightKg': 78.5,
      'heightCm': 172,
      'consentStatus': consentStatus,
      'monitoringStatus': 'INACTIVE',
      'pairingCode': 'SL-84F2K9',
      'createdAt': '2026-07-08T10:00:00Z',
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MonitoredContextStore().resetInMemoryForTests();
    MonitoringCoordinatorRegistry.resetForTests();
  });

  tearDown(() async {
    SessionRepository.resetForTests();
    final store = MonitoredContextStore()..bindUser('monitored-1');
    await store.clear();
  });

  testWidgets('cuenta MONITORED sin ficha muestra PENDING_LINK', (
    tester,
  ) async {
    final monitoredService = MonitoredService(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/me')) {
          return _json(
            {
              'error': 'NOT_FOUND',
              'message': 'Monitored profile not linked',
            },
            404,
          );
        }
        throw UnsupportedError('Unexpected request: ${req.url}');
      }),
    );

    await _pumpMonitoredScreen(tester, _buildMonitored(monitoredService: monitoredService));

    expect(find.textContaining('PENDING_LINK'), findsOneWidget);
    expect(find.text('Vinculación pendiente'), findsOneWidget);
  });

  testWidgets('PENDING_LINK bloquea pairing y monitorización', (tester) async {
    final monitoredService = MonitoredService(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/me')) {
          return _json(
            {
              'error': 'NOT_FOUND',
              'message': 'Monitored profile not linked',
            },
            404,
          );
        }
        throw UnsupportedError('Unexpected request: ${req.url}');
      }),
    );

    await _pumpMonitoredScreen(tester, _buildMonitored(monitoredService: monitoredService));

    expect(find.text('Código del cuidador'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Iniciar monitoreo'), findsOneWidget);
    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Iniciar monitoreo'),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('IMU faltante muestra pantalla bloqueante', (tester) async {
    final monitoredService = MonitoredService(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/me')) {
          return _json({'id': 'person-1', 'fullName': 'Manuel'});
        }
        throw UnsupportedError('Unexpected request: ${req.url}');
      }),
    );

    await _pumpMonitoredScreen(
      tester,
      _buildMonitored(
        monitoredService: monitoredService,
        sensorCapabilityService: _unavailableImuSensorService(),
      ),
    );

    expect(find.text('Sensores no disponibles'), findsOneWidget);
    expect(find.text('Iniciar monitoreo'), findsNothing);
  });

  testWidgets('TabBar Estado|Sensores y pestaña sensores pausada (T5.4)', (
    tester,
  ) async {
    final monitoredService = MonitoredService(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/me')) {
          return _json({'id': 'person-1', 'fullName': 'Manuel'});
        }
        throw UnsupportedError('Unexpected request: ${req.url}');
      }),
    );

    await _pumpMonitoredScreen(tester, _buildMonitored(monitoredService: monitoredService));

    expect(find.text('Estado'), findsOneWidget);
    expect(find.text('Sensores'), findsOneWidget);

    await tester.tap(find.text('Sensores'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'La monitorización está detenida. Inicia el monitoreo para ver las señales en vivo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'tras logout en el mismo móvil recupera pairing y consentimiento activo',
    (tester) async {
      const userId = 'monitored-1';
      final store = MonitoredContextStore()..bindUser(userId);
      await store.clear();

      final telemetryService = TelemetryService(
        client: MockClient((req) async {
          if (req.url.path.contains('/status/')) {
            return _json({
              'monitoringStatus': 'INACTIVE',
              'lastWindowAt': null,
              'lastPrediction': null,
            });
          }
          throw UnsupportedError('Unexpected telemetry request: ${req.url}');
        }),
      );

      final devicesService = DevicesService(
        client: MockClient((req) async {
          if (req.url.path.endsWith('/my-pairing')) {
            return _json({
              'monitoredPersonId': 'person-1',
              'deviceId': 'device-1',
              'deviceToken': 'token-1',
            });
          }
          throw UnsupportedError('Unexpected devices request: ${req.url}');
        }),
      );

      final monitoredService = MonitoredService(
        client: MockClient((req) async {
          if (req.url.path.endsWith('/me')) {
            return _json(_linkedProfile(consentStatus: 'ACTIVE'));
          }
          if (req.url.path.contains('/telemetry/')) {
            return _json({'lastPrediction': null, 'lastWindowAt': null});
          }
          throw UnsupportedError('Unexpected request: ${req.url}');
        }),
      );

      await _pumpMonitoredScreen(
        tester,
        _buildMonitored(
          monitoredService: monitoredService,
          devicesService: devicesService,
          telemetryService: telemetryService,
          contextStore: store,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(store.isPaired, isTrue);
      expect(store.consentActive, isTrue);
      expect(find.text('Dispositivo vinculado'), findsOneWidget);
      expect(find.text('Consentimiento de monitorización'), findsNothing);
      expect(find.text('Se requiere consentimiento activo'), findsNothing);
    },
  );
}
