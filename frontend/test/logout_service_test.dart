import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentilife/models/prediction_result.dart';
import 'package:sentilife/models/telemetry_window.dart';
import 'package:sentilife/models/user.dart';
import 'package:sentilife/services/device_id_service.dart';
import 'package:sentilife/services/devices_service.dart';
import 'package:sentilife/services/logout_service.dart';
import 'package:sentilife/services/monitoring_coordinator.dart';
import 'package:sentilife/services/monitoring_coordinator_registry.dart';
import 'package:sentilife/services/monitoring_foreground_bridge.dart';
import 'package:sentilife/services/monitored_context_store.dart';
import 'package:sentilife/services/secure_token_storage.dart';
import 'package:sentilife/services/sensor_capture_service.dart';
import 'package:sentilife/services/session_repository.dart';
import 'package:sentilife/services/sliding_window_builder.dart';
import 'package:sentilife/services/telemetry_pipeline_service.dart';
import 'package:sentilife/services/telemetry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MonitoredContextStore().resetInMemoryForTests();
    MonitoringCoordinatorRegistry.resetForTests();
    DeviceIdService.testOverride = 'android-logout-test';
    SessionRepository.resetForTests();
    SessionRepository.useForTests(
      SessionRepository(storage: InMemorySecureTokenStorage()),
    );
  });

  tearDown(() {
    DeviceIdService.resetForTests();
    MonitoringCoordinatorRegistry.resetForTests();
    SessionRepository.resetForTests();
  });

  group('LogoutService', () {
    test('MONITORED logout shuts down coordinator and clears namespaced context',
        () async {
      const monitoredUserId = 'user-monitored-1';
      final store = MonitoredContextStore()..bindUser(monitoredUserId);
      await store.setPairing(
        personId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'token-1',
      );

      final coordinator = MonitoringCoordinator(
        pipeline: TelemetryPipelineService(
          sensorCaptureService: _FakeSensorCaptureService(),
          windowBuilder: _FakeSlidingWindowBuilder(),
          telemetryService: _FakeTelemetryService(),
        ),
        foregroundBridge: _FakeForegroundBridge(),
      );
      MonitoringCoordinatorRegistry.instance.register(coordinator);
      await coordinator.start(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'token-1',
      );

      var sessionCleared = false;
      await LogoutService(
        devicesService: DevicesService(client: MockClient((_) async => http.Response('', 404))),
      ).performLogout(
        user: const User(
          id: monitoredUserId,
          email: 'monitored@test.com',
          fullName: 'Monitored User',
          role: UserRole.monitored,
        ),
        clearSession: () async {
          sessionCleared = true;
        },
      );

      expect(coordinator.isMonitoring, isFalse);
      expect(store.isPaired, isFalse);
      expect(sessionCleared, isTrue);

      store.bindUser(monitoredUserId);
      await store.load();
      expect(store.isPaired, isFalse);
    });

    test('CAREGIVER logout calls DELETE push-token', () async {
      String? deletedPath;
      final service = LogoutService(
        devicesService: DevicesService(
          client: MockClient((req) async {
            if (req.method == 'DELETE') {
              deletedPath = req.url.path;
              return http.Response('', 204);
            }
            return http.Response('', 404);
          }),
        ),
      );

      await service.performLogout(
        user: const User(
          id: 'caregiver-1',
          email: 'caregiver@test.com',
          fullName: 'Caregiver',
          role: UserRole.caregiver,
        ),
        clearSession: () async {},
      );

      expect(deletedPath, endsWith('/push-token/android-logout-test'));
    });
  });
}

class _FakeForegroundBridge extends MonitoringForegroundBridge {
  @override
  Future<void> start({String title = 'SentiLife', String body = 'Monitorizando...'}) async {}

  @override
  Future<void> stop() async {}
}

class _FakeSensorCaptureService extends SensorCaptureService {
  final _controller = StreamController<SensorSnapshot>.broadcast();

  @override
  Stream<SensorSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

class _FakeSlidingWindowBuilder extends SlidingWindowBuilder {
  @override
  TelemetryWindow? add(SensorSnapshot snapshot, {DateTime? capturedAt}) => null;
}

class _FakeTelemetryService extends TelemetryService {
  @override
  Future<WindowPrediction> sendWindow({
    required String monitoredPersonId,
    required String deviceId,
    required String deviceToken,
    required DateTime windowStart,
    required DateTime windowEnd,
    required int sampleRateHz,
    required Map<String, List<double>> samples,
    Map<String, dynamic>? context,
  }) async {
    return WindowPrediction(
      windowId: 'win-test',
      fallDetected: false,
      confidence: 0.1,
      modelVersion: 'test',
      latencyMs: 1,
    );
  }
}
