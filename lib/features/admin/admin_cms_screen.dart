import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import 'admin_cms_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Site Config CMS Screen — /admin/cms
// Allows the admin to edit home page content, featured ayah, and logo settings
// ─────────────────────────────────────────────────────────────────────────────
class AdminCmsScreen extends ConsumerStatefulWidget {
  const AdminCmsScreen({super.key});
  @override
  ConsumerState<AdminCmsScreen> createState() => _AdminCmsScreenState();
}

class _AdminCmsScreenState extends ConsumerState<AdminCmsScreen> {
  bool _loading = true;
  Map<String, String> _config = {};

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('site_config')
          .select('key, value');
      final map = <String, String>{};
      for (final row in List<Map<String, dynamic>>.from(res)) {
        map[row['key'] as String] = row['value'] as String;
      }
      setState(() { _config = map; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _edit(String key, String title, {bool multiline = true}) async {
    final current = _config[key] ?? '';
    final saved = await AdminEditDialog.show(
      context,
      title: title,
      initialText: current,
      multiline: multiline,
      onSave: (newText) async {
        await adminUpdateSiteConfig(key, newText);
        setState(() => _config[key] = newText);
      },
    );
    if (saved == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved ✓'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Widget _row(String label, String key, {bool multiline = true, String? hint}) {
    final val = _config[key];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: ListTile(
        title: Text(label,
            style: TextStyle(color: AppTheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hint != null) ...[
              Text(hint, style: TextStyle(color: AppTheme.outline, fontSize: 10)),
              const SizedBox(height: 2),
            ],
            Text(
              val ?? '(not set)',
              style: TextStyle(
                color: val != null ? AppTheme.onSurfaceVariant : AppTheme.outline,
                fontSize: 12,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: Icon(Icons.edit_outlined, color: AppTheme.primary, size: 18),
          onPressed: () => _edit(key, label, multiline: multiline),
        ),
        onTap: () => _edit(key, label, multiline: multiline),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        leading: BackButton(color: AppTheme.primary),
        title: Row(children: [
          Icon(Icons.web_outlined, color: AppTheme.primary, size: 18),
          SizedBox(width: 8),
          Text('Site CMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.outline),
            onPressed: _loadConfig,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadConfig,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Home Page Content ───────────────────────────────────
                  _sectionLabel('Home Page'),
                  const SizedBox(height: 8),
                  _row('Hero Title (Arabic)', 'home_hero_title',
                      hint: 'Displayed as large Arabic text on home screen'),
                  _row('Hero Subtitle', 'home_hero_subtitle', multiline: false,
                      hint: 'Translation shown below the Arabic text'),
                  _row('App Tagline', 'home_tagline', multiline: false,
                      hint: 'Short description shown under app name'),
                  const SizedBox(height: 20),

                  // ── Featured Ayah ───────────────────────────────────────
                  _sectionLabel('Featured Ayah of the Day'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '💡 Use verse_key format: sura:ayah — e.g. 2:255 for Ayat Kursi, 1:1 for Al-Fatihah 1',
                      style: TextStyle(color: AppTheme.outline, fontSize: 11, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _row('Featured Verse Key', 'featured_ayah_key', multiline: false,
                      hint: 'Format: sura:ayah (e.g. 2:255)'),
                  _row('Featured Ayah Note', 'featured_ayah_note', multiline: false,
                      hint: 'Short description shown on the featured card'),
                  const SizedBox(height: 20),

                  // ── Announcement Banner ─────────────────────────────────
                  _sectionLabel('Announcement Banner'),
                  const SizedBox(height: 8),
                  _row('Banner Text', 'announcement_text', multiline: false,
                      hint: 'Leave blank to hide the banner'),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 0),
    child: Text(text.toUpperCase(),
        style: TextStyle(
            color: AppTheme.outline, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
  );
}
