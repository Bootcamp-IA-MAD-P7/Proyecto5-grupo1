import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/exceptions.dart';
import '../services/session_manager.dart';

/// Login/Register screen — spec §6.1, T2.11 (SL-30).
///
/// Authenticates against the Java backend POST /api/v1/auth/login.
/// On success, stores JWT tokens in SessionManager and calls [onLoginSuccess].
/// main.dart bridges SessionManager → AuthSession for role-based navigation.
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final AuthService? authService;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    this.authService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  late final AuthService _authService = widget.authService ?? AuthService();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  bool _isRegister = false;
  UserRole _selectedRole = UserRole.caregiver;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      AuthTokens tokens;

      if (_isRegister) {
        await _authService.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          role: _selectedRole,
        );
        tokens = await _authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        tokens = await _authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      await SessionManager().login(tokens);
      if (mounted) widget.onLoginSuccess();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = context.l10n.connectionError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.health_and_safety,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.appTitle,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegister ? l10n.registerSubtitle : l10n.loginSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 40),

                  if (_isRegister) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.fullName,
                        prefixIcon: const Icon(Icons.person),
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => _isRegister && (v == null || v.isEmpty)
                          ? l10n.requiredField
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.registrationRolePrompt,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<UserRole>(
                      segments: [
                        ButtonSegment(
                          value: UserRole.caregiver,
                          icon: const Icon(Icons.volunteer_activism),
                          label: Text(l10n.roleCaregiver),
                        ),
                        ButtonSegment(
                          value: UserRole.monitored,
                          icon: const Icon(Icons.health_and_safety_outlined),
                          label: Text(l10n.roleMonitored),
                        ),
                      ],
                      selected: {_selectedRole},
                      showSelectedIcon: false,
                      onSelectionChanged: (roles) =>
                          setState(() => _selectedRole = roles.single),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: l10n.email,
                      prefixIcon: const Icon(Icons.email),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        v == null || !v.contains('@') ? l10n.invalidEmail : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) =>
                        v == null || v.length < 8 ? l10n.passwordMinLength : null,
                  ),
                  const SizedBox(height: 24),

                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isRegister ? l10n.register : l10n.signIn,
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () => setState(() {
                      _isRegister = !_isRegister;
                      _error = null;
                    }),
                    child: Text(
                      _isRegister
                          ? l10n.alreadyHaveAccount
                          : l10n.noAccountRegister,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
