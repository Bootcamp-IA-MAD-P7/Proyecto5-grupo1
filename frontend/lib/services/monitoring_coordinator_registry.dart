import 'package:flutter/foundation.dart';

import 'monitoring_coordinator.dart';

/// Holds the active [MonitoringCoordinator] so logout can shut it down — ADR-12 / T2c.10.
class MonitoringCoordinatorRegistry {
  static final MonitoringCoordinatorRegistry instance =
      MonitoringCoordinatorRegistry._();

  MonitoringCoordinatorRegistry._();

  MonitoringCoordinator? _active;

  void register(MonitoringCoordinator coordinator) {
    _active = coordinator;
  }

  void unregister(MonitoringCoordinator coordinator) {
    if (identical(_active, coordinator)) {
      _active = null;
    }
  }

  Future<void> shutdownIfActive() async {
    final coordinator = _active;
    if (coordinator == null) return;
    await coordinator.shutdown();
    _active = null;
  }

  @visibleForTesting
  static void resetForTests() {
    instance._active = null;
  }
}
