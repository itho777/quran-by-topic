import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Admin Login Screen — /admin-login
// ─────────────────────────────────────────────────────────────────────────────
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).signInWithEmail(email, password);
      await ref.read(userProfileProvider.future);
      final isAdmin = ref.read(isAdminProvider);
      if (!mounted) return;
      if (isAdmin) {
        context.go('/admin');
      } else {
        await ref.read(authServiceProvider).signOut();
        setState(() => _error = 'Access denied — this account does not have admin privileges.');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final profileAsync = ref.watch(userProfileProvider);

    if (currentUser != null && isAdmin) {
      return _buildAlreadyAdminView(profileAsync, currentUser);
    }
    if (currentUser != null && !isAdmin && !profileAsync.isLoading) {
      return _buildAccessDeniedView(currentUser);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF060D0D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primary, size: 36),
                    ),
                    const SizedBox(height: 20),
                    Text('Admin Portal',
                      style: TextStyle(color: AppTheme.onSurface, fontSize: 26,
                          fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                    const SizedBox(height: 6),
                    Text('Sign in with your administrator credentials',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.outline, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Icon(Icons.shield_outlined, color: const Color(0xFFFFB300), size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'This portal is restricted to authorized administrators only.',
                    style: TextStyle(color: const Color(0xFFFFB300).withValues(alpha: 0.9), fontSize: 12),
                  )),
                ]),
              ),
              const SizedBox(height: 28),
              _buildField(controller: _emailCtrl, label: 'Admin Email',
                  icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
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
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: AppTheme.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: AppTheme.error, fontSize: 13))),
                  ]),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 54,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In to Admin',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: () => context.go('/'),
                  icon: Icon(Icons.arrow_back, size: 14, color: AppTheme.outline),
                  label: Text('Back to App', style: TextStyle(color: AppTheme.outline, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlreadyAdminView(AsyncValue<UserProfile?> profileAsync, user) {
    return Scaffold(
      backgroundColor: const Color(0xFF060D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Column(children: [
                  Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primary, size: 48),
                  const SizedBox(height: 16),
                  Text("You're signed in as Admin",
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  profileAsync.maybeWhen(
                    data: (p) => Text(p?.displayName ?? user.email ?? '',
                        style: TextStyle(color: AppTheme.outline, fontSize: 13)),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.dashboard_outlined, size: 18),
                      label: const Text('Go to Admin Dashboard',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      onPressed: () => context.go('/admin'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: Text('Back to App', style: TextStyle(color: AppTheme.outline, fontSize: 13)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessDeniedView(User user) {
    return Scaffold(
      backgroundColor: const Color(0xFF060D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                ),
                child: Column(children: [
                  Icon(Icons.block_outlined, color: AppTheme.error, size: 48),
                  const SizedBox(height: 16),
                  Text('Access Denied',
                    style: TextStyle(color: AppTheme.error, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Your account (${user.email}) does not have admin privileges.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.outline, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Sign Out',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        await ref.read(authServiceProvider).signOut();
                        if (mounted) context.go('/');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: Text('Back to App', style: TextStyle(color: AppTheme.outline, fontSize: 13)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
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
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.outline, fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.outline, size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF0F1A1A),
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
    );
  }
}
