import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/alerts_service.dart';
import 'alert_detail_screen.dart';

/// Carga una alerta por ID (p. ej. desde tap en push FCM) y abre el detalle.
class AlertDetailLoaderScreen extends StatefulWidget {
  final String alertId;
  final VoidCallback? onUpdated;

  const AlertDetailLoaderScreen({
    super.key,
    required this.alertId,
    this.onUpdated,
  });

  @override
  State<AlertDetailLoaderScreen> createState() =>
      _AlertDetailLoaderScreenState();
}

class _AlertDetailLoaderScreenState extends State<AlertDetailLoaderScreen> {
  final _alerts = AlertsService();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final alert = await _alerts.getById(widget.alertId);
      if (!mounted) return;
      if (alert == null) {
        setState(() {
          _loading = false;
          _error = 'Alerta no encontrada';
        });
        return;
      }

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AlertDetailScreen(
            alert: alert,
            onUpdated: widget.onUpdated ?? () {},
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar la alerta';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.alertDetail)),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? l10n.noAlerts),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.back),
                  ),
                ],
              ),
      ),
    );
  }
}
