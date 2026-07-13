import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/auth_session.dart';
import '../services/telemetry_pipeline_service.dart';
import '../services/telemetry_service.dart';
import '../widgets/consent_dialog.dart';
import '../widgets/transparency_dialog.dart';
import 'app_shell.dart';

/// SL-24 / T1.11 — Pantalla MONITORED v1: estado + última evaluación.
class MonitoredScreen extends StatefulWidget {
  final AuthSession session;
  final ValueChanged<Locale> onLocaleChanged;

  const MonitoredScreen({
    super.key,
    required this.session,
    required this.onLocaleChanged,
  });

  @override
  State<MonitoredScreen> createState() => _MonitoredScreenState();
}

class _MonitoredScreenState extends State<MonitoredScreen> {
  final _pipeline = TelemetryPipelineService();
  bool _monitoring = false;
  WindowPrediction? _lastPrediction;
  DateTime? _lastWindowAt;
  bool _consentAccepted = false;

  StreamSubscription<WindowPrediction>? _predictionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowConsent());
  }

  Future<void> _maybeShowConsent() async {
    if (_consentAccepted) return;
    final accepted = await ConsentDialog.show(context);
    if (!mounted) return;
    if (accepted == true) {
      setState(() => _consentAccepted = true);
    }
  }

  Future<void> _toggleMonitoring() async {
    if (!_consentAccepted) {
      await _maybeShowConsent();
      if (!_consentAccepted) return;
    }
    if (_monitoring) {
      await _predictionSub?.cancel();
      await _pipeline.stopMonitoring();
      setState(() => _monitoring = false);
    } else {
      _predictionSub = _pipeline.predictions.listen((prediction) {
        if (!mounted) return;
        setState(() {
          _lastPrediction = prediction;
          _lastWindowAt = DateTime.now();
        });
      });
      await _pipeline.startMonitoring(
        monitoredPersonId: 'uuid-monitored-001',
        deviceId: 'device-local',
      );
      setState(() => _monitoring = true);
    }
  }

  @override
  void dispose() {
    _predictionSub?.cancel();
    _pipeline.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final user = widget.session.user!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.monitoredTitle),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: l10n.dataTransparency,
            onPressed: () => TransparencyDialog.show(context),
          ),
          AppTopActions(
            session: widget.session,
            onLocaleChanged: widget.onLocaleChanged,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(user.fullName[0])),
              title: Text(user.fullName),
              subtitle: Text(l10n.roleMonitored),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.circle, color: _monitoring ? Colors.green : Colors.grey, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    _monitoring ? l10n.monitoringActive : l10n.monitoringInactive,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _monitoring ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.lastEvaluation, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_lastPrediction != null) ...[
            Card(
              color: _lastPrediction!.fallDetected ? Colors.red[50] : Colors.green[50],
              child: ListTile(
                leading: Icon(
                  _lastPrediction!.fallDetected ? Icons.warning : Icons.check_circle,
                  color: _lastPrediction!.fallDetected ? Colors.red : Colors.green,
                ),
                title: Text(
                  _lastPrediction!.fallDetected ? l10n.fallDetected : l10n.noFall,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${l10n.confidence(((_lastPrediction!.confidence) * 100).toStringAsFixed(1))}\n'
                  '${l10n.modelVersion}: ${_lastPrediction!.modelVersion}',
                ),
              ),
            ),
            if (_lastWindowAt != null)
              Text(
                l10n.lastWindowAt(_lastWindowAt!.toLocal().toString().substring(0, 19)),
                style: theme.textTheme.bodySmall,
              ),
          ] else
            Text(l10n.noEvaluationYet, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _toggleMonitoring,
              icon: Icon(_monitoring ? Icons.stop : Icons.sensors),
              label: Text(_monitoring ? l10n.stopMonitoring : l10n.startMonitoring),
            ),
          ),
        ],
      ),
    );
  }
}
