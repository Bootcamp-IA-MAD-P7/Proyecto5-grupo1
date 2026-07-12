import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// SL-37 / T2.12 — Modal de consentimiento GDPR.
class ConsentDialog extends StatelessWidget {
  const ConsentDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ConsentDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.consentTitle),
      content: SingleChildScrollView(child: Text(l10n.consentBody)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.decline),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.acceptConsent),
        ),
      ],
    );
  }
}
