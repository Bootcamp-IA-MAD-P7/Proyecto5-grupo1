import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/auth_session.dart';
import '../services/device_id_service.dart';
import '../services/devices_service.dart';
import '../services/exceptions.dart';
import '../services/monitored_context_store.dart';
import '../services/monitored_service.dart';
import '../services/telemetry_pipeline_service.dart';
import '../services/telemetry_service.dart';
import '../widgets/consent_dialog.dart';
import '../widgets/transparency_dialog.dart';
import 'app_shell.dart';

/// SL-24 / T1.11 — Pantalla MONITORED v1: estado + última evaluación.
/// T2.20 — Consentimiento real contra API Java.
/// T2.21 — Pairing dispositivo antes de consentimiento y telemetría.
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
  final _contextStore = MonitoredContextStore();
  final _monitoredService = MonitoredService();
  final _devicesService = DevicesService();
  final _deviceIdService = DeviceIdService();
  final _pairingCodeController = TextEditingController();
  late final TelemetryPipelineService _pipeline;
  bool _monitoring = false;
  WindowPrediction? _lastPrediction;
  DateTime? _lastWindowAt;
  bool _consentAccepted = false;
  bool _consentInFlight = false;
  bool _pairingInFlight = false;

  StreamSubscription<WindowPrediction>? _predictionSub;

  @override
  void initState() {
    super.initState();
    _consentAccepted = _contextStore.consentActive;
    _pipeline = TelemetryPipelineService(
      onTelemetryError: _handleTelemetryError,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowConsent());
  }

  void _handleTelemetryError(TelemetryException error) {
    if (!mounted || error.status != 403) return;
    unawaited(_stopMonitoring());
    _contextStore.setConsentActive(false);
    setState(() => _consentAccepted = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.consentRequired)),
    );
    _maybeShowConsent();
  }

  Future<void> _maybeShowConsent() async {
    if (_consentAccepted || _consentInFlight || !_contextStore.isPaired) return;

    final accepted = await ConsentDialog.show(context);
    if (!mounted || accepted != true) return;

    await _submitConsent();
  }

  Future<void> _submitPairing() async {
    final pairingCode = _pairingCodeController.text.trim().toUpperCase();
    if (pairingCode.isEmpty || _pairingInFlight) return;

    setState(() => _pairingInFlight = true);
    try {
      final deviceId = await _deviceIdService.getStableDeviceId();
      final result = await _devicesService.pair(
        pairingCode: pairingCode,
        deviceId: deviceId,
      );
      _contextStore.setPairing(
        personId: result.monitoredPersonId,
        deviceId: deviceId,
      );
      if (!mounted) return;
      setState(() => _consentAccepted = _contextStore.consentActive);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pairingSuccess)),
      );
      await _maybeShowConsent();
    } on DeviceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pairingError)),
      );
    } finally {
      if (mounted) setState(() => _pairingInFlight = false);
    }
  }

  Future<void> _submitConsent() async {
    final personId = _contextStore.monitoredPersonId;
    if (personId == null) return;

    setState(() => _consentInFlight = true);
    final locale = Localizations.localeOf(context).languageCode;

    try {
      await _monitoredService.acceptConsent(
        personId,
        policyVersion: consentPolicyVersion(locale),
      );
      _contextStore.setConsentActive(true);
      if (!mounted) return;
      setState(() => _consentAccepted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.consentSaved)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.consentError)),
      );
    } finally {
      if (mounted) setState(() => _consentInFlight = false);
    }
  }

  Future<void> _stopMonitoring() async {
    await _predictionSub?.cancel();
    _predictionSub = null;
    await _pipeline.stopMonitoring();
    if (mounted) setState(() => _monitoring = false);
  }

  Future<void> _toggleMonitoring() async {
    if (!_contextStore.isPaired) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pairingRequired)),
      );
      return;
    }

    if (!_consentAccepted) {
      await _maybeShowConsent();
      if (!_consentAccepted) return;
    }

    final personId = _contextStore.monitoredPersonId;
    final deviceId = _contextStore.deviceId;
    if (personId == null || deviceId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pairingRequired)),
      );
      return;
    }

    if (_monitoring) {
      await _stopMonitoring();
    } else {
      _predictionSub = _pipeline.predictions.listen((prediction) {
        if (!mounted) return;
        setState(() {
          _lastPrediction = prediction;
          _lastWindowAt = DateTime.now();
        });
      });
      await _pipeline.startMonitoring(
        monitoredPersonId: personId,
        deviceId: deviceId,
      );
      setState(() => _monitoring = true);
    }
  }

  @override
  void dispose() {
    _pairingCodeController.dispose();
    _predictionSub?.cancel();
    _pipeline.stopMonitoring();
    _pipeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final user = widget.session.user!;
    final isPaired = _contextStore.isPaired;
    final canPressMonitoring = _monitoring ||
        (isPaired && !_consentInFlight && !_pairingInFlight);

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
          if (!isPaired)
            _buildPairingForm(l10n, theme)
          else
            _buildLinkedCard(l10n, theme),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    color: _monitoring ? Colors.green : Colors.grey,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _monitoring
                        ? l10n.monitoringActive
                        : l10n.monitoringInactive,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _monitoring ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isPaired) ...[
            const SizedBox(height: 12),
            Text(
              l10n.pairingRequired,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ] else if (!_consentAccepted) ...[
            const SizedBox(height: 12),
            Text(
              l10n.consentRequired,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Text(l10n.lastEvaluation, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_lastPrediction != null) ...[
            Card(
              color: _lastPrediction!.fallDetected
                  ? Colors.red[50]
                  : Colors.green[50],
              child: ListTile(
                leading: Icon(
                  _lastPrediction!.fallDetected
                      ? Icons.warning
                      : Icons.check_circle,
                  color: _lastPrediction!.fallDetected
                      ? Colors.red
                      : Colors.green,
                ),
                title: Text(
                  _lastPrediction!.fallDetected
                      ? l10n.fallDetected
                      : l10n.noFall,
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
                l10n.lastWindowAt(
                    _lastWindowAt!.toLocal().toString().substring(0, 19)),
                style: theme.textTheme.bodySmall,
              ),
          ] else
            Text(l10n.noEvaluationYet, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: canPressMonitoring ? _toggleMonitoring : null,
              icon: Icon(_monitoring ? Icons.stop : Icons.sensors),
              label: Text(
                  _monitoring ? l10n.stopMonitoring : l10n.startMonitoring),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairingForm(AppLocalizations l10n, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.pairingTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _pairingCodeController,
              enabled: !_pairingInFlight,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l10n.pairingCodeLabel,
                hintText: l10n.pairingCodeHint,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submitPairing(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _pairingInFlight ? null : _submitPairing,
                icon: _pairingInFlight
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: Text(l10n.pairDevice),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedCard(AppLocalizations l10n, ThemeData theme) {
    return Card(
      color: Colors.green[50],
      child: ListTile(
        leading: Icon(Icons.link, color: theme.colorScheme.primary),
        title: Text(
          l10n.deviceLinked,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(l10n.deviceLinkedSubtitle),
      ),
    );
  }
}
