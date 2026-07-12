import 'package:flutter/material.dart';

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
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final alert = _items[i];
          return ListTile(
            leading: Icon(
              alert.status == AlertStatus.pending ? Icons.warning_amber : Icons.check,
              color: alert.status == AlertStatus.pending ? Colors.orange : Colors.grey,
            ),
            title: Text(alert.monitoredPersonName),
            subtitle: Text(
              '${l10n.confidence((alert.confidence * 100).toStringAsFixed(1))} · ${alert.status.value}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlertDetailScreen(alert: alert, onUpdated: _load),
                ),
              );
            },
          );
        },
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: Text(l10n.alerts)), body: body);
  }
}
