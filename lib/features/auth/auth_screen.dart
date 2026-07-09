import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/auth_provider.dart';
import '../../core/settings_manager.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = ref.read(authServiceProvider);
      if (_tabController.index == 0) {
        // Login
        await svc.signInWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        // Register
        await svc.signUpWithEmail(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          displayName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        );
      }
      // After login: pull cloud settings then go home
      if (mounted) {
        await ref.read(settingsProvider.notifier).loadFromCloud();
        context.go('/');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = ref.read(authServiceProvider);
      final redirectUrl = kIsWeb
          ? '${Uri.base.scheme}://${Uri.base.host}:${Uri.base.port}/'
          : 'io.supabase.tafseerid://login-callback';
      await svc.signInWithGoogle(
        redirectTo: redirectUrl,
      );
      // OAuth redirect will reload the page — no further action needed here
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // ── Header ──────────────────────────────────────────────────
              _buildHeader(),
              const SizedBox(height: 32),

              // ── Tab bar ─────────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.outline,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Sign In'),
                    Tab(text: 'Register'),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Form fields ─────────────────────────────────────────────
              AnimatedBuilder(
                animation: _tabController,
                builder: (_, _) => Column(
                  children: [
                    if (_tabController.index == 1) ...[
                      _buildField(
                        controller: _nameCtrl,
                        label: 'Display Name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildField(
                      controller: _emailCtrl,
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _passwordCtrl,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppTheme.outline, size: 18),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppTheme.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: TextStyle(color: AppTheme.error, fontSize: 13))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // ── Submit button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : AnimatedBuilder(
                          animation: _tabController,
                          builder: (_, _) => Text(
                            _tabController.index == 0 ? 'Sign In' : 'Create Account',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Divider ──────────────────────────────────────────────────
              Row(children: [
                Expanded(child: Divider(color: AppTheme.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: TextStyle(color: AppTheme.outline.withValues(alpha: 0.7), fontSize: 12)),
                ),
                Expanded(child: Divider(color: AppTheme.outlineVariant)),
              ]),
              const SizedBox(height: 20),

              // ── Google Sign-In ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _googleSignIn,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.outlineVariant),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    foregroundColor: AppTheme.onSurface,
                  ),
                  icon: _GoogleIcon(),
                  label: const Text('Continue with Google',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),

              // ── Skip / Continue as Guest ─────────────────────────────────
              TextButton(
                onPressed: () => context.go('/'),
                child: Text('Continue as Guest →',
                    style: TextStyle(color: AppTheme.outline, fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Image.asset(
          AppTheme.isDark
              ? 'assets/images/logo_dark.png'
              : 'assets/images/logo_light.png',
          height: 120,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 16),
        Text('Sign in to sync your settings & bookmarks across devices',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.outline.withValues(alpha: 0.8), fontSize: 13)),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: TextStyle(color: AppTheme.onSurface, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.outline, fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.outline, size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppTheme.surfaceContainer,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onSubmitted: (_) => _submit(),
    );
  }
}

// Simple Google "G" icon
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: const Center(
        child: Text('G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Arial',
            )),
      ),
    );
  }
}
