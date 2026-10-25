import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegistering = false;
  bool _isSubmitting = false;
  String? _generalErrorMessage;

  // Inline field validation errors
  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _passwordController.clear();
    _confirmPasswordController.clear();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearInlineErrors() {
    setState(() {
      _usernameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _generalErrorMessage = null;
    });
  }

  bool _validateInputs() {
    _clearInlineErrors();
    bool isValid = true;

    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _usernameError = 'Username is required.';
      isValid = false;
    } else if (username.length < 3 || username.length > 20) {
      _usernameError = 'Username must be 3-20 characters long.';
      isValid = false;
    } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      _usernameError = 'Only letters, numbers, and underscores allowed.';
      isValid = false;
    }

    if (_isRegistering) {
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        _emailError = 'Email is required.';
        isValid = false;
      } else if (!RegExp(r'^.+@.+\..+$').hasMatch(email)) {
        _emailError = 'Please enter a valid email address.';
        isValid = false;
      }
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      _passwordError = 'Password is required.';
      isValid = false;
    } else if (password.length < 8) {
      _passwordError = 'Password must be at least 8 characters long.';
      isValid = false;
    }

    if (_isRegistering) {
      final confirmPassword = _confirmPasswordController.text;
      if (confirmPassword.isEmpty) {
        _confirmPasswordError = 'Please confirm your password.';
        isValid = false;
      } else if (password != confirmPassword) {
        _confirmPasswordError = 'Passwords do not match.';
        isValid = false;
      }
    }

    setState(() {});
    return isValid;
  }

  void _submit() {
    if (_isSubmitting) return;

    final isValid = _validateInputs();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Strict ephemeral security: immediately clear password input controllers
    _passwordController.clear();
    _confirmPasswordController.clear();

    if (!isValid) return;

    setState(() => _isSubmitting = true);

    String? error;
    if (_isRegistering) {
      error = widget.controller.register(
        username: username,
        email: email,
        password: password,
      );
    } else {
      error = widget.controller.login(username);
    }

    if (error != null) {
      setState(() {
        _generalErrorMessage = error;
        _isSubmitting = false;
      });
    } else {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Icon(Icons.radar, size: 44, color: AppTheme.radarTeal),
                const SizedBox(height: 8),
                Text(
                  _isRegistering ? 'Create Account' : 'Welcome to Proximity',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Transparent demo notice badge
                Container(
                  key: const Key('demo-auth-notice-badge'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.radarTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.radarTeal.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'Prototype Demonstration Authentication — Accounts stored in local demo state. '
                    'Passwords are ephemeral and never persisted.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                if (_generalErrorMessage != null) ...<Widget>[
                  Container(
                    key: const Key('auth-general-error-box'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: Text(
                      _generalErrorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Mode selector tabs
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextButton(
                        key: const Key('auth-tab-signin'),
                        style: TextButton.styleFrom(
                          foregroundColor: !_isRegistering
                              ? AppTheme.pulseMint
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          textStyle: TextStyle(
                            fontWeight: !_isRegistering
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onPressed: () {
                          if (_isRegistering) {
                            setState(() {
                              _isRegistering = false;
                              _clearInlineErrors();
                              _passwordController.clear();
                              _confirmPasswordController.clear();
                            });
                          }
                        },
                        child: const Text('Sign In'),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        key: const Key('auth-tab-signup'),
                        style: TextButton.styleFrom(
                          foregroundColor: _isRegistering
                              ? AppTheme.pulseMint
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          textStyle: TextStyle(
                            fontWeight: _isRegistering
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onPressed: () {
                          if (!_isRegistering) {
                            setState(() {
                              _isRegistering = true;
                              _clearInlineErrors();
                              _passwordController.clear();
                              _confirmPasswordController.clear();
                            });
                          }
                        },
                        child: const Text('Create Account'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Form Fields
                TextField(
                  key: const Key('auth-username-field'),
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person_outline),
                    isDense: true,
                    errorText: _usernameError,
                  ),
                ),
                if (_isRegistering) ...<Widget>[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('auth-email-field'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      isDense: true,
                      errorText: _emailError,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  key: const Key('auth-password-field'),
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    isDense: true,
                    errorText: _passwordError,
                  ),
                ),
                if (_isRegistering) ...<Widget>[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('auth-confirm-password-field'),
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_reset),
                      isDense: true,
                      errorText: _confirmPasswordError,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  key: const Key('auth-submit-btn'),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isRegistering ? 'Create Account' : 'Sign In'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: Key(
                    _isRegistering
                        ? 'auth-switch-to-login'
                        : 'auth-switch-to-register',
                  ),
                  onPressed: () {
                    setState(() {
                      _isRegistering = !_isRegistering;
                      _clearInlineErrors();
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                    });
                  },
                  child: Text(
                    _isRegistering
                        ? 'Already have an account? Sign In'
                        : "Don't have an account? Sign Up",
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
