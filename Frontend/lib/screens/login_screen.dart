import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../services/exceptions.dart';

class LoginScreen extends StatefulWidget {
  final AuthSession session;
  final ValueChanged<Locale> onLocaleChanged;

  const LoginScreen({
    super.key,
    required this.session,
    required this.onLocaleChanged,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _emailCtrl = TextEditingController(text: 'caregiver@test.com');
  final _passwordCtrl = TextEditingController(text: 'Test1234!');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tokens = await _auth.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      widget.session.setSession(tokens);
      if (!mounted) return;
      // AuthSession notifica a main.dart, que reconstruye AppShell.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = context.l10n.unknownError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _quickLogin(String email) {
    _emailCtrl.text = email;
    _passwordCtrl.text = 'Test1234!';
    _login();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
            onSelected: widget.onLocaleChanged,
            itemBuilder: (_) => [
              PopupMenuItem(value: const Locale('es'), child: Text(l10n.spanish)),
              PopupMenuItem(value: const Locale('en'), child: Text(l10n.english)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          Icon(Icons.health_and_safety, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(l10n.loginTitle, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 32),
          TextField(
            controller: _emailCtrl,
            decoration: InputDecoration(labelText: l10n.email, border: const OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            decoration: InputDecoration(labelText: l10n.password, border: const OutlineInputBorder()),
            obscureText: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.login),
            ),
          ),
          const SizedBox(height: 32),
          Text(l10n.demoAccounts, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _DemoChip(label: l10n.roleCaregiver, onTap: () => _quickLogin('caregiver@test.com')),
          _DemoChip(label: l10n.roleMonitored, onTap: () => _quickLogin('monitored@test.com')),
          _DemoChip(label: l10n.roleItAdmin, onTap: () => _quickLogin('admin@test.com')),
        ],
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DemoChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(onPressed: onTap, child: Text(label)),
    );
  }
}
