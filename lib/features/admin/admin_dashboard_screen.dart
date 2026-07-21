import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Admin Dashboard — 3-tab layout: Mobile App / Web CMS / Admin Settings
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Mobile App stats
  bool _loadingStats = true;
  Map<String, int> _counts = {};

  // Web CMS config
  bool _loadingCms = true;
  Map<String, String> _cmsConfig = {};

  // Admin Settings
  bool _adminLoginVisible = false;
  bool _savingSettings = false;

  static const _tables = [
    ('verses', Icons.auto_stories_outlined, 'Verses'),
    ('translations', Icons.translate, 'Translations'),
    ('tafsirs', Icons.menu_book_outlined, 'Tafsirs'),
    ('asbabun_nuzul', Icons.history_edu_outlined, 'Asbabun Nuzul'),
    ('tags', Icons.label_outline, 'Tags'),
    ('verse_tags', Icons.sell_outlined, 'Verse Tags'),
  ];

  static const _tableRoutes = {
    'verses': '/admin/verses',
    'translations': '/admin/translations',
    'tafsirs': '/admin/tafsirs',
    'asbabun_nuzul': '/admin/nuzul',
    'tags': '/admin/tags',
    'verse_tags': '/admin/verse-tags',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
    _loadCms();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data loaders ────────────────────────────────────────────────────────────

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    final db = Supabase.instance.client;
    final Map<String, int> counts = {};
    for (final (table, _, _) in _tables) {
      try {
        final res = await db.from(table).select('id').count(CountOption.exact);
        counts[table] = res.count;
      } catch (_) {
        counts[table] = 0;
      }
    }
    setState(() { _counts = counts; _loadingStats = false; });
  }

  Future<void> _loadCms() async {
    setState(() => _loadingCms = true);
    try {
      final res = await Supabase.instance.client.from('site_config').select('key, value');
      final map = <String, String>{};
      for (final row in List<Map<String, dynamic>>.from(res)) {
        map[row['key'] as String] = row['value'] as String;
      }
      setState(() {
        _cmsConfig = map;
        _adminLoginVisible = (map['admin_login_visible'] ?? 'false') == 'true';
        _loadingCms = false;
      });
    } catch (_) {
      setState(() { _loadingCms = false; });
    }
  }

  Future<void> _saveAdminLoginVisible(bool value) async {
    setState(() => _savingSettings = true);
    try {
      await Supabase.instance.client.from('site_config').upsert({
        'key': 'admin_login_visible',
        'value': value.toString(),
      }, onConflict: 'key');
      setState(() { _adminLoginVisible = value; _savingSettings = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value
              ? 'Admin login page is now publicly visible'
              : 'Admin login page is now hidden'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      setState(() => _savingSettings = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        title: Row(children: [
          Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.outline),
            onPressed: () { _loadStats(); _loadCms(); },
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppTheme.outline),
            color: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) async {
              if (v == 'signout') {
                final router = GoRouter.of(context);
                await ref.read(authServiceProvider).signOut();
                if (!mounted) return;
                router.go('/');
              } else if (v == 'app') {
                context.go('/');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'app', child: Row(children: [
                Icon(Icons.home_outlined, size: 16, color: AppTheme.outline),
                const SizedBox(width: 10),
                const Text('Back to App', style: TextStyle(fontSize: 13)),
              ])),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'signout', child: Row(children: [
                Icon(Icons.logout, size: 16, color: AppTheme.error),
                const SizedBox(width: 10),
                Text('Sign Out', style: TextStyle(fontSize: 13, color: AppTheme.error)),
              ])),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.outline,
          indicatorColor: AppTheme.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.phone_android, size: 18), text: 'Mobile App'),
            Tab(icon: Icon(Icons.language, size: 18), text: 'Web / CMS'),
            Tab(icon: Icon(Icons.settings_outlined, size: 18), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMobileTab(),
          _buildWebCmsTab(),
          _buildSettingsTab(profileAsync, user),
        ],
      ),
    );
  }

  // ── Tab 1: Mobile App ───────────────────────────────────────────────────────

  Widget _buildMobileTab() {
    if (_loadingStats) return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerCard(
            icon: Icons.dataset_outlined,
            title: 'Database Overview',
            subtitle: 'Manage Quran content, translations, tafsirs, and tags',
          ),
          const SizedBox(height: 24),
          _sectionLabel('Content Tables'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemCount: _tables.length,
            itemBuilder: (context, i) {
              final (table, icon, label) = _tables[i];
              final count = _counts[table] ?? 0;
              final route = _tableRoutes[table] ?? '/admin';
              return _StatCard(icon: icon, label: label, count: count,
                  onTap: () => context.go(route));
            },
          ),
          const SizedBox(height: 28),
          _sectionLabel('Quick Actions'),
          const SizedBox(height: 12),
          _QuickAction(
            icon: Icons.add_circle_outline, color: AppTheme.primary,
            title: 'Add New Tag', subtitle: 'Create a new topic tag in EN or ID',
            onTap: () => context.go('/admin/tags'),
          ),
          const SizedBox(height: 10),
          _QuickAction(
            icon: Icons.translate, color: AppTheme.secondary,
            title: 'Manage Translations', subtitle: 'View and edit translation entries',
            onTap: () => context.go('/admin/translations'),
          ),
          const SizedBox(height: 10),
          _QuickAction(
            icon: Icons.menu_book_outlined, color: AppTheme.primaryContainer,
            title: 'Manage Tafsirs', subtitle: 'View and edit tafsir entries',
            onTap: () => context.go('/admin/tafsirs'),
          ),
          const SizedBox(height: 10),
          _QuickAction(
            icon: Icons.history_edu_outlined, color: const Color(0xFF6C63FF),
            title: 'Asbabun Nuzul', subtitle: 'View and edit revelation context',
            onTap: () => context.go('/admin/nuzul'),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Tab 2: Web / CMS ────────────────────────────────────────────────────────

  Widget _buildWebCmsTab() {
    if (_loadingCms) return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerCard(
            icon: Icons.web_outlined,
            title: 'Web & CMS Management',
            subtitle: 'Edit home content, featured ayah, announcements, and site configuration',
            color: const Color(0xFF6C63FF),
          ),
          const SizedBox(height: 24),
          _sectionLabel('Site Configuration'),
          const SizedBox(height: 12),
          _CmsKeyCard(
            label: 'Featured Ayah',
            icon: Icons.auto_awesome_outlined,
            value: _cmsConfig['featured_verse_key'] ?? '—',
            color: AppTheme.primary,
          ),
          const SizedBox(height: 10),
          _CmsKeyCard(
            label: 'Home Banner Text',
            icon: Icons.campaign_outlined,
            value: _cmsConfig['home_banner_text'] ?? '—',
            color: AppTheme.secondary,
            truncate: true,
          ),
          const SizedBox(height: 10),
          _CmsKeyCard(
            label: 'Announcement',
            icon: Icons.notifications_outlined,
            value: _cmsConfig['announcement'] ?? '—',
            color: const Color(0xFFFFB300),
            truncate: true,
          ),
          const SizedBox(height: 24),
          _sectionLabel('Quick Actions'),
          const SizedBox(height: 12),
          _QuickAction(
            icon: Icons.edit_outlined, color: const Color(0xFF6C63FF),
            title: 'Site CMS Editor',
            subtitle: 'Edit home content, featured ayah & announcements',
            onTap: () => context.go('/admin/cms'),
          ),
          const SizedBox(height: 10),
          _QuickAction(
            icon: Icons.open_in_browser_outlined, color: AppTheme.primary,
            title: 'View Live Site',
            subtitle: 'Open tafseer.id in browser',
            onTap: () async {
              await Clipboard.setData(const ClipboardData(text: 'https://tafseer.id'));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('URL copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ));
              }
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Tab 3: Admin Settings ───────────────────────────────────────────────────

  Widget _buildSettingsTab(AsyncValue<UserProfile?> profileAsync, user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current session card
          _headerCard(
            icon: Icons.manage_accounts_outlined,
            title: 'Admin Settings',
            subtitle: 'Security controls and session management',
            color: AppTheme.secondary,
          ),
          const SizedBox(height: 24),
          _sectionLabel('Current Session'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                child: profileAsync.maybeWhen(
                  data: (p) => Text(
                    (p?.displayName ?? user?.email ?? 'A')[0].toUpperCase(),
                    style: TextStyle(fontSize: 18, color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
                  orElse: () => Icon(Icons.person, color: AppTheme.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  profileAsync.maybeWhen(
                    data: (p) => Text(p?.displayName ?? 'Admin',
                        style: TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  Text(user?.email ?? '', style: TextStyle(color: AppTheme.outline, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Administrator',
                        style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 10),
          _QuickAction(
            icon: Icons.logout, color: AppTheme.error,
            title: 'Sign Out',
            subtitle: 'End current admin session',
            onTap: () async {
              await ref.read(authServiceProvider).signOut();
              if (mounted) context.go('/');
            },
          ),

          const SizedBox(height: 28),
          _sectionLabel('Security'),
          const SizedBox(height: 12),

          // Admin Login Visibility Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _adminLoginVisible
                    ? const Color(0xFFFFB300).withValues(alpha: 0.4)
                    : AppTheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_adminLoginVisible ? const Color(0xFFFFB300) : AppTheme.outline)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _adminLoginVisible ? Icons.lock_open_outlined : Icons.lock_outlined,
                  color: _adminLoginVisible ? const Color(0xFFFFB300) : AppTheme.outline,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin Login Page Visible',
                      style: TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    _adminLoginVisible
                        ? '/#/admin-login shows a login form to anyone'
                        : '/#/admin-login redirects non-admins to home (hidden)',
                    style: TextStyle(color: AppTheme.outline, fontSize: 11),
                  ),
                ],
              )),
              const SizedBox(width: 8),
              _savingSettings
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Switch(
                      value: _adminLoginVisible,
                      activeThumbColor: const Color(0xFFFFB300),
                      activeTrackColor: const Color(0xFFFFB300).withValues(alpha: 0.4),
                      onChanged: _saveAdminLoginVisible,
                    ),
            ]),
          ),

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.outline.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 14, color: AppTheme.outline),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'When hidden, only users who are already signed in as admin can access /#/admin-login. '
                'This prevents discovery of the admin portal URL.',
                style: TextStyle(color: AppTheme.outline, fontSize: 11),
              )),
            ]),
          ),

          const SizedBox(height: 28),
          _sectionLabel('Admin Portal URLs'),
          const SizedBox(height: 12),
          _UrlCard(label: 'Admin Dashboard', url: '/#/admin', onCopy: _copyUrl),
          const SizedBox(height: 8),
          _UrlCard(label: 'Admin Login', url: '/#/admin-login', onCopy: _copyUrl),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: 'https://tafseer.id$url'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$url copied to clipboard'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────

  Widget _headerCard({required IconData icon, required String title, required String subtitle, Color? color}) {
    final c = color ?? AppTheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1400), const Color(0xFF0D1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: c, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: AppTheme.onSurface, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: AppTheme.outline, fontSize: 12)),
          ],
        )),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text.toUpperCase(),
    style: TextStyle(color: AppTheme.outline, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatCard
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  const _StatCard({required this.icon, required this.label, required this.count, required this.onTap});

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 18),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(count == 0 ? '—' : _fmt(count),
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 22)),
              Text(label, style: TextStyle(color: AppTheme.outline, fontSize: 11)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuickAction
// ─────────────────────────────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.color, required this.title,
      required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: AppTheme.outline, fontSize: 12)),
              ],
            )),
            Icon(Icons.chevron_right, color: AppTheme.outline, size: 18),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CmsKeyCard — shows a CMS config value
// ─────────────────────────────────────────────────────────────────────────────
class _CmsKeyCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final Color color;
  final bool truncate;
  const _CmsKeyCard({required this.label, required this.icon, required this.value,
      required this.color, this.truncate = false});

  @override
  Widget build(BuildContext context) {
    final display = truncate && value.length > 60 ? '${value.substring(0, 60)}…' : value;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppTheme.outline, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(display, style: TextStyle(color: AppTheme.onSurface, fontSize: 13)),
          ],
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UrlCard — shows an admin URL with copy button
// ─────────────────────────────────────────────────────────────────────────────
class _UrlCard extends StatelessWidget {
  final String label;
  final String url;
  final void Function(String) onCopy;
  const _UrlCard({required this.label, required this.url, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.link, color: AppTheme.outline, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppTheme.outline, fontSize: 10, fontWeight: FontWeight.bold)),
            Text('tafseer.id$url',
                style: TextStyle(color: AppTheme.primary, fontSize: 12, fontFamily: 'monospace')),
          ],
        )),
        IconButton(
          icon: Icon(Icons.copy_outlined, size: 16, color: AppTheme.outline),
          onPressed: () => onCopy(url),
          tooltip: 'Copy URL',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }
}
