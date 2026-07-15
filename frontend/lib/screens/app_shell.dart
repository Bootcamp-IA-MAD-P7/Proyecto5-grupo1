import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/user.dart';
import '../services/auth_session.dart';
import '../services/logout_service.dart';
import '../services/session_manager.dart';
import '../widgets/role_help_dialog.dart';
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

/// Barra de acciones común: ayuda + idioma + logout.
class AppTopActions extends StatelessWidget {
  final AuthSession session;
  final ValueChanged<Locale> onLocaleChanged;
  final UserRole role;

  const AppTopActions({
    super.key,
    required this.session,
    required this.onLocaleChanged,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: l10n.helpButton,
          onPressed: () => showRoleHelpDialog(context, role),
        ),
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
            unawaited(_logout(context));
          },
        ),
      ],
    );
  }

  Future<void> _logout(BuildContext context) async {
    final user = SessionManager().currentUser ?? session.user;
    if (user == null) return;

    await LogoutService().performLogout(
      user: user,
      clearSession: session.clear,
    );
  }
}
