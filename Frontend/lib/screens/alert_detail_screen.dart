import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/alert.dart';
import '../services/alerts_service.dart';

/// SL-32 — Detalle de alerta: confirmar / descartar con comentario.
class AlertDetailScreen extends StatefulWidget {
  final Alert alert;
  final VoidCallback onUpdated;

  const AlertDetailScreen({
    super.key,
    required this.alert,
    required this.onUpdated,
  });

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  final _alerts = AlertsService();
  final _comment = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _review(AlertStatus status) async {
    setState(() => _loading = true);
    try {
      await _alerts.review(
        widget.alert.id,
        status: status,
        comment: _comment.text.isEmpty ? null : _comment.text,
      );
      widget.onUpdated();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = widget.alert;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.alertDetail)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(a.monitoredPersonName),
            subtitle: Text(a.detectedAt.toLocal().toString()),
          ),
          Text(l10n.confidence((a.confidence * 100).toStringAsFixed(1))),
          Text('${l10n.modelVersion}: ${a.modelVersion}'),
          const SizedBox(height: 16),
          TextField(
            controller: _comment,
            decoration: InputDecoration(
              labelText: l10n.comment,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          if (a.status == AlertStatus.pending) ...[
            FilledButton(
              onPressed: _loading ? null : () => _review(AlertStatus.confirmed),
              child: Text(l10n.confirmFall),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loading ? null : () => _review(AlertStatus.dismissed),
              child: Text(l10n.dismissAlert),
            ),
          ] else
            Chip(label: Text('${l10n.status}: ${a.status.value}')),
        ],
      ),
    );
  }
}
