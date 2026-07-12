import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/exceptions.dart';
import '../services/session_manager.dart';

/// Login/Register screen — spec §6.1, T2.11 (SL-30).
///
/// Authenticates against the Java backend POST /api/v1/auth/login.
/// On success, stores JWT tokens in SessionManager and navigates
/// to the appropriate profile screen by role (RF-20, RF-21, RF-22).
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  bool _isRegister = false;

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
        // Register returns a User (spec §6.1 POST /register → 201)
        await _authService.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          role: UserRole.caregiver,
        );
        // Then login to get tokens
        tokens = await _authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        // Login returns AuthTokens (spec §6.1 POST /login → 200)
        tokens = await _authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      SessionManager().login(tokens);
      if (mounted) widget.onLoginSuccess();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Connection error. Is the backend running?');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  Icon(Icons.health_and_safety,
                      size: 80, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('SentiLife',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      )),
                  const SizedBox(height: 8),
                  Text(
                    _isRegister ? 'Create your account' : 'Sign in to continue',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),

                  // Full name (register only)
                  if (_isRegister) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => _isRegister && (v == null || v.isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        v == null || !v.contains('@') ? 'Invalid email' : null,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) => v == null || v.length < 8
                        ? 'Min 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // Error
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_error!,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),

                  // Submit
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
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isRegister ? 'Register' : 'Login',
                              style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Toggle
                  TextButton(
                    onPressed: () =>
                        setState(() {
                          _isRegister = !_isRegister;
                          _error = null;
                        }),
                    child: Text(_isRegister
                        ? 'Already have an account? Login'
                        : "Don't have an account? Register"),
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
