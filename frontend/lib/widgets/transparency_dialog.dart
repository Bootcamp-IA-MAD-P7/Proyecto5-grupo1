import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// SL-38 / T2.13 — Modal de transparencia de datos (patrón proyecto 4).
class TransparencyDialog extends StatelessWidget {
  const TransparencyDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const TransparencyDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.dataTransparency),
      content: SingleChildScrollView(child: Text(l10n.transparencyBody)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.understood),
        ),
      ],
    );
  }
}
