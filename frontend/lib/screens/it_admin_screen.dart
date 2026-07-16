import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/l10n.dart';
import '../models/monitored_person.dart';
import '../models/retrain_prerequisites.dart';
import '../models/retrain_status.dart';
import '../models/user.dart';
import '../services/admin_service.dart';
import '../services/auth_session.dart';
import '../services/exceptions.dart';
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
            role: UserRole.itAdmin,
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

class _HistoryTab extends StatefulWidget {
  final AdminService admin;
  const _HistoryTab({required this.admin});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  static const _pageSize = 20;

  int _page = 0;
  int _totalPages = 0;
  int _totalElements = 0;
  List<HistoryEntry> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPage(0));
  }

  Future<void> _loadPage(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await widget.admin.getHistory(page: page, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _page = response.page;
        _totalPages = response.totalPages;
        _totalElements = response.totalElements;
        _items = response.content;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.historyLoadError;
      });
    }
  }

  Future<void> _goToPage(int page) async {
    if (page < 0 || page >= _totalPages || page == _page) return;
    await _loadPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(child: Text(_error!));
    }
    if (_items.isEmpty) {
      return Center(child: Text(l10n.noHistory));
    }

    final hasPagination = _totalPages > 1;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadPage(_page),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _items.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      l10n.historyPageIndicator(
                        _page + 1,
                        _totalPages == 0 ? 1 : _totalPages,
                        _totalElements,
                      ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  );
                }
                final h = _items[i - 1];
                return ListTile(
                  title: Text(h.monitoredPersonName),
                  subtitle: Text(
                    '${h.detectedAt.toLocal()} · ${l10n.confidence((h.confidence * 100).toStringAsFixed(1))}',
                  ),
                  trailing: Text(h.alertStatus.name),
                );
              },
            ),
          ),
        ),
        if (hasPagination)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: l10n.historyPreviousPage,
                    onPressed: _loading || _page <= 0
                        ? null
                        : () => unawaited(_goToPage(_page - 1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(l10n.historyPageShort(_page + 1, _totalPages)),
                  IconButton(
                    tooltip: l10n.historyNextPage,
                    onPressed: _loading || _page >= _totalPages - 1
                        ? null
                        : () => unawaited(_goToPage(_page + 1)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
      ],
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
  RetrainPrerequisites? _prerequisites;
  bool _loading = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        widget.admin.getRetrainStatus(),
        widget.admin.getRetrainPrerequisites(),
      ]);
      if (!mounted) return;
      final status = results[0] as RetrainJobStatus;
      setState(() {
        _status = status;
        _prerequisites = results[1] as RetrainPrerequisites;
      });
      _syncPolling(status);
    } catch (_) {
      // Keep last known state on poll errors.
    }
  }

  void _syncPolling(RetrainJobStatus status) {
    _pollTimer?.cancel();
    if (status.isRunning) {
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    }
  }

  Future<void> _showInsufficientFeedbackDialog() async {
    final l10n = context.l10n;
    final prereq = _prerequisites;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.info_outline, size: 40),
        title: Text(l10n.mlopsInsufficientFeedbackTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prereq != null)
                Text(
                  l10n.mlopsFeedbackProgress(
                    prereq.feedbackRecords,
                    prereq.minFeedbackRecords,
                  ),
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              const SizedBox(height: 12),
              Text(l10n.mlopsInsufficientFeedbackBody),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.helpClose),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmRetrain() async {
    final l10n = context.l10n;
    final prereq = _prerequisites;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mlopsConfirmTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prereq != null) ...[
                Text(
                  l10n.mlopsFeedbackProgress(
                    prereq.feedbackRecords,
                    prereq.minFeedbackRecords,
                  ),
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                if (prereq.feedbackRecords < prereq.recommendedFeedbackRecords)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.mlopsFeedbackRecommended(prereq.recommendedFeedbackRecords),
                      style: TextStyle(color: Theme.of(ctx).colorScheme.tertiary),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              Text(l10n.mlopsConfirmBody),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.mlopsStartRetrain),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _startRetrain() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final prereq = _prerequisites;

    if (prereq != null && !prereq.eligible) {
      await _showInsufficientFeedbackDialog();
      return;
    }

    if (!await _confirmRetrain()) return;

    setState(() => _loading = true);
    try {
      await widget.admin.startRetrain();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.mlopsRetrainStarted)));
      await _refresh();
    } on AdminException catch (e) {
      if (!mounted) return;
      if (e.status == 400 && (_prerequisites?.eligible == false)) {
        await _showInsufficientFeedbackDialog();
      } else {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
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
    final prereq = _prerequisites;
    final canStart = prereq?.eligible ?? false;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.mlopsTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(l10n.mlopsDescription),
        const SizedBox(height: 16),
        ExpansionTile(
          leading: const Icon(Icons.school_outlined),
          title: Text(l10n.mlopsCriteriaTitle),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(l10n.mlopsCriteriaBody),
            ),
          ],
        ),
        if (prereq != null) ...[
          const SizedBox(height: 8),
          Card(
            color: canStart
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
                : Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
            child: ListTile(
              leading: Icon(
                canStart ? Icons.check_circle_outline : Icons.warning_amber,
                color: canStart
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
              title: Text(l10n.mlopsPrerequisitesTitle),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.mlopsFeedbackProgress(
                    prereq.feedbackRecords,
                    prereq.minFeedbackRecords,
                  )),
                  if (prereq.feedbackRecords < prereq.recommendedFeedbackRecords)
                    Text(l10n.mlopsFeedbackRecommended(prereq.recommendedFeedbackRecords)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: (_loading || (status?.isRunning ?? false) || !canStart)
              ? null
              : _startRetrain,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(l10n.mlopsStartRetrain),
        ),
        if (!canStart && prereq != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _showInsufficientFeedbackDialog,
            icon: const Icon(Icons.info_outline),
            label: Text(l10n.mlopsWhyDisabled),
          ),
        ],
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
