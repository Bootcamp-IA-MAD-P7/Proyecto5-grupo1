import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/user.dart';

/// RF-44 — Guía contextual por perfil (MONITORED / CAREGIVER / IT_ADMIN).
Future<void> showRoleHelpDialog(BuildContext context, UserRole role) {
  final l10n = context.l10n;
  final title = switch (role) {
    UserRole.monitored => l10n.helpMonitoredTitle,
    UserRole.caregiver => l10n.helpCaregiverTitle,
    UserRole.itAdmin => l10n.helpItAdminTitle,
  };
  final body = switch (role) {
    UserRole.monitored => l10n.helpMonitoredBody,
    UserRole.caregiver => l10n.helpCaregiverBody,
    UserRole.itAdmin => l10n.helpItAdminBody,
  };

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.help_outline),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Text(body, style: Theme.of(ctx).textTheme.bodyMedium),
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
