import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/airbnb_theme.dart';
import '../domain/auth/auth_models.dart';

class LoginView extends StatefulWidget {
  final AuthService authService;
  final VoidCallback? onLoginSuccess;

  const LoginView({
    super.key,
    required this.authService,
    this.onLoginSuccess,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (widget.authService.isTenantBoundaryBlocked) {
        widget.authService.dismissTenantBoundaryBlock();
      }
      if (mounted) {
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo & Heading
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AirbnbTheme.coral.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          size: 32,
                          color: AirbnbTheme.coral,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ROUTIDROW',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AirbnbTheme.dark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'FMCG Distribution & Logistics Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AirbnbTheme.grey,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Error Notification Banner
                    if (_errorMessage != null || widget.authService.state.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFD2D2), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AirbnbTheme.coral, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage ?? widget.authService.state.errorMessage ?? '',
                                style: const TextStyle(
                                  color: Color(0xFFC01E2E),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Username Input
                    const Text(
                      'Username',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AirbnbTheme.dark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        hintText: 'Enter your username',
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                        filled: true,
                        fillColor: AirbnbTheme.lightGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AirbnbTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AirbnbTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AirbnbTheme.coral, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Username is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Password Input
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AirbnbTheme.dark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                            color: AirbnbTheme.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: AirbnbTheme.lightGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AirbnbTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AirbnbTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AirbnbTheme.coral, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    ElevatedButton(
                      onPressed: (_isLoading || widget.authService.state.status == AuthStatus.authenticating)
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbTheme.coral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: (_isLoading || widget.authService.state.status == AuthStatus.authenticating)
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),

                    // Debug-only Presets (Excluded in Release builds; zero hardcoded passwords in release)
                    if (kDebugMode) ...[
                      const Divider(color: AirbnbTheme.border),
                      const SizedBox(height: 12),
                      const Text(
                        'Debug Quick-Fill',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AirbnbTheme.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.navigation_outlined, size: 14, color: AirbnbTheme.coral),
                            label: const Text('Sales Rep', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            onPressed: () {
                              setState(() {
                                _usernameController.text = 'sales_rep';
                                _passwordController.text = 'RouteFlow@2026!';
                                _errorMessage = null;
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.warehouse_outlined, size: 14, color: AirbnbTheme.jodhpurBlue),
                            label: const Text('Inventory', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            onPressed: () {
                              setState(() {
                                _usernameController.text = 'inventory_mgr';
                                _passwordController.text = 'RouteFlow@2026!';
                                _errorMessage = null;
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.local_shipping_outlined, size: 14, color: AirbnbTheme.success),
                            label: const Text('Delivery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            onPressed: () {
                              setState(() {
                                _usernameController.text = 'delivery_driver';
                                _passwordController.text = 'RouteFlow@2026!';
                                _errorMessage = null;
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.admin_panel_settings_outlined, size: 14, color: Color(0xFF6C5CE7)),
                            label: const Text('Distributor Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            onPressed: () {
                              setState(() {
                                _usernameController.text = 'dist_admin';
                                _passwordController.text = 'RouteFlow@2026!';
                                _errorMessage = null;
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.shield_outlined, size: 14, color: Color(0xFFD97706)),
                            label: const Text('Distributor Owner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            onPressed: () {
                              setState(() {
                                _usernameController.text = 'dist_owner';
                                _passwordController.text = 'RouteFlow@2026!';
                                _errorMessage = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
