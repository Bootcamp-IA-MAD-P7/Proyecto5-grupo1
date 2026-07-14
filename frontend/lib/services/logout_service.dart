import '../models/user.dart';
import 'device_id_service.dart';
import 'devices_service.dart';
import 'monitoring_coordinator_registry.dart';
import 'monitored_context_store.dart';
import 'session_manager.dart';

/// Ordered logout: stop monitoring, cancel queue, unregister push, clear context — ADR-12 / T2c.10.
class LogoutService {
  LogoutService({
    DevicesService? devicesService,
    DeviceIdService? deviceIdService,
    MonitoredContextStore? contextStore,
    MonitoringCoordinatorRegistry? coordinatorRegistry,
  })  : _devicesService = devicesService ?? DevicesService(),
        _deviceIdService = deviceIdService ?? DeviceIdService(),
        _contextStore = contextStore ?? MonitoredContextStore(),
        _coordinatorRegistry =
            coordinatorRegistry ?? MonitoringCoordinatorRegistry.instance;

  final DevicesService _devicesService;
  final DeviceIdService _deviceIdService;
  final MonitoredContextStore _contextStore;
  final MonitoringCoordinatorRegistry _coordinatorRegistry;

  Future<void> performLogout({
    required User user,
    required Future<void> Function() clearSession,
  }) async {
    await _coordinatorRegistry.shutdownIfActive();

    if (user.role == UserRole.caregiver) {
      try {
        final deviceId = await _deviceIdService.getStableDeviceId();
        await _devicesService.unregisterPushToken(deviceId: deviceId);
      } catch (_) {
        // best-effort — session must still clear
      }
    }

    _contextStore.bindUser(user.id);
    await _contextStore.clear();

    await SessionManager().logout();
    await clearSession();
  }
}
