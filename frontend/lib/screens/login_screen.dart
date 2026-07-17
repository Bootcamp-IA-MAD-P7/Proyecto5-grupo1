import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../l10n/l10n.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/exceptions.dart';
import '../services/session_repository.dart';
import '../widgets/sentilife_logo.dart';

/// Login/Register screen — spec §6.1, T2.11 (SL-30).
///
/// Authenticates against the Java backend POST /api/v1/auth/login.
/// On success, stores JWT tokens in [session] (single source of truth).
class LoginScreen extends StatefulWidget {
  final SessionRepository session;
  final VoidCallback onLoginSuccess;
  final AuthService? authService;
  final ValueChanged<Locale>? onLocaleChanged;

  const LoginScreen({
    super.key,
    required this.session,
    required this.onLoginSuccess,
    this.authService,
    this.onLocaleChanged,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  late final AuthService _authService = widget.authService ?? AuthService();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  bool _isRegister = false;
  bool _obscurePassword = true;
  UserRole _selectedRole = UserRole.caregiver;
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
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

      await widget.session.login(tokens);
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
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Language selector top-right
              if (widget.onLocaleChanged != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: PopupMenuButton<Locale>(
                    icon: const Icon(Icons.language, color: Colors.white70),
                    tooltip: 'Language',
                    onSelected: widget.onLocaleChanged,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: const Locale('es'),
                        child: Row(
                          children: [
                            const Text('🇪🇸', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Text(l10n.spanish),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: const Locale('en'),
                        child: Row(
                          children: [
                            const Text('🇬🇧', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Text(l10n.english),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Main content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        const SentiLifeLogo(size: 96, lightMode: true),
                        const SizedBox(height: 32),

                        // Card with form
                        Container(
                          width: size.width > 500 ? 440 : double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Title
                                Text(
                                  _isRegister ? l10n.registerSubtitle : l10n.loginSubtitle,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 28),

                                // Register fields
                                if (_isRegister) ...[
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      labelText: l10n.fullName,
                                      prefixIcon: const Icon(Icons.person_outline),
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
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
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
                                    style: ButtonStyle(
                                      shape: WidgetStateProperty.all(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Email
                                TextFormField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    labelText: l10n.email,
                                    prefixIcon: const Icon(Icons.email_outlined),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  validator: (v) =>
                                      v == null || !v.contains('@') ? l10n.invalidEmail : null,
                                ),
                                const SizedBox(height: 16),

                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: InputDecoration(
                                    labelText: l10n.password,
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: AppTheme.textSecondary,
                                      ),
                                      onPressed: () => setState(
                                          () => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: (v) => v == null || v.length < 8
                                      ? l10n.passwordMinLength
                                      : null,
                                ),
                                const SizedBox(height: 24),

                                // Error message
                                if (_error != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.danger.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTheme.danger.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: AppTheme.danger,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: const TextStyle(
                                              color: AppTheme.danger,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Submit button
                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          AppTheme.primaryColor.withValues(alpha: 0.6),
                                      elevation: 3,
                                      shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            _isRegister ? l10n.register : l10n.signIn,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Toggle login/register
                                TextButton(
                                  onPressed: () => setState(() {
                                    _isRegister = !_isRegister;
                                    _error = null;
                                  }),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.primaryColor,
                                  ),
                                  child: Text(
                                    _isRegister
                                        ? l10n.alreadyHaveAccount
                                        : l10n.noAccountRegister,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
