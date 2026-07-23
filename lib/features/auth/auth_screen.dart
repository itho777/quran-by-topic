import 'dart:async';
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
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Listen for Google OAuth redirect completing — navigate home on sign-in
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        ref.read(settingsProvider.notifier).loadFromCloud().then((_) {
          if (mounted) context.go('/');
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
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
      if (!mounted) return;
      await ref.read(settingsProvider.notifier).loadFromCloud();
      if (!mounted) return;
      context.go('/');
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
      // Build a clean redirect URL without port number for web
      final redirectUrl = kIsWeb
          ? '${Uri.base.scheme}://${Uri.base.host}/'
          : 'io.supabase.tafseerid://login-callback';
      await svc.signInWithGoogle(
        redirectTo: redirectUrl,
      );
      // OAuth redirect will reload the page — auth listener above handles navigation
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── If already signed in, show signed-in state card ─────────────────────
    final currentUser = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final isAdmin = ref.watch(isAdminProvider);

    if (currentUser != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              children: [
                const SizedBox(height: 24),
                _buildHeader(),
                const SizedBox(height: 40),
                profileAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (err, stack) => const SizedBox.shrink(),
                  data: (profile) => Column(
                    children: [
                      // Signed-in card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                              backgroundImage: (profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(profile.avatarUrl!)
                                  : null,
                              child: (profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty)
                                  ? Text(
                                      (profile?.displayName ?? currentUser.email ?? 'U')[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 28,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              profile?.displayName ?? currentUser.email?.split('@').first ?? 'User',
                              style: TextStyle(
                                color: AppTheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentUser.email ?? '',
                              style: TextStyle(color: AppTheme.outline, fontSize: 13),
                            ),
                            if (isAdmin) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.admin_panel_settings_outlined, size: 14, color: AppTheme.primary),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Admin',
                                      style: TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Go to Home button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.home_outlined, size: 18),
                          label: const Text('Go to Home', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          onPressed: () => context.go('/'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.admin_panel_settings_outlined, size: 18, color: AppTheme.primary),
                            label: Text('Admin Dashboard',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                            onPressed: () => context.go('/admin'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppTheme.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () async {
                          await ref.read(authServiceProvider).signOut();
                          if (context.mounted) context.go('/');
                        },
                        child: Text(
                          'Sign Out',
                          style: TextStyle(color: AppTheme.error, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                builder: (_, child) => Column(
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
                          builder: (_, child) => Text(
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
