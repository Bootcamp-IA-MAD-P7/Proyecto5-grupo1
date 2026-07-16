import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/monitored_person.dart';
import '../models/user.dart';
import '../services/auth_session.dart';
import '../services/device_id_service.dart';
import '../services/devices_service.dart';
import '../services/exceptions.dart';
import '../services/monitoring_coordinator.dart';
import '../services/monitoring_coordinator_registry.dart';
import '../services/monitored_context_store.dart';
import '../services/monitored_service.dart';
import '../services/sensor_capability_service.dart';
import '../services/telemetry_service.dart';
import '../widgets/consent_dialog.dart';
import '../widgets/live_sensor_charts.dart';
import '../widgets/transparency_dialog.dart';
import 'app_shell.dart';
import 'sensor_unavailable_screen.dart';

/// Estado de vínculo ficha↔cuenta MONITORED (RF-34).
enum MonitoredLinkStatus { loading, pendingLink, linked }

/// Estado de comprobación IMU obligatoria (RF-40 / T4e.1).
enum ImuGateStatus { checking, available, unavailable }

/// SL-24 / T1.11 — Pantalla MONITORED v1: estado + última evaluación.
/// T2.20 — Consentimiento real contra API Java.
/// T2.21 — Pairing dispositivo antes de consentimiento y telemetría.
class MonitoredScreen extends StatefulWidget {
  final AuthSession session;
  final ValueChanged<Locale> onLocaleChanged;
  final MonitoredContextStore? contextStore;
  final MonitoredService? monitoredService;
  final TelemetryService? telemetryService;
  final MonitoringCoordinator? coordinator;
  final SensorCapabilityService? sensorCapabilityService;

  const MonitoredScreen({
    super.key,
    required this.session,
    required this.onLocaleChanged,
    this.contextStore,
    this.monitoredService,
    this.telemetryService,
    this.coordinator,
    this.sensorCapabilityService,
  });

  @override
  State<MonitoredScreen> createState() => _MonitoredScreenState();
}

class _MonitoredScreenState extends State<MonitoredScreen>
    with SingleTickerProviderStateMixin {
  late final MonitoredContextStore _contextStore;
  late final TelemetryService _telemetryService;
  late final MonitoredService _monitoredService;
  final _devicesService = DevicesService();
  final _deviceIdService = DeviceIdService();
  final _pairingCodeController = TextEditingController();
  late final MonitoringCoordinator _coordinator;
  late final SensorCapabilityService _sensorCapabilityService;
  bool _monitoring = false;
  WindowPrediction? _lastPrediction;
  DateTime? _lastWindowAt;
  bool _consentAccepted = false;
  bool _consentInFlight = false;
  bool _pairingInFlight = false;
  MonitoredLinkStatus _linkStatus = MonitoredLinkStatus.loading;
  ConsentStatus? _backendConsentStatus;
  ImuGateStatus _imuGateStatus = ImuGateStatus.checking;
  ImuCapabilityResult? _imuCapabilityResult;
  late TabController _tabController;

  void _onCoordinatorChanged() {
    if (!mounted) return;
    setState(() {
      _monitoring = _coordinator.isMonitoring;
      _lastPrediction = _coordinator.lastPrediction;
      _lastWindowAt = _coordinator.lastWindowAt;
    });
  }

  @override
  void initState() {
    super.initState();
    _contextStore = widget.contextStore ?? MonitoredContextStore();
    _contextStore.bindUser(widget.session.user!.id);
    _telemetryService = widget.telemetryService ?? TelemetryService();
    _monitoredService = widget.monitoredService ?? MonitoredService();
    _consentAccepted = _contextStore.consentActive;
    _coordinator = widget.coordinator ??
        MonitoringCoordinator(
          onTelemetryError: _handleTelemetryError,
          onCaptureError: _handleCaptureError,
        );
    _sensorCapabilityService =
        widget.sensorCapabilityService ?? SensorCapabilityService();
    _tabController = TabController(length: 2, vsync: this);
    MonitoringCoordinatorRegistry.instance.register(_coordinator);
    _coordinator.addListener(_onCoordinatorChanged);
    unawaited(_checkImuGate());
    _hydrateContext();
  }

  Future<void> _checkImuGate() async {
    final result = await _sensorCapabilityService.checkImuAvailability();
    if (!mounted) return;
    setState(() {
      _imuCapabilityResult = result;
      _imuGateStatus = result.isFullyAvailable
          ? ImuGateStatus.available
          : ImuGateStatus.unavailable;
    });
  }

  Future<void> _hydrateContext() async {
    await _resolveLinkStatus();
    if (!mounted || _linkStatus == MonitoredLinkStatus.pendingLink) return;

    await _contextStore.load();
    if (!mounted) return;
    setState(() => _consentAccepted = _contextStore.consentActive);

    // If local pairing was cleared (e.g. after logout) but the backend still
    // has an active device linked, recover the credentials automatically.
    if (!_contextStore.isPaired && _linkStatus == MonitoredLinkStatus.linked) {
      await _tryRecoverPairing();
      if (!mounted) return;
    }

    if (_contextStore.isPaired) {
      await _loadLastEvaluation();
    }
    await _maybeShowConsent();
  }

  Future<void> _resolveLinkStatus() async {
    try {
      final profile = await _monitoredService.getMyProfile();
      if (!mounted) return;
      _backendConsentStatus = profile.consentStatus;
      setState(() => _linkStatus = MonitoredLinkStatus.linked);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 404) {
        setState(() => _linkStatus = MonitoredLinkStatus.pendingLink);
      } else {
        setState(() => _linkStatus = MonitoredLinkStatus.linked);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _linkStatus = MonitoredLinkStatus.linked);
    }
  }

  /// Attempts to recover pairing credentials from the backend when the local
  /// store is empty (e.g. after logout) but a device is still linked server-side.
  Future<void> _tryRecoverPairing() async {
    try {
      final recovered = await _devicesService.recoverPairing();
      if (recovered == null || !mounted) return;
      await _contextStore.setPairing(
        personId: recovered.monitoredPersonId,
        deviceId: recovered.deviceId,
        deviceToken: recovered.deviceToken,
      );
      // If the backend already has an active consent, sync it locally
      // to avoid re-submitting and hitting the unique constraint.
      if (_backendConsentStatus == ConsentStatus.active) {
        await _contextStore.setConsentActive(true);
      }
      if (!mounted) return;
      setState(() => _consentAccepted = _contextStore.consentActive);
    } catch (_) {
      // Best-effort: if recovery fails, user can still re-pair manually.
    }
  }

  Future<void> _loadLastEvaluation() async {
    final personId = _contextStore.monitoredPersonId;
    if (personId == null) return;

    try {
      final status = await _telemetryService.getStatus(personId);
      if (!mounted) return;
      setState(() {
        _lastPrediction = status.lastPrediction;
        _lastWindowAt = status.lastWindowAt;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.lastEvaluationLoadError)),
      );
    }
  }

  void _handleTelemetryError(TelemetryException error) {
    if (!mounted || error.status != 403) return;
    unawaited(_stopMonitoring());
    _contextStore.setConsentActive(false);
    setState(() => _consentAccepted = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.consentRequired)));
    _maybeShowConsent();
  }

  void _handleCaptureError(Object error) {
    unawaited(_handleCaptureFailure());
  }

  Future<void> _handleCaptureFailure() async {
    await _coordinator.stop();
    if (!mounted) return;
    setState(() => _monitoring = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.sensorStartError)));
  }

  Future<void> _maybeShowConsent() async {
    if (_imuGateStatus != ImuGateStatus.available ||
        _linkStatus != MonitoredLinkStatus.linked ||
        _consentAccepted ||
        _consentInFlight ||
        !_contextStore.isPaired) {
      return;
    }

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
      await _contextStore.setPairing(
        personId: result.monitoredPersonId,
        deviceId: deviceId,
        deviceToken: result.deviceToken,
      );
      if (!mounted) return;
      setState(() => _consentAccepted = _contextStore.consentActive);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.pairingSuccess)));
      await _maybeShowConsent();
    } on DeviceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.pairingError)));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.consentSaved)));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.consentError)));
    } finally {
      if (mounted) setState(() => _consentInFlight = false);
    }
  }

  Future<void> _revokeConsent() async {
    final personId = _contextStore.monitoredPersonId;
    if (personId == null || _consentInFlight) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.revokeConsent),
        content: Text(ctx.l10n.revokeConsentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.revokeConsent),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _consentInFlight = true);
    try {
      await _monitoredService.revokeConsent(personId);
      await _stopMonitoring();
      _contextStore.setConsentActive(false);
      if (!mounted) return;
      setState(() => _consentAccepted = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.consentRevoked)));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.consentRevokeError)));
    } finally {
      if (mounted) setState(() => _consentInFlight = false);
    }
  }

  Future<void> _stopMonitoring() async {
    await _coordinator.stop();
    final personId = _contextStore.monitoredPersonId;
    if (personId != null) {
      unawaited(_monitoredService.notifyMonitoringEvent(personId, started: false));
    }
    if (mounted) setState(() => _monitoring = false);
  }

  Future<void> _toggleMonitoring() async {
    if (_imuGateStatus != ImuGateStatus.available ||
        _linkStatus == MonitoredLinkStatus.pendingLink) {
      return;
    }

    if (!_contextStore.isPaired) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.pairingRequired)));
      return;
    }

    if (!_consentAccepted) {
      await _maybeShowConsent();
      if (!_consentAccepted) return;
    }

    final personId = _contextStore.monitoredPersonId;
    final deviceId = _contextStore.deviceId;
    final deviceToken = _contextStore.deviceToken;
    if (personId == null || deviceId == null || deviceToken == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.pairingRequired)));
      return;
    }

    if (_monitoring) {
      await _stopMonitoring();
    } else {
      try {
        await _coordinator.start(
          monitoredPersonId: personId,
          deviceId: deviceId,
          deviceToken: deviceToken,
        );
        unawaited(_monitoredService.notifyMonitoringEvent(personId, started: true));
        if (!mounted) return;
        setState(() => _monitoring = _coordinator.isMonitoring);
      } catch (_) {
        await _handleCaptureFailure();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pairingCodeController.dispose();
    _coordinator.removeListener(_onCoordinatorChanged);
    MonitoringCoordinatorRegistry.instance.unregister(_coordinator);
    unawaited(_coordinator.shutdown());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_imuGateStatus == ImuGateStatus.checking ||
        _linkStatus == MonitoredLinkStatus.loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.monitoredTitle),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_imuGateStatus == ImuGateStatus.unavailable &&
        _imuCapabilityResult != null) {
      return SensorUnavailableScreen(
        session: widget.session,
        onLocaleChanged: widget.onLocaleChanged,
        result: _imuCapabilityResult!,
        onRetry: () {
          setState(() => _imuGateStatus = ImuGateStatus.checking);
          unawaited(_checkImuGate());
        },
      );
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final user = widget.session.user!;
    final isPendingLink = _linkStatus == MonitoredLinkStatus.pendingLink;
    final isPaired = _contextStore.isPaired;
    final canPressMonitoring = _imuGateStatus == ImuGateStatus.available &&
        !isPendingLink &&
        (_monitoring || (isPaired && !_consentInFlight && !_pairingInFlight));

    if (_linkStatus == MonitoredLinkStatus.loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.monitoredTitle),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.monitoredTitle),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: l10n.monitoredTabStatus),
            Tab(text: l10n.monitoredTabSensors),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: l10n.dataTransparency,
            onPressed: () => TransparencyDialog.show(
              context,
              onViewLiveSensors: () => _tabController.animateTo(1),
            ),
          ),
          AppTopActions(
            session: widget.session,
            onLocaleChanged: widget.onLocaleChanged,
            role: UserRole.monitored,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatusTab(
            l10n,
            theme,
            user,
            isPendingLink,
            isPaired,
            canPressMonitoring,
          ),
          LiveSensorCharts(
            sensorStream: _coordinator.sensorSnapshots,
            isMonitoring: _monitoring,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(
    AppLocalizations l10n,
    ThemeData theme,
    User user,
    bool isPendingLink,
    bool isPaired,
    bool canPressMonitoring,
  ) {
    return ListView(
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
        if (isPendingLink)
          _buildPendingLinkCard(l10n, theme)
        else if (!isPaired)
          _buildPairingForm(l10n, theme)
        else
          _buildLinkedCard(l10n, theme),
        const SizedBox(height: 16),
        if (!isPendingLink)
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
        if (isPendingLink) ...[
          const SizedBox(height: 12),
          Text(
            l10n.pendingLinkBody,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ] else if (!isPaired) ...[
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
        if (!isPendingLink) ...[
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
                  _lastWindowAt!.toLocal().toString().substring(0, 19),
                ),
                style: theme.textTheme.bodySmall,
              ),
          ] else
            Text(
              l10n.noEvaluationYet,
              style: TextStyle(color: Colors.grey[600]),
            ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: canPressMonitoring ? _toggleMonitoring : null,
            icon: Icon(_monitoring ? Icons.stop : Icons.sensors),
            label: Text(
              _monitoring ? l10n.stopMonitoring : l10n.startMonitoring,
            ),
          ),
        ),
        if (!isPendingLink && isPaired && _consentAccepted) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _consentInFlight ? null : _revokeConsent,
            icon: const Icon(Icons.privacy_tip_outlined),
            label: Text(l10n.revokeConsent),
          ),
        ],
      ],
    );
  }

  Widget _buildPendingLinkCard(AppLocalizations l10n, ThemeData theme) {
    return Card(
      color: Colors.orange[50],
      child: ListTile(
        leading: Icon(Icons.hourglass_empty, color: theme.colorScheme.primary),
        title: Text(
          l10n.pendingLinkTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${l10n.pendingLinkStatus}\n${l10n.pendingLinkBody}'),
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
            if (_contextStore.requiresRepairing) ...[
              Text(
                l10n.pairingCredentialMissing,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
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
