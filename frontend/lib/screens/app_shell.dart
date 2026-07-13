import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/user.dart';
import '../services/auth_session.dart';
import '../services/monitored_context_store.dart';
import '../services/session_manager.dart';
import 'caregiver_home_screen.dart';
import 'it_admin_screen.dart';
import 'monitored_screen.dart';

/// SL-11 — Navegación por rol tras el login real contra el backend Java.
class AppShell extends StatelessWidget {
  final AuthSession session;
  final ValueChanged<Locale> onLocaleChanged;

  const AppShell({
    super.key,
    required this.session,
    required this.onLocaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final user = session.user!;
    switch (user.role) {
      case UserRole.monitored:
        return MonitoredScreen(session: session, onLocaleChanged: onLocaleChanged);
      case UserRole.caregiver:
        return CaregiverHomeScreen(session: session, onLocaleChanged: onLocaleChanged);
      case UserRole.itAdmin:
        return ItAdminScreen(session: session, onLocaleChanged: onLocaleChanged);
    }
  }
}

/// Barra de acciones común: idioma + logout.
class AppTopActions extends StatelessWidget {
  final AuthSession session;
  final ValueChanged<Locale> onLocaleChanged;

  const AppTopActions({
    super.key,
    required this.session,
    required this.onLocaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<Locale>(
          icon: const Icon(Icons.language),
          onSelected: onLocaleChanged,
          itemBuilder: (_) => [
            PopupMenuItem(value: const Locale('es'), child: Text(l10n.spanish)),
            PopupMenuItem(value: const Locale('en'), child: Text(l10n.english)),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: l10n.logout,
          onPressed: () {
            SessionManager().logout();
            MonitoredContextStore().clear();
            session.clear();
          },
        ),
      ],
    );
  }
}
