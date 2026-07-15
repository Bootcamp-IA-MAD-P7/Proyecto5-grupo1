import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/l10n.dart';
import '../models/monitored_person.dart';
import '../models/retrain_status.dart';
import '../models/user.dart';
import '../services/admin_service.dart';
import '../services/auth_session.dart';
import 'app_shell.dart';

/// SL-40 / T2.17 + T4.5 — Perfil IT_ADMIN: historial, export, usuarios, MLOps.
class ItAdminScreen extends StatefulWidget {
  final AuthSession session;
  final ValueChanged<Locale> onLocaleChanged;
  final AdminService? adminService;

  const ItAdminScreen({
    super.key,
    required this.session,
    required this.onLocaleChanged,
    this.adminService,
  });

  @override
  State<ItAdminScreen> createState() => _ItAdminScreenState();
}

class _ItAdminScreenState extends State<ItAdminScreen> {
  late final AdminService _admin;

  @override
  void initState() {
    super.initState();
    _admin = widget.adminService ?? AdminService();
  }
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.itAdminTitle),
        actions: [
          AppTopActions(
            session: widget.session,
            onLocaleChanged: widget.onLocaleChanged,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.history), label: l10n.history),
          NavigationDestination(icon: const Icon(Icons.download), label: l10n.export),
          NavigationDestination(icon: const Icon(Icons.people), label: l10n.users),
          NavigationDestination(icon: const Icon(Icons.model_training), label: l10n.mlops),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _HistoryTab(admin: _admin),
          _ExportTab(admin: _admin),
          _UsersTab(admin: _admin),
          _MlopsTab(admin: _admin),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final AdminService admin;
  const _HistoryTab({required this.admin});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder(
      future: admin.getHistory(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final items = snap.data!.content;
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final h = items[i];
            return ListTile(
              title: Text(h.monitoredPersonName),
              subtitle: Text(
                '${h.detectedAt.toLocal()} · ${l10n.confidence((h.confidence * 100).toStringAsFixed(1))}',
              ),
              trailing: Text(h.alertStatus.name),
            );
          },
        );
      },
    );
  }
}

class _ExportTab extends StatefulWidget {
  final AdminService admin;
  const _ExportTab({required this.admin});

  @override
  State<_ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<_ExportTab> {
  bool _downloading = false;

  Future<void> _downloadExport() async {
    if (_downloading) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _downloading = true);
    try {
      final download = await widget.admin.downloadExport();
      if (!mounted) return;

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${download.filename}');
        await file.writeAsBytes(download.bytes);
        await OpenFilex.open(file.path);
      }

      messenger.showSnackBar(SnackBar(content: Text(l10n.exportDownloadSuccess)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportDownloadError)));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.exportDescription, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _downloading ? null : _downloadExport,
              icon: _downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download),
              label: Text(l10n.exportDataset),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  final AdminService admin;
  const _UsersTab({required this.admin});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late Future<PagedResponse<User>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.admin.getUsers();
  }

  Future<void> _toggle(User user, bool active) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await widget.admin.setUserActive(user.id, active: active);
      if (!mounted) return;
      setState(() => _future = widget.admin.getUsers());
      messenger.showSnackBar(SnackBar(content: Text(l10n.userStatusUpdated)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.userStatusError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<PagedResponse<User>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snap.data!.content;
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            return SwitchListTile(
              value: u.active,
              onChanged: (v) => _toggle(u, v),
              title: Text(u.fullName),
              subtitle: Text(
                '${u.email} · ${u.role.name} · '
                '${u.active ? l10n.userActive : l10n.userInactive}',
              ),
            );
          },
        );
      },
    );
  }
}

class _MlopsTab extends StatefulWidget {
  final AdminService admin;
  const _MlopsTab({required this.admin});

  @override
  State<_MlopsTab> createState() => _MlopsTabState();
}

class _MlopsTabState extends State<_MlopsTab> {
  RetrainJobStatus? _status;
  bool _loading = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    try {
      final status = await widget.admin.getRetrainStatus();
      if (!mounted) return;
      setState(() => _status = status);
      _syncPolling(status);
    } catch (_) {
      // Keep last known status on poll errors.
    }
  }

  void _syncPolling(RetrainJobStatus status) {
    _pollTimer?.cancel();
    if (status.isRunning) {
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refreshStatus());
    }
  }

  Future<void> _startRetrain() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _loading = true);
    try {
      await widget.admin.startRetrain();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.mlopsRetrainStarted)));
      await _refreshStatus();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.mlopsRetrainError)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _decisionLabel(AppLocalizations l10n, String? decision) {
    switch (decision?.toLowerCase()) {
      case 'promoted':
        return l10n.mlopsDecisionPromoted;
      case 'candidate':
        return l10n.mlopsDecisionCandidate;
      case 'discarded':
        return l10n.mlopsDecisionDiscarded;
      default:
        return l10n.mlopsDecisionPending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = _status;
    final details = status?.details;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.mlopsTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(l10n.mlopsDescription),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: (_loading || (status?.isRunning ?? false)) ? null : _startRetrain,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(l10n.mlopsStartRetrain),
        ),
        if (status?.isRunning ?? false) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.mlopsRetrainRunning)),
            ],
          ),
        ],
        if (status != null) ...[
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (status.phase != null)
                    Text('${l10n.mlopsPhase}: ${status.phase!.toUpperCase()}'),
                  if (status.message != null) ...[
                    const SizedBox(height: 8),
                    Text(status.message!),
                  ],
                  if (status.decision != null) ...[
                    const SizedBox(height: 8),
                    Text('${l10n.mlopsDecision}: ${_decisionLabel(l10n, status.decision)}'),
                  ],
                  if (status.modelVersion != null) ...[
                    const SizedBox(height: 8),
                    Text('${l10n.mlopsModelVersion}: ${status.modelVersion}'),
                  ],
                  if (details?.newRecall != null) ...[
                    const SizedBox(height: 8),
                    Text('${l10n.mlopsRecall}: ${(details!.newRecall! * 100).toStringAsFixed(1)}%'),
                  ],
                  if (details?.currentRecall != null) ...[
                    const SizedBox(height: 4),
                    Text('${l10n.mlopsCurrentRecall}: ${(details!.currentRecall! * 100).toStringAsFixed(1)}%'),
                  ],
                  if (details?.overfittingGap != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.mlopsOverfitting}: ${(details!.overfittingGap! * 100).toStringAsFixed(1)}%',
                    ),
                  ],
                  if (details?.feedbackRecords != null) ...[
                    const SizedBox(height: 8),
                    Text('${l10n.mlopsFeedbackRecords}: ${details!.feedbackRecords}'),
                  ],
                  if (details?.augmentedWindows != null) ...[
                    const SizedBox(height: 4),
                    Text('${l10n.mlopsAugmentedWindows}: ${details!.augmentedWindows}'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
