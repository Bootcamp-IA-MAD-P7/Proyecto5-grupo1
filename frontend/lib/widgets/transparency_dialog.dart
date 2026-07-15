import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// SL-38 / T2.13 — Modal de transparencia de datos (patrón proyecto 4).
class TransparencyDialog extends StatelessWidget {
  const TransparencyDialog({
    super.key,
    this.onViewLiveSensors,
  });

  final VoidCallback? onViewLiveSensors;

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onViewLiveSensors,
  }) {
    return showDialog(
      context: context,
      builder: (_) => TransparencyDialog(onViewLiveSensors: onViewLiveSensors),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.dataTransparency),
      content: SingleChildScrollView(child: Text(l10n.transparencyBody)),
      actions: [
        if (onViewLiveSensors != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onViewLiveSensors!();
            },
            child: Text(l10n.viewLiveSensorsLink),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.understood),
        ),
      ],
    );
  }
}
