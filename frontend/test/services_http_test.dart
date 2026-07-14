import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentilife/config/window_contract.dart';
import 'package:sentilife/models/alert.dart';
import 'package:sentilife/models/user.dart';
import 'package:sentilife/services/admin_service.dart';
import 'package:sentilife/services/alerts_service.dart';
import 'package:sentilife/services/auth_service.dart';
import 'package:sentilife/services/devices_service.dart';
import 'package:sentilife/services/exceptions.dart';
import 'package:sentilife/services/monitored_service.dart';
import 'package:sentilife/services/telemetry_service.dart';

/// Contratos FE↔BE verificados contra JSON real del backend Java usando
/// `MockClient` (test doble HTTP). Sin datos fake: se ejercita el código de
/// producción de cada servicio. Las respuestas replican la serialización de
/// Spring (paginación con la clave `number`, spec §6).
http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _paged(List<Object> content) => {
      'content': content,
      // Spring Data serializa el índice de página como 'number'.
      'number': 0,
      'size': 20,
      'totalElements': content.length,
      'totalPages': 1,
    };

Map<String, dynamic> _personJson({
  String id = 'uuid-person-001',
  bool withPrediction = false,
}) =>
    {
      'id': id,
      'fullName': 'Manuel Pérez',
      'birthDate': '1948-03-12',
      'age': 78,
      'sex': 'M',
      'weightKg': 78.5,
      'heightCm': 172,
      'emergencyContact': '+34600111222',
      'consentStatus': 'ACTIVE',
      'monitoringStatus': withPrediction ? 'ACTIVE' : 'INACTIVE',
      'pairingCode': 'SL-84F2K9',
      'createdAt': '2026-07-08T10:00:00Z',
      if (withPrediction) 'lastSeenAt': '2026-07-13T10:00:00Z',
      if (withPrediction)
        'lastPrediction': {
          'fallDetected': false,
          'confidence': 0.03,
          'modelVersion': 'baseline-v1',
          'timestamp': '2026-07-13T10:00:00Z',
        },
    };

void main() {
  // ── AuthService ────────────────────────────────────────────────────────────
  group('AuthService (HTTP real)', () {
    test('login parsea tokens y usuario del backend', () async {
      final auth = AuthService(
        client: MockClient((req) async {
          expect(req.url.path, endsWith('/auth/login'));
          return _json({
            'accessToken': 'access-abc',
            'refreshToken': 'refresh-abc',
            'expiresIn': 900,
            'user': {
              'id': 'uuid-cg-1',
              'email': 'caregiver@test.com',
              'fullName': 'Ana García',
              'role': 'CAREGIVER',
              'locale': 'es',
            },
          });
        }),
      );

      final tokens =
          await auth.login(email: 'caregiver@test.com', password: 'x');
      expect(tokens.accessToken, 'access-abc');
      expect(tokens.user.role, UserRole.caregiver);
      expect(tokens.user.email, 'caregiver@test.com');
    });

    test('login con 401 lanza AuthException 401', () async {
      final auth = AuthService(
        client: MockClient((req) async => _json(
              {'error': 'INVALID_CREDENTIALS', 'message': 'Credenciales'},
              401,
            )),
      );

      expect(
        () => auth.login(email: 'x@test.com', password: 'bad'),
        throwsA(isA<AuthException>().having((e) => e.status, 'status', 401)),
      );
    });

    test('refresh parsea tokens rotados del backend', () async {
      final auth = AuthService(
        client: MockClient((req) async {
          expect(req.url.path, endsWith('/auth/refresh'));
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['refreshToken'], 'refresh-old');
          return _json({
            'accessToken': 'access-new',
            'refreshToken': 'refresh-new',
            'expiresIn': 900,
            'user': {
              'id': 'uuid-cg-1',
              'email': 'caregiver@test.com',
              'fullName': 'Ana García',
              'role': 'CAREGIVER',
              'locale': 'es',
            },
          });
        }),
      );

      final tokens = await auth.refresh('refresh-old');
      expect(tokens.accessToken, 'access-new');
      expect(tokens.refreshToken, 'refresh-new');
    });

    test('register lee el usuario de la envoltura {user}', () async {
      final auth = AuthService(
        client: MockClient((req) async => _json({
              'accessToken': 'a',
              'refreshToken': 'r',
              'expiresIn': 900,
              'user': {
                'id': 'uuid-new',
                'email': 'nuevo@test.com',
                'fullName': 'Nuevo',
                'role': 'CAREGIVER',
                'locale': 'es',
              },
            })),
      );

      final user = await auth.register(
        email: 'nuevo@test.com',
        password: 'Pass1234!',
        fullName: 'Nuevo',
        role: UserRole.caregiver,
      );
      expect(user.email, 'nuevo@test.com');
      expect(user.role, UserRole.caregiver);
    });
  });

  // ── MonitoredService ───────────────────────────────────────────────────────
  group('MonitoredService (HTTP real)', () {
    test('list parsea paginación de Spring (clave number)', () async {
      final service = MonitoredService(
        client: MockClient((req) async => _json(_paged([_personJson()]))),
      );

      final result = await service.list();
      expect(result.content, hasLength(1));
      expect(result.page, 0);
      expect(result.content.first.fullName, 'Manuel Pérez');
    });

    test('get embebe lastPrediction/lastSeenAt (T2.27)', () async {
      final service = MonitoredService(
        client: MockClient(
          (req) async => _json(_personJson(withPrediction: true)),
        ),
      );

      final person = await service.get('uuid-person-001');
      expect(person.monitoringStatus.name, 'active');
      expect(person.lastSeenAt, isNotNull);
      expect(person.lastPrediction, isNotNull);
      expect(person.lastPrediction!.modelVersion, 'baseline-v1');
    });

    test('get con 404 lanza ApiException 404', () async {
      final service = MonitoredService(
        client: MockClient(
          (req) async => _json({'error': 'NOT_FOUND', 'message': 'x'}, 404),
        ),
      );

      expect(
        () => service.get('no-existe'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });

    test('create envía monitoredUserEmail y parsea la persona creada', () async {
      late Map<String, dynamic> sent;
      final service = MonitoredService(
        client: MockClient((req) async {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return _json(_personJson(id: 'uuid-created'));
        }),
      );

      final person = await service.create(
        monitoredUserEmail: 'monitored@test.com',
        fullName: 'Manuel Pérez',
        birthDate: '1948-03-12',
        sex: 'M',
        weightKg: 78.5,
        heightCm: 172,
      );
      expect(sent['monitoredUserEmail'], 'monitored@test.com');
      expect(sent['fullName'], 'Manuel Pérez');
      expect(person.id, 'uuid-created');
    });

    test('create con 404 lanza ApiException NOT_FOUND', () async {
      final service = MonitoredService(
        client: MockClient(
          (req) async => _json(
            {'error': 'NOT_FOUND', 'message': 'Monitored user not found'},
            404,
          ),
        ),
      );

      expect(
        () => service.create(
          monitoredUserEmail: 'missing@test.com',
          fullName: 'Manuel Pérez',
          birthDate: '1948-03-12',
          sex: 'M',
          weightKg: 78.5,
          heightCm: 172,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 404)
              .having((e) => e.error, 'error', 'NOT_FOUND'),
        ),
      );
    });

    test('create con 400 lanza ApiException BAD_REQUEST', () async {
      final service = MonitoredService(
        client: MockClient(
          (req) async => _json(
            {
              'error': 'BAD_REQUEST',
              'message': 'Linked account must have MONITORED role',
            },
            400,
          ),
        ),
      );

      expect(
        () => service.create(
          monitoredUserEmail: 'caregiver@test.com',
          fullName: 'Manuel Pérez',
          birthDate: '1948-03-12',
          sex: 'M',
          weightKg: 78.5,
          heightCm: 172,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.error, 'error', 'BAD_REQUEST'),
        ),
      );
    });

    test('create con 409 lanza ApiException CONFLICT', () async {
      final service = MonitoredService(
        client: MockClient(
          (req) async => _json(
            {
              'error': 'CONFLICT',
              'message': 'MONITORED account is already linked',
            },
            409,
          ),
        ),
      );

      expect(
        () => service.create(
          monitoredUserEmail: 'linked@test.com',
          fullName: 'Manuel Pérez',
          birthDate: '1948-03-12',
          sex: 'M',
          weightKg: 78.5,
          heightCm: 172,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.error, 'error', 'CONFLICT'),
        ),
      );
    });

    test('getMyProfile devuelve la ficha del MONITORED autenticado', () async {
      final service = MonitoredService(
        client: MockClient((req) async {
          expect(req.url.path, endsWith('/monitored-persons/me'));
          return _json(_personJson());
        }),
      );

      final person = await service.getMyProfile();
      expect(person.id, 'uuid-person-001');
      expect(person.fullName, 'Manuel Pérez');
    });

    test('getMyProfile con 404 indica perfil sin vincular', () async {
      final service = MonitoredService(
        client: MockClient(
          (req) async => _json(
            {
              'error': 'NOT_FOUND',
              'message': 'Monitored profile not linked',
            },
            404,
          ),
        ),
      );

      expect(
        () => service.getMyProfile(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 404)
              .having((e) => e.message, 'message', 'Monitored profile not linked'),
        ),
      );
    });

    test('revokeConsent (DELETE) completa sin error', () async {
      final service = MonitoredService(
        client: MockClient((req) async {
          expect(req.method, 'DELETE');
          return http.Response('', 200);
        }),
      );

      await expectLater(service.revokeConsent('uuid-person-001'), completes);
    });
  });

  // ── AlertsService ──────────────────────────────────────────────────────────
  group('AlertsService (HTTP real)', () {
    Map<String, dynamic> alertJson(String id, String status) => {
          'id': id,
          'monitoredPersonId': 'uuid-person-001',
          'monitoredPersonName': 'Manuel Pérez',
          'detectedAt': '2026-07-13T10:00:00Z',
          'confidence': 0.92,
          'modelVersion': 'baseline-v1',
          'status': status,
        };

    test('list parsea alertas y filtra por status en query', () async {
      final service = AlertsService(
        client: MockClient((req) async {
          expect(req.url.queryParameters['status'], 'PENDING');
          return _json(_paged([alertJson('uuid-alert-001', 'PENDING')]));
        }),
      );

      final result = await service.list(status: AlertStatus.pending);
      expect(result.content, hasLength(1));
      expect(result.content.first.status, AlertStatus.pending);
    });

    test('review (PATCH) envía status y completa sin error', () async {
      late Map<String, dynamic> sent;
      final service = AlertsService(
        client: MockClient((req) async {
          expect(req.method, 'PATCH');
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          // Backend responde FeedbackResponse, no Alert (spec §6.5).
          return _json({
            'alertId': 'uuid-alert-001',
            'status': 'CONFIRMED',
            'feedbackLabelId': 'uuid-fb-001',
          });
        }),
      );

      await service.review('uuid-alert-001',
          status: AlertStatus.confirmed, comment: 'Caída real');
      expect(sent['status'], 'CONFIRMED');
      expect(sent['comment'], 'Caída real');
    });

    test('review con 404 lanza ApiException 404', () async {
      final service = AlertsService(
        client: MockClient(
          (req) async => _json({'error': 'NOT_FOUND', 'message': 'x'}, 404),
        ),
      );

      expect(
        () => service.review('no-existe', status: AlertStatus.dismissed),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });
  });

  // ── TelemetryService ───────────────────────────────────────────────────────
  group('TelemetryService (HTTP real)', () {
    final windowEnd = DateTime.now();
    final windowStart = windowEnd.subtract(
      const Duration(milliseconds: WindowContract.durationMs),
    );

    Map<String, List<double>> samples() => {
          'accX': List.filled(WindowContract.samplesPerSignal, 0.1),
          'accY': List.filled(WindowContract.samplesPerSignal, 9.8),
          'accZ': List.filled(WindowContract.samplesPerSignal, 0.1),
          'gyroX': List.filled(WindowContract.samplesPerSignal, 0.1),
          'gyroY': List.filled(WindowContract.samplesPerSignal, 0.1),
          'gyroZ': List.filled(WindowContract.samplesPerSignal, 0.1),
        };

    test('sendWindow parsea la predicción anidada', () async {
      final service = TelemetryService(
        client: MockClient((req) async {
          expect(req.method, 'POST');
          expect(req.url.path, endsWith('/telemetry/windows'));
          expect(req.headers['authorization'], 'Bearer device-token-1');
          return _json({
              'windowId': 'w-1',
              'prediction': {
                'fallDetected': true,
                'confidence': 0.91,
                'modelVersion': 'baseline-v1',
                'latencyMs': 80,
              },
            });
        }),
      );

      final result = await service.sendWindow(
        monitoredPersonId: 'uuid-person-001',
        deviceId: 'android-1',
        deviceToken: 'device-token-1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        sampleRateHz: WindowContract.sampleRateHz,
        samples: samples(),
      );
      expect(result.fallDetected, isTrue);
      expect(result.confidence, 0.91);
      expect(result.modelVersion, 'baseline-v1');
    });

    test('sendWindow con 403 lanza TelemetryException CONSENT_REQUIRED',
        () async {
      final service = TelemetryService(
        client: MockClient((req) async => http.Response('', 403)),
      );

      expect(
        () => service.sendWindow(
          monitoredPersonId: 'uuid-person-001',
          deviceId: 'android-1',
          deviceToken: 'device-token-1',
          windowStart: windowStart,
          windowEnd: windowEnd,
          sampleRateHz: WindowContract.sampleRateHz,
          samples: samples(),
        ),
        throwsA(
            isA<TelemetryException>().having((e) => e.status, 'status', 403)),
      );
    });

    test('getStatus parsea lastPrediction plano (spec §6.3)', () async {
      final service = TelemetryService(
        client: MockClient((req) async => _json({
              'monitoringStatus': 'ACTIVE',
              'lastWindowAt': '2026-07-13T10:00:00Z',
              'lastPrediction': {
                'fallDetected': false,
                'confidence': 0.04,
                'modelVersion': 'baseline-v1',
                'latencyMs': 120,
              },
            })),
      );

      final status = await service.getStatus('uuid-person-001');
      expect(status.monitoringStatus, 'ACTIVE');
      expect(status.lastWindowAt, isNotNull);
      expect(status.lastPrediction!.modelVersion, 'baseline-v1');
    });
  });

  // ── DevicesService ─────────────────────────────────────────────────────────
  group('DevicesService (HTTP real)', () {
    test('pair parsea monitoredPersonId y deviceToken', () async {
      final service = DevicesService(
        client: MockClient((req) async => _json({
              'monitoredPersonId': 'uuid-person-001',
              'deviceToken': 'device-token-abc',
            })),
      );

      final result =
          await service.pair(pairingCode: 'SL-84F2K9', deviceId: 'android-1');
      expect(result.monitoredPersonId, 'uuid-person-001');
      expect(result.deviceToken, 'device-token-abc');
    });

    test('pair con 404 lanza DeviceException 404', () async {
      final service = DevicesService(
        client: MockClient(
          (req) async => _json({'error': 'INVALID_CODE', 'message': 'x'}, 404),
        ),
      );

      expect(
        () => service.pair(pairingCode: 'BAD', deviceId: 'android-1'),
        throwsA(isA<DeviceException>().having((e) => e.status, 'status', 404)),
      );
    });

    test('registerPushToken completa sin error', () async {
      final service = DevicesService(
        client: MockClient((req) async => http.Response('', 200)),
      );

      await expectLater(
        service.registerPushToken(
            fcmToken: 'fcm-1', deviceId: 'android-1'),
        completes,
      );
    });

    test('unregisterPushToken DELETE devuelve 204', () async {
      final service = DevicesService(
        client: MockClient((req) async {
          expect(req.method, 'DELETE');
          expect(req.url.path, endsWith('/push-token/android-1'));
          return http.Response('', 204);
        }),
      );

      await expectLater(
        service.unregisterPushToken(deviceId: 'android-1'),
        completes,
      );
    });
  });

  // ── AdminService ───────────────────────────────────────────────────────────
  group('AdminService (HTTP real)', () {
    test('getHistory parsea alertId y fallDetected por defecto', () async {
      final service = AdminService(
        client: MockClient((req) async => _json(_paged([
              {
                'alertId': 'uuid-alert-001',
                'monitoredPersonId': 'uuid-person-001',
                'monitoredPersonName': 'Manuel Pérez',
                'detectedAt': '2026-07-13T10:00:00Z',
                'confidence': 0.92,
                'modelVersion': 'baseline-v1',
                'alertStatus': 'CONFIRMED',
                'feedbackLabel': 'TRUE_FALL',
              }
            ]))),
      );

      final result = await service.getHistory();
      expect(result.content, hasLength(1));
      expect(result.content.first.id, 'uuid-alert-001');
      expect(result.content.first.fallDetected, isTrue);
      expect(result.content.first.feedbackLabel, 'TRUE_FALL');
    });

    test('getUsers parsea los 3 roles', () async {
      final service = AdminService(
        client: MockClient((req) async => _json(_paged([
              {
                'id': 'u1',
                'email': 'caregiver@test.com',
                'fullName': 'Ana',
                'role': 'CAREGIVER',
                'active': true,
              },
              {
                'id': 'u2',
                'email': 'monitored@test.com',
                'fullName': 'Manuel',
                'role': 'MONITORED',
                'active': true,
              },
              {
                'id': 'u3',
                'email': 'admin@test.com',
                'fullName': 'IT',
                'role': 'IT_ADMIN',
                'active': true,
              },
            ]))),
      );

      final result = await service.getUsers();
      final roles = result.content.map((u) => u.role).toSet();
      expect(
        roles,
        containsAll(
            [UserRole.caregiver, UserRole.monitored, UserRole.itAdmin]),
      );
    });

    test('setUserActive envía active y parsea el usuario (T2.31)', () async {
      late Map<String, dynamic> sent;
      final service = AdminService(
        client: MockClient((req) async {
          expect(req.method, 'PATCH');
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return _json({
            'id': 'u1',
            'email': 'caregiver@test.com',
            'fullName': 'Ana',
            'role': 'CAREGIVER',
            'active': false,
          });
        }),
      );

      final updated = await service.setUserActive('u1', active: false);
      expect(sent['active'], false);
      expect(updated.active, isFalse);
    });

    test('startRetrain con 409 lanza AdminException 409', () async {
      final service = AdminService(
        client: MockClient(
          (req) async =>
              _json({'error': 'RETRAIN_RUNNING', 'message': 'x'}, 409),
        ),
      );

      expect(
        () => service.startRetrain(),
        throwsA(isA<AdminException>().having((e) => e.status, 'status', 409)),
      );
    });

    test('getRetrainStatus parsea el job completado', () async {
      final service = AdminService(
        client: MockClient((req) async => _json({
              'status': 'completed',
              'decision': 'promoted',
              'details': {
                'currentRecall': 0.91,
                'newRecall': 0.94,
                'overfittingGap': 0.03,
                'driftDetected': false,
                'modelReloaded': true,
              },
            })),
      );

      final status = await service.getRetrainStatus();
      expect(status.decision, 'promoted');
      expect(status.details!.newRecall, greaterThan(status.details!.currentRecall));
    });
  });
}
