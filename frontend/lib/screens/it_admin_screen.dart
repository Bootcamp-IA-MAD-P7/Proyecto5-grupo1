import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/monitored_person.dart';
import '../models/user.dart';
import '../services/admin_service.dart';
import '../services/auth_session.dart';
import 'app_shell.dart';

/// SL-40 / T2.17 — Perfil IT_ADMIN: historial, export, usuarios.
class ItAdminScreen extends StatefulWidget {
  final AuthSession session;
  final ValueChanged<Locale> onLocaleChanged;

  const ItAdminScreen({
    super.key,
    required this.session,
    required this.onLocaleChanged,
  });

  @override
  State<ItAdminScreen> createState() => _ItAdminScreenState();
}

class _ItAdminScreenState extends State<ItAdminScreen> {
  final _admin = AdminService();
  int _tab = 0;
  String? _exportUrl;

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
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _HistoryTab(admin: _admin),
          _ExportTab(
            admin: _admin,
            exportUrl: _exportUrl,
            onExport: (url) => setState(() => _exportUrl = url),
          ),
          _UsersTab(admin: _admin),
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

class _ExportTab extends StatelessWidget {
  final AdminService admin;
  final String? exportUrl;
  final ValueChanged<String> onExport;

  const _ExportTab({required this.admin, required this.exportUrl, required this.onExport});

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
              onPressed: () async {
                final url = await admin.getExportUrl();
                onExport(url);
              },
              icon: const Icon(Icons.file_download),
              label: Text(l10n.exportDataset),
            ),
            if (exportUrl != null) ...[
              const SizedBox(height: 16),
              SelectableText('${l10n.exportReady}: $exportUrl'),
            ],
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
