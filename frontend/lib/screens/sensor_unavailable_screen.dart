import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/user.dart';
import '../services/auth_session.dart';
import '../services/sensor_capability_service.dart';
import 'app_shell.dart';

/// Blocking screen when required IMU sensors are missing — RF-40 / T4e.1.
class SensorUnavailableScreen extends StatelessWidget {
  const SensorUnavailableScreen({
    super.key,
    required this.session,
    required this.onLocaleChanged,
    required this.result,
    this.onRetry,
  });

  final AuthSession session;
  final ValueChanged<Locale> onLocaleChanged;
  final ImuCapabilityResult result;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.monitoredTitle),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          AppTopActions(
            session: session,
            onLocaleChanged: onLocaleChanged,
            role: UserRole.monitored,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.sensors_off,
            size: 72,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.sensorUnavailableTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(l10n.sensorUnavailableBody),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SensorRow(
                    label: l10n.accelerometer,
                    available: result.accelerometerAvailable,
                    availableText: l10n.sensorAvailable,
                    missingText: l10n.sensorMissing,
                  ),
                  const SizedBox(height: 12),
                  _SensorRow(
                    label: l10n.gyroscope,
                    available: result.gyroscopeAvailable,
                    availableText: l10n.sensorAvailable,
                    missingText: l10n.sensorMissing,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (onRetry != null)
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.sensorUnavailableRetry),
            ),
        ],
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({
    required this.label,
    required this.available,
    required this.availableText,
    required this.missingText,
  });

  final String label;
  final bool available;
  final String availableText;
  final String missingText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          available ? Icons.check_circle : Icons.cancel,
          color: available ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Text(
          available ? availableText : missingText,
          style: TextStyle(color: available ? Colors.green : Colors.red),
        ),
      ],
    );
  }
}
