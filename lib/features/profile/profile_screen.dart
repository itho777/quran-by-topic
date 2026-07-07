import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/auth_provider.dart';
import '../../core/settings_manager.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final settings = ref.watch(settingsProvider);
    final isAdmin = ref.watch(isAdminProvider);

    // Guest view
    if (user == null) {
      return _buildGuestView(context);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.surfaceContainer,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                icon: Icon(Icons.settings_outlined, color: AppTheme.outline),
                tooltip: 'Settings',
                onPressed: () => context.push('/settings'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D3040), Color(0xFF0A1C28)],
                  ),
                ),
                child: SafeArea(
                  child: profileAsync.when(
                    loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                    error: (_, _) => Center(child: Icon(Icons.person, color: AppTheme.outline, size: 48)),
                    data: (profile) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                          backgroundImage: (profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty)
                              ? NetworkImage(profile.avatarUrl!)
                              : null,
                          child: (profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty)
                              ? Text(
                                  (profile?.displayName ?? user.email ?? 'U')[0].toUpperCase(),
                                  style: TextStyle(fontSize: 32, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          profile?.displayName ?? user.email?.split('@').first ?? 'User',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email ?? '',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, color: AppTheme.secondary, size: 12),
                                SizedBox(width: 4),
                                Text('Admin', style: TextStyle(color: AppTheme.secondary, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Admin Panel Link (admins only) ──────────────────────
                if (isAdmin) ...[
                  _sectionLabel('Administration'),
                  const SizedBox(height: 8),
                  _tile(
                    icon: Icons.admin_panel_settings_outlined,
                    iconColor: AppTheme.secondary,
                    title: 'Admin Panel',
                    subtitle: 'Manage verses, translations, tags & more',
                    trailing: Icon(Icons.chevron_right, color: AppTheme.outline, size: 18),
                    onTap: () => context.go('/admin'),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Settings Sync ────────────────────────────────────────
                _sectionLabel('Settings Sync'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.25)),
                  ),
                  child: Column(children: [
                    ListTile(
                      leading: _iconBox(Icons.cloud_upload_outlined, AppTheme.primary),
                      title: Text('Push to Cloud', style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text('Save current settings to your account', style: TextStyle(color: AppTheme.outline, fontSize: 12)),
                      trailing: Icon(Icons.chevron_right, color: AppTheme.outline, size: 18),
                      onTap: () async {
                        await ref.read(settingsProvider.notifier).syncToCloud();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Settings synced to cloud ✓'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: _iconBox(Icons.cloud_download_outlined, AppTheme.bronzeMute),
                      title: Text('Restore from Cloud', style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text('Load settings saved to your account', style: TextStyle(color: AppTheme.outline, fontSize: 12)),
                      trailing: Icon(Icons.chevron_right, color: AppTheme.outline, size: 18),
                      onTap: () async {
                        await ref.read(settingsProvider.notifier).loadFromCloud();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Settings restored from cloud ✓'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Current Settings Summary ─────────────────────────────
                _sectionLabel('Current Preferences'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.25)),
                  ),
                  child: Column(children: [
                    _prefRow('Language', settings.appLanguage == 'en' ? 'English' : 'Indonesian'),
                    _prefRow('Translation', settings.defaultTranslationSource),
                    _prefRow('Reciter', settings.selectedReciter.replaceAll('_', ' ')),
                    _prefRow('Arabic font', '${settings.arabicFontSize.toInt()} px'),
                    _prefRow('Transliteration', settings.showTransliteration ? 'Shown' : 'Hidden', isLast: true),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Settings Link ────────────────────────────────────────
                _tile(
                  icon: Icons.settings_outlined,
                  iconColor: AppTheme.outline,
                  title: 'App Settings',
                  subtitle: 'Theme, font size, display options',
                  trailing: Icon(Icons.chevron_right, color: AppTheme.outline, size: 18),
                  onTap: () => context.go('/settings'),
                ),
                const SizedBox(height: 20),

                // ── Sign Out ─────────────────────────────────────────────
                _sectionLabel('Account'),
                const SizedBox(height: 8),
                _tile(
                  icon: Icons.logout,
                  iconColor: AppTheme.error,
                  title: 'Sign Out',
                  subtitle: 'You will continue to have read access as a guest',
                  onTap: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go('/');
                  },
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppTheme.outline),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.person_outline, color: AppTheme.primary, size: 40),
              ),
              const SizedBox(height: 24),
              Text('You\'re browsing as a guest',
                  style: TextStyle(color: AppTheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Sign in to sync your settings and bookmarks across devices',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.outline.withValues(alpha: 0.8), fontSize: 13, height: 1.5)),
              const SizedBox(height: 32),
              SizedBox(
                width: 220,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: Icon(Icons.login),
                  label: const Text('Sign In / Register', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/settings'),
                child: Text('App Settings →', style: TextStyle(color: AppTheme.outline)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(text.toUpperCase(),
        style: TextStyle(color: AppTheme.outline, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
  );

  Widget _iconBox(IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
    child: Icon(icon, color: color, size: 18),
  );

  Widget _tile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              _iconBox(icon, iconColor),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: AppTheme.outline, fontSize: 12)),
              ])),
              ?trailing,
            ]),
          ),
        ),
      ),
    );
  }

  Widget _prefRow(String label, String value, {bool isLast = false}) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: AppTheme.outline, fontSize: 13)),
            Text(value, style: TextStyle(color: AppTheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      if (!isLast) Divider(height: 1, color: AppTheme.outlineVariant),
    ]);
  }
}
