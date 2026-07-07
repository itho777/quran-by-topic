import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Admin Dashboard — entry point for the admin section
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  Map<String, int> _counts = {};

  static const _tables = [
    ('verses', Icons.auto_stories_outlined, 'Verses'),
    ('translations', Icons.translate, 'Translations'),
    ('tafsirs', Icons.menu_book_outlined, 'Tafsirs'),
    ('asbabun_nuzul', Icons.history_edu_outlined, 'Asbabun Nuzul'),
    ('tags', Icons.label_outline, 'Tags'),
    ('verse_tags', Icons.sell_outlined, 'Verse Tags'),
  ];

  static const _routes = {
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
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _loading = true);
    final db = Supabase.instance.client;
    final Map<String, int> counts = {};
    for (final (table, _, __) in _tables) {
      try {
        final res = await db
            .from(table)
            .select('id')
            .count(CountOption.exact);
        counts[table] = res.count;
      } catch (_) {
        counts[table] = 0;
      }
    }
    setState(() {
      _counts = counts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primary, size: 20),
            SizedBox(width: 10),
            Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.outline),
            onPressed: _loadCounts,
            tooltip: 'Refresh counts',
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header strip
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A1400), Color(0xFF0D1A1A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.dataset_outlined, color: AppTheme.primary, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Database Overview',
                                  style: TextStyle(color: AppTheme.onSurface, fontSize: 17, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                'Manage Quran content, translations, tafsirs, and tags',
                                style: TextStyle(color: AppTheme.outline, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const _SectionLabel('Content Tables'),
                  const SizedBox(height: 12),

                  // Stats grid
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
                      final route = _routes[table] ?? '/admin';
                      return _StatCard(
                        icon: icon,
                        label: label,
                        count: count,
                        onTap: () => context.go(route),
                      );
                    },
                  ),

                  const SizedBox(height: 28),
                  const _SectionLabel('Quick Actions'),
                  const SizedBox(height: 12),

                  _QuickAction(
                    icon: Icons.add_circle_outline,
                    color: AppTheme.primary,
                    title: 'Add New Tag',
                    subtitle: 'Create a new topic tag in EN or ID',
                    onTap: () => context.go('/admin/tags/new'),
                  ),
                  const SizedBox(height: 10),
                  _QuickAction(
                    icon: Icons.link_outlined,
                    color: AppTheme.secondary,
                    title: 'Map Verse → Tag',
                    subtitle: 'Link an existing ayah to a topic',
                    onTap: () => context.go('/admin/verse-tags/new'),
                  ),
                  const SizedBox(height: 10),
                  _QuickAction(
                    icon: Icons.upload_file_outlined,
                    color: AppTheme.primaryContainer,
                    title: 'Manage Translations',
                    subtitle: 'View and edit translation entries',
                    onTap: () => context.go('/admin/translations'),
                  ),
                  const SizedBox(height: 10),
                  _QuickAction(
                    icon: Icons.web_outlined,
                    color: const Color(0xFF6C63FF),
                    title: 'Site CMS',
                    subtitle: 'Edit home content, featured ayah & announcements',
                    onTap: () => context.go('/admin/cms'),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  const _StatCard({required this.icon, required this.label, required this.count, required this.onTap});

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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 0 ? '—' : _fmt(count),
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 22),
                ),
                Text(label, style: TextStyle(color: AppTheme.outline, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(subtitle, style: TextStyle(color: AppTheme.outline, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.outline, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(color: AppTheme.outline, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
  );
}
