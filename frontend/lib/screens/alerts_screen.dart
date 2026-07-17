import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../l10n/l10n.dart';
import '../models/alert.dart';
import '../services/alerts_service.dart';
import 'alert_detail_screen.dart';

/// SL-32 / T2.15 — Lista de alertas del cuidador.
class AlertsScreen extends StatefulWidget {
  final bool embedded;

  const AlertsScreen({super.key, this.embedded = false});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _alerts = AlertsService();
  List<Alert> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final page = await _alerts.list();
    setState(() {
      _items = page.content;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return Center(child: Text(l10n.noAlerts));

    final body = RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final alert = _items[i];
          final isPending = alert.status == AlertStatus.pending;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isPending ? AppTheme.warning : AppTheme.textSecondary)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPending ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  color: isPending ? AppTheme.warning : AppTheme.success,
                  size: 22,
                ),
              ),
              title: Text(
                alert.monitoredPersonName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: l10n.confidence((alert.confidence * 100).toStringAsFixed(1)),
                      style: AppTheme.monoStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    TextSpan(text: ' · ${alert.status.value}'),
                  ],
                ),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AlertDetailScreen(alert: alert, onUpdated: _load),
                  ),
                );
              },
            ),
          );
        },
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: Text(l10n.alerts)), body: body);
  }
}
