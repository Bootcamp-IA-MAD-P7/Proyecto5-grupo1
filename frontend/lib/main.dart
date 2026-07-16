import 'dart:async';

import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';
import 'models/user.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_session.dart';
import 'services/firebase_bootstrap.dart';
import 'services/push_notification_service.dart';
import 'services/push_registration_service.dart';
import 'services/session_repository.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('es');
  final _session = SessionRepository.instance;

  void _changeLocale(Locale locale) {
    if (_locale == locale) return;
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: PushNotificationService.navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: _AppRoot(
        session: _session,
        onLocaleChanged: _changeLocale,
        locale: _locale,
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  final SessionRepository session;
  final ValueChanged<Locale> onLocaleChanged;
  final Locale locale;

  const _AppRoot({
    required this.session,
    required this.onLocaleChanged,
    required this.locale,
  });

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  final _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    _updateService.setLocale(widget.locale);
    widget.session.addListener(_onAuthChanged);
    unawaited(_bootstrapSession());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdate();
      unawaited(PushNotificationService.tryNavigateToPendingAlert());
    });
  }

  @override
  void didUpdateWidget(covariant _AppRoot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locale != widget.locale) {
      _updateService.setLocale(widget.locale);
    }
  }

  Future<void> _bootstrapSession() async {
    await widget.session.restoreSession();
    if (!mounted) return;
    _onSessionReady(widget.session.user);
  }

  void _onSessionReady(User? user) {
    if (user == null) return;
    widget.onLocaleChanged(Locale(user.locale));
    if (user.role == UserRole.caregiver) {
      unawaited(
        PushRegistrationService().registerForCaregiver(locale: user.locale),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(PushNotificationService.tryNavigateToPendingAlert());
      });
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onAuthChanged);
    _updateService.dispose();
    super.dispose();
  }

  void _onAuthChanged() => setState(() {});

  void _onLoginSuccess() {
    _onSessionReady(widget.session.user);
  }

  Future<void> _checkUpdate() async {
    await _updateService.checkForUpdate();
    if (!mounted) return;
    if (_updateService.status == UpdateStatus.updateAvailable) {
      final remote = _updateService.remoteVersion!;
      final isMandatory = remote.isMandatoryUpdate(
        _updateService.installedVersionCode ?? 0,
      );
      await UpdateDialog.show(context, _updateService, mandatory: isMandatory);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.isRestoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.session.isLoggedIn) {
      return AppShell(
        session: widget.session,
        onLocaleChanged: widget.onLocaleChanged,
      );
    }
    return LoginScreen(
      session: widget.session,
      onLoginSuccess: _onLoginSuccess,
    );
  }
}
