import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/settings_manager.dart';
import '../../core/auth_provider.dart';

void _showCreditsPopup(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) {
      final titleColor = AppTheme.primary;
      final textColor = AppTheme.onSurface;
      final linkColor = AppTheme.secondary;

      Future<void> launchUrlString(String urlString) async {
        final uri = Uri.tryParse(urlString);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      Widget buildCreditItem(String text, {String? url}) {
        if (url != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: InkWell(
              onTap: () => launchUrlString(url),
              child: Text(
                text,
                style: TextStyle(
                  color: linkColor,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 13),
          ),
        );
      }

      return AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.favorite_rounded, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Credits & Attributions',
              style: TextStyle(color: AppTheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Scrollbar(
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Gratitude & Acknowledgement',
                  style: TextStyle(color: titleColor, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                buildCreditItem('• Allah Azza wa Jalla'),
                buildCreditItem('• Prophet Muhammad PBUH'),
                buildCreditItem('• Family and Friends'),
                const SizedBox(height: 16),
                Text(
                  'Data & Content Sources',
                  style: TextStyle(color: titleColor, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                buildCreditItem('• Tanzil.net (Quran text, translations, transliterations)', url: 'https://tanzil.net'),
                buildCreditItem('• everyayah.com (Audio stream)', url: 'https://everyayah.com'),
                buildCreditItem('• mp3quran.net (Alternative surah-level audio)', url: 'https://mp3quran.net'),
                buildCreditItem(
                  '• AL SADIQIN Press & Ben Abrahamson (Tafsir Tabari, Baghawi, Qurtubi, Baidawi, Ibn Kathir, Jalalayn, Suyuti & Fath al-Qadir)',
                  url: 'https://alsadiqin.org/tafsir/',
                ),
                buildCreditItem('• Royal Aal al-Bayt Institute (Asbab al-Nuzul by Al-Wahidi)'),
                buildCreditItem('• Kemenag RI (Asbabun-Nuzul & Translation ID)'),
                buildCreditItem('• H. Suhardi (Indeks Al-Qur’an)'),
                buildCreditItem('• Abu Farhah (Indeks Quran)'),
                buildCreditItem('• Kongsi Ebooks', url: 'https://kongsiebooks.blogspot.com/2010/04/islam-indeks-al-quran.html'),
                buildCreditItem('• Quranku Quranmu', url: 'http://qurankuquranmu.blogspot.com/2012/12/indeks-al-quran-berdasarkan-klasifikasi.html'),
                buildCreditItem('• Saadus Wordpres Indeks', url: 'https://saadus.wordpress.com/2011/02/05/indeks-al-quran-ms-excel-dan-ms-access/'),
                const SizedBox(height: 16),
                Text(
                  'Assets & Technology',
                  style: TextStyle(color: titleColor, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                buildCreditItem('• Quranpedia Hafs KFQC SVG (Mushaf SVG images)', url: 'https://github.com/quranpedia/quran-svg'),
                buildCreditItem('• Google (Alphabet Inc.)', url: 'https://google.com'),
                buildCreditItem('• GitHub', url: 'https://github.com'),
                buildCreditItem('• Cloudflare', url: 'https://cloudflare.com'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      );
    },
  );
}


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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primary),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ── Fitur & Personal ────────────────────────────────────────────────
          _SectionLabel(settings.appLanguage == 'en' ? 'Personal & Features' : 'Fitur & Personal'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                // Profile & Account
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.account_circle_outlined, color: AppTheme.primary, size: 18),
                  ),
                  title: Text(
                    settings.appLanguage == 'en' ? 'Profile & Account' : 'Profil & Akun',
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    ref.watch(currentUserProvider) != null
                        ? (ref.watch(currentUserProvider)!.email ?? '')
                        : (settings.appLanguage == 'en' ? 'Sign in to sync your bookmarks' : 'Masuk untuk sinkronisasi bookmark'),
                    style: TextStyle(color: AppTheme.outline, fontSize: 11),
                  ),
                  trailing: Icon(Icons.chevron_right, color: AppTheme.outline, size: 18),
                  onTap: () => context.go('/profile'),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),

                // Saved Verses (Bookmarks)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.bookmark_outline, color: AppTheme.secondary, size: 18),
                  ),
                  title: Text(
                    settings.appLanguage == 'en' ? 'Saved Verses' : 'Ayat Tersimpan (Bookmark)',
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    settings.appLanguage == 'en' ? 'View and manage your bookmarked verses' : 'Lihat dan kelola ayat yang Anda simpan',
                    style: TextStyle(color: AppTheme.outline, fontSize: 11),
                  ),
                  trailing: Icon(Icons.chevron_right, color: AppTheme.outline, size: 18),
                  onTap: () => context.go('/bookmarks'),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),

                // Library / Downloads
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.bronzeMute.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.download_for_offline_outlined, color: AppTheme.bronzeMute, size: 18),
                  ),
                  title: Text(
                    settings.appLanguage == 'en' ? 'Offline Library' : 'Perpustakaan Offline (Unduhan)',
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    settings.appLanguage == 'en' ? 'Manage offline mushaf pages and audio files' : 'Kelola halaman mushaf dan file audio offline',
                    style: TextStyle(color: AppTheme.outline, fontSize: 11),
                  ),
                  trailing: Icon(Icons.chevron_right, color: AppTheme.outline, size: 18),
                  onTap: () => context.go('/library'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

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

                // Mushaf Full Width
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.fit_screen_outlined, color: AppTheme.primary, size: 18),
                  ),
                  title: Text('Mushaf Full Width', style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Stretch pages to fill screen width (tap/pinch to scroll vertically)', style: TextStyle(color: AppTheme.outline, fontSize: 11)),
                  trailing: Switch(
                    value: settings.mushafFullWidth,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (val) async {
                      await ref.read(settingsProvider.notifier).setMushafFullWidth(val);
                    },
                  ),
                ),
                
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
                  trailing: PopupMenuButton<String>(
                    icon: Icon(Icons.expand_more, color: AppTheme.outline, size: 20),
                    color: AppTheme.surfaceContainerHigh,
                    onSelected: (newVal) {
                      ref.read(settingsProvider.notifier).setDefaultTranslationSource(newVal);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'id.kemenag',
                        child: Text('INDONESIAN'),
                      ),
                      PopupMenuItem(
                        value: 'en.sahih',
                        child: Text('ENGLISH'),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
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
                                  Text(
                                    settings.appLanguage == 'en' ? 'Translation Font Size' : 'Ukuran Font Terjemahan',
                                    style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  Text('${settings.translationFontSize.toInt()} px', style: TextStyle(color: AppTheme.outline, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          settings.appLanguage == 'en' ? 'In the name of Allah' : 'Dengan nama Allah',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: settings.translationFontSize, color: AppTheme.onSurfaceVariant),
                        ),
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
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.hasData ? snapshot.data!.version : '3.0.0-beta';
              final buildNum = snapshot.hasData ? snapshot.data!.buildNumber : '9';
              final packageName = snapshot.hasData ? snapshot.data!.packageName : 'id.tafseer.app';
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AppTheme.getMushafIcon(color: AppTheme.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tafseer.id — Qurʼan by Topic',
                            style: TextStyle(
                              color: AppTheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'v$version  •  Build $buildNum',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            packageName,
                            style: TextStyle(
                              color: AppTheme.outline,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.favorite_border_rounded,
            iconColor: AppTheme.primary,
            title: 'Credits & Attributions',
            subtitle: 'Sources, assets, and acknowledgements',
            onTap: () => _showCreditsPopup(context),
          ),
          const SizedBox(height: 32),
          Center(
            child: Opacity(
              opacity: 0.85,
              child: Image.asset(
                AppTheme.isDark
                    ? 'assets/images/logo_dark.png'
                    : 'assets/images/logo_light.png',
                height: 48,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              settings.appLanguage == 'en' ? 'Qur\u02bcan by Topic' : 'Al-Qur\u02bcan by Topik',
              style: TextStyle(
                color: AppTheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Center(
            child: Text(
              settings.appLanguage == 'en' ? 'Read, Comprehend, Apply' : 'Baca, Pahami, Amalkan',
              style: TextStyle(
                color: AppTheme.outline,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 32),
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
    this.onTap,
  });

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

