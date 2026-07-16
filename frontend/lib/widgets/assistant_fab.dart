import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../screens/assistant_chat_screen.dart';

/// FAB global del asistente IA (RF-46).
class AssistantFab extends StatelessWidget {
  final String locale;
  final Object? heroTag;

  const AssistantFab({
    super.key,
    this.locale = 'es',
    this.heroTag = 'assistant-fab',
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FloatingActionButton(
      heroTag: heroTag,
      tooltip: l10n.assistantTitle,
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AssistantChatScreen(locale: locale),
          ),
        );
      },
      child: const Icon(Icons.smart_toy_outlined),
    );
  }
}

/// Column helper when another FAB already exists on the screen.
class AssistantFabColumn extends StatelessWidget {
  final String locale;
  final Widget? primaryFab;

  const AssistantFabColumn({
    super.key,
    this.locale = 'es',
    this.primaryFab,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AssistantFab(locale: locale, heroTag: 'assistant-fab'),
        if (primaryFab != null) ...[
          const SizedBox(height: 12),
          primaryFab!,
        ],
      ],
    );
  }
}
