import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/settings_manager.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        title: const Text('Settings & More', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: AppTheme.primary),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ── Display ───────────────────────────────────────────────────────
          _SectionLabel('Display & Content Settings'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                // Theme Mode
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.palette_outlined, color: AppTheme.secondary, size: 18),
                  ),
                  title: Text('Theme Mode', style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(themeMode.name.toUpperCase(),
                      style: TextStyle(color: AppTheme.outline, fontSize: 11)),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<ThemeMode>(
                      value: themeMode,
                      dropdownColor: AppTheme.surfaceContainer,
                      icon: Icon(Icons.expand_more, color: AppTheme.outline, size: 16),
                      style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                      onChanged: (newMode) {
                        if (newMode != null) {
                          ref.read(themeModeProvider.notifier).setThemeMode(newMode);
                        }
                      },
                      items: ThemeMode.values.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(mode.name.toUpperCase()),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                
                // Show Transliteration
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.translate, color: AppTheme.primary, size: 18),
                  ),
                  title: Text('Show Transliteration', style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Display transliteration text under Arabic verses', style: TextStyle(color: AppTheme.outline, fontSize: 11)),
                  trailing: Switch(
                    value: settings.showTransliteration,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (val) {
                      ref.read(settingsProvider.notifier).setShowTransliteration(val);
                    },
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                
                // Default Translation Source
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.bronzeMute.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.language, color: AppTheme.bronzeMute, size: 18),
                  ),
                  title: Text('Preferred Translation', style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    settings.defaultTranslationSource == 'id.kemenag' ? 'Kemenag RI (Indonesian)' : 'Sahih International (English)',
                    style: TextStyle(color: AppTheme.outline, fontSize: 11),
                  ),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: settings.defaultTranslationSource,
                      dropdownColor: AppTheme.surfaceContainer,
                      icon: Icon(Icons.expand_more, color: AppTheme.outline, size: 16),
                      style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                      onChanged: (newVal) {
                        if (newVal != null) {
                          ref.read(settingsProvider.notifier).setDefaultTranslationSource(newVal);
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'id.kemenag',
                          child: Text('INDONESIAN'),
                        ),
                        DropdownMenuItem(
                          value: 'en.sahih',
                          child: Text('ENGLISH'),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),

                // Arabic Font Size Slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.format_size, color: AppTheme.secondary, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Arabic Font Size', style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                                  Text('${settings.arabicFontSize.toInt()} px', style: TextStyle(color: AppTheme.outline, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                          // Arabic preview
                          Text(
                            'بِسْمِ اللَّهِ',
                            style: AppTheme.arabicStyle(fontSize: settings.arabicFontSize * 0.7, color: AppTheme.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppTheme.primary,
                          inactiveTrackColor: AppTheme.outlineVariant.withValues(alpha: 0.3),
                          thumbColor: AppTheme.primary,
                          overlayColor: AppTheme.primary.withValues(alpha: 0.2),
                          valueIndicatorColor: AppTheme.surfaceContainerHigh,
                          valueIndicatorTextStyle: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                        ),
                        child: Slider(
                          value: settings.arabicFontSize,
                          min: 20,
                          max: 48,
                          divisions: 14,
                          label: '${settings.arabicFontSize.toInt()}px',
                          onChanged: (val) {
                            ref.read(settingsProvider.notifier).setArabicFontSize(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),

                // Translation Font Size Slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.outline.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.text_fields, color: AppTheme.outline, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Translation Font Size', style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                                  Text('${settings.translationFontSize.toInt()} px', style: TextStyle(color: AppTheme.outline, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                          // Translation preview
                          Text(
                            'In the name of Allah',
                            style: TextStyle(fontSize: settings.translationFontSize, color: AppTheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppTheme.primary,
                          inactiveTrackColor: AppTheme.outlineVariant.withValues(alpha: 0.3),
                          thumbColor: AppTheme.primary,
                          overlayColor: AppTheme.primary.withValues(alpha: 0.2),
                          valueIndicatorColor: AppTheme.surfaceContainerHigh,
                          valueIndicatorTextStyle: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                        ),
                        child: Slider(
                          value: settings.translationFontSize,
                          min: 12,
                          max: 24,
                          divisions: 6,
                          label: '${settings.translationFontSize.toInt()}px',
                          onChanged: (val) {
                            ref.read(settingsProvider.notifier).setTranslationFontSize(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Reset ─────────────────────────────────────────────────────────
          _SectionLabel('Reset'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Row(
                        children: [
                          Icon(Icons.restore, color: AppTheme.error, size: 20),
                          SizedBox(width: 8),
                          Text('Reset to Defaults', style: TextStyle(color: AppTheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: Text(
                        'This will reset all settings to their factory defaults:\n\n'
                        '• Language: Indonesian\n'
                        '• Translation: Kemenag RI\n'
                        '• Reciter: Alafasy 128kbps\n'
                        '• Font sizes: default\n'
                        '• Show transliteration: on\n\n'
                        'Your reading data is not affected.',
                        style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13, height: 1.5),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel', style: TextStyle(color: AppTheme.outline)),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Reset', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(settingsProvider.notifier).resetToDefaults();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text('Settings reset to defaults'),
                            ],
                          ),
                          backgroundColor: AppTheme.surfaceContainerHigh,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.restore, color: AppTheme.error, size: 18),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reset to Defaults',
                                style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600, fontSize: 14)),
                            Text('Restore all settings to factory defaults',
                                style: TextStyle(color: AppTheme.outline, fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppTheme.error, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── About ─────────────────────────────────────────────────────────
          _SectionLabel('About'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.info_outline,
            iconColor: AppTheme.outline,
            title: 'App Version',
            subtitle: 'Tafseer ID v1.0.0',
            trailing: Text('1.0.0',
                style: TextStyle(color: AppTheme.outline, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(color: AppTheme.outline, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  }) : onTap = null;

  @override
  Widget build(BuildContext context) {
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(subtitle,
                          style: TextStyle(color: AppTheme.outline, fontSize: 12)),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

