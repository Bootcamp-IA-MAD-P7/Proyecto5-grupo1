import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/session_manager.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('es');

  void _changeLocale(Locale locale) {
    if (_locale == locale) return;
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: _AppRoot(onLocaleChanged: _changeLocale),
    );
  }
}

class _AppRoot extends StatefulWidget {
  final ValueChanged<Locale> onLocaleChanged;

  const _AppRoot({required this.onLocaleChanged});

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  final _updateService = UpdateService();
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _loggedIn = SessionManager().isLoggedIn;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
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

  void _onLoginSuccess() {
    setState(() => _loggedIn = true);
  }

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }
    // Route by role (RF-20, RF-21, RF-22)
    // For now all roles go to HomeScreen; dedicated screens per role
    // will be added in SL-11 (navigation 3 profiles) and SL-31 (CAREGIVER).
    return HomeScreen(onLocaleChanged: widget.onLocaleChanged);
  }
}
