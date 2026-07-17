import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/settings_manager.dart';
import '../../core/alarm_service.dart';
import 'qibla_providers.dart';

class PrayerSettingsScreen extends ConsumerStatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  ConsumerState<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends ConsumerState<PrayerSettingsScreen> {
  @override
  void dispose() {
    // Stop any active previews when leaving settings
    AlarmService.instance.stopAdzanPreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isEn = settings.appLanguage == 'en';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        title: Text(
          isEn ? 'Prayer & Adzan Settings' : 'Pengaturan Shalat & Adzan',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () {
            context.pop();
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ─── SECTION 1: CALCULATION ──────────────────────────────────────
          _SectionLabel(isEn ? 'Calculation & Adjustments' : 'Perhitungan & Penyesuaian'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                // Calculation Method
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.explore_outlined, color: AppTheme.primary, size: 18),
                  ),
                  title: Text(
                    isEn ? 'Calculation Method' : 'Metode Perhitungan',
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    settings.prayerCalculationMethod.toUpperCase(),
                    style: TextStyle(color: AppTheme.outline, fontSize: 11),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: Icon(Icons.expand_more, color: AppTheme.outline, size: 20),
                    color: AppTheme.surfaceContainerHigh,
                    onSelected: (newVal) async {
                      ref.read(settingsProvider.notifier).setPrayerCalculationMethod(newVal);
                      await _rescheduleAlarms();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'singapore', child: Text('MUIS (Singapore)')),
                      PopupMenuItem(value: 'kemenag', child: Text('Kemenag (Indonesia) / MUI')),
                      PopupMenuItem(value: 'makkah', child: Text('MAKKAH (UMM AL-QURA)')),
                      PopupMenuItem(value: 'karachi', child: Text('KARACHI (UIS)')),
                      PopupMenuItem(value: 'isna', child: Text('NORTH AMERICA (ISNA)')),
                      PopupMenuItem(value: 'mwl', child: Text('WORLD LEAGUE (MWL)')),
                      PopupMenuItem(value: 'egyptian', child: Text('EGYPTIAN SURVEY')),
                      PopupMenuItem(value: 'turkey', child: Text('TURKEY (DIYANET)')),
                      PopupMenuItem(value: 'tehran', child: Text('TEHRAN (UNIVERSITY)')),
                    ],
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),

                // Manual Time Adjustments Button
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit_calendar_outlined, color: AppTheme.secondary, size: 18),
                  ),
                  title: Text(
                    isEn ? 'Manual Offsets (Minutes)' : 'Penyesuaian Menit Manual',
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isEn ? 'Adjust prayer offsets individually' : 'Sesuaikan pergeseran waktu shalat',
                    style: TextStyle(color: AppTheme.outline, fontSize: 11),
                  ),
                  trailing: Icon(Icons.chevron_right, color: AppTheme.outline, size: 20),
                  onTap: () => _showPrayerAdjustmentDialog(context, settings, isEn),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── SECTION 2: ADZAN VOICES ─────────────────────────────────────
          _SectionLabel(isEn ? 'Adzan Audio Settings' : 'Pengaturan Suara Adzan'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                // Adzan Sound Toggle
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.volume_up_outlined, color: AppTheme.primary, size: 18),
                  ),
                  title: Text(
                    isEn ? 'Adzan Sound' : 'Suara Adzan',
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isEn
                        ? 'Play adzan audio with prayer notifications'
                        : 'Putar suara adzan saat notifikasi shalat',
                    style: TextStyle(color: AppTheme.outline, fontSize: 11),
                  ),
                  trailing: Switch(
                    value: settings.enableAdzanSound,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (val) async {
                      ref.read(settingsProvider.notifier).setEnableAdzanSound(val);
                      await _rescheduleAlarms();
                    },
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),

                // Muadzin Voice Selector
                ListTile(
                  enabled: settings.enableAdzanSound,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: settings.enableAdzanSound
                          ? AppTheme.secondary.withValues(alpha: 0.12)
                          : AppTheme.outline.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.mic_none_outlined,
                      color: settings.enableAdzanSound ? AppTheme.secondary : AppTheme.outline,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    isEn ? 'Muadzin (Adzan Voice)' : 'Pilihan Suadzan / Muadzin',
                    style: TextStyle(
                      color: settings.enableAdzanSound ? AppTheme.onSurface : AppTheme.outline,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    AlarmService.muadzinLabel(settings.adzanMuadzin),
                    style: TextStyle(
                      color: settings.enableAdzanSound ? AppTheme.primary : AppTheme.outline.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Play Preview button
                      IconButton(
                        icon: Icon(
                          Icons.play_circle_outline,
                          color: settings.enableAdzanSound ? AppTheme.primary : AppTheme.outline.withValues(alpha: 0.3),
                          size: 22,
                        ),
                        tooltip: isEn ? 'Preview adzan' : 'Dengarkan adzan',
                        onPressed: settings.enableAdzanSound
                            ? () => AlarmService.instance.playAdzanPreview(settings.adzanMuadzin)
                            : null,
                      ),
                      // Stop Preview button
                      IconButton(
                        icon: Icon(
                          Icons.stop_circle_outlined,
                          color: settings.enableAdzanSound ? AppTheme.outline : AppTheme.outline.withValues(alpha: 0.3),
                          size: 22,
                        ),
                        tooltip: isEn ? 'Stop preview' : 'Hentikan adzan',
                        onPressed: settings.enableAdzanSound
                            ? () => AlarmService.instance.stopAdzanPreview()
                            : null,
                      ),
                      // Muadzin list
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.expand_more,
                          color: settings.enableAdzanSound ? AppTheme.outline : AppTheme.outline.withValues(alpha: 0.3),
                          size: 20,
                        ),
                        color: AppTheme.surfaceContainerHigh,
                        enabled: settings.enableAdzanSound,
                        onSelected: (newVal) async {
                          ref.read(settingsProvider.notifier).setAdzanMuadzin(newVal);
                          await _rescheduleAlarms();
                        },
                        itemBuilder: (context) => [
                          _muadzinMenuItem('makkah',  '🕌 Makkah', 'Masjid al-Haram', settings.adzanMuadzin),
                          _muadzinMenuItem('madinah', '🕌 Madinah', 'Masjid Nabawi', settings.adzanMuadzin),
                          _muadzinMenuItem('afasi',   '🎙 Mishary Al-Afasi', 'Most popular worldwide', settings.adzanMuadzin),
                          _muadzinMenuItem('qatami',  '🎙 Nasser Al-Qatami', 'Beautiful recitation', settings.adzanMuadzin),
                          _muadzinMenuItem('standard','🔔 Standard', 'Classic notification sound', settings.adzanMuadzin),
                          _muadzinMenuItem('fajr',    '🌙 Fajr Style', 'Special Fajr adzan', settings.adzanMuadzin),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),

                // Tahajjud / First Adzan Toggle
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.nights_stay_outlined, color: AppTheme.primary, size: 18),
                  ),
                  title: Text(
                    isEn ? 'First Adzan (Tahajjud)' : 'Adzan Awal (Tahajjud)',
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isEn
                        ? 'Schedule a notification before Fajr'
                        : 'Jadwalkan notifikasi sebelum Subuh',
                    style: TextStyle(color: AppTheme.outline, fontSize: 11),
                  ),
                  trailing: Switch(
                    value: settings.enableFirstAdzan,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (val) async {
                      ref.read(settingsProvider.notifier).setEnableFirstAdzan(val);
                      await _rescheduleAlarms();
                    },
                  ),
                ),
                if (settings.enableFirstAdzan) ...[
                  Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const SizedBox(width: 34),
                    title: Text(
                      isEn ? 'Minutes before Fajr' : 'Menit sebelum Subuh',
                      style: TextStyle(color: AppTheme.onSurface, fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: settings.firstAdzanOffset > 10
                              ? () => _updateFirstAdzanOffset(settings.firstAdzanOffset - 5)
                              : null,
                        ),
                        Text(
                          '${settings.firstAdzanOffset}m',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: settings.firstAdzanOffset < 120
                              ? () => _updateFirstAdzanOffset(settings.firstAdzanOffset + 5)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFirstAdzanOffset(int val) async {
    ref.read(settingsProvider.notifier).setFirstAdzanOffset(val);
    await _rescheduleAlarms();
  }

  Future<void> _rescheduleAlarms() async {
    final location = ref.read(currentLocationProvider).value;
    if (location != null) {
      await AlarmService.instance.schedulePrayerAlarms(
        latitude: location.latitude,
        longitude: location.longitude,
        settings: ref.read(settingsProvider),
      );
    }
  }

  PopupMenuItem<String> _muadzinMenuItem(
      String value, String label, String subtitle, String selected) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          if (selected == value)
            const Icon(Icons.check, size: 16, color: Colors.green),
        ],
      ),
    );
  }

  void _showPrayerAdjustmentDialog(
      BuildContext context, SettingsState freshSettings, bool isEn) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildAdjustmentRow(String label, String key, int currentValue) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: () async {
                            final newVal = currentValue - 1;
                            if (newVal >= -60) {
                              await ref.read(settingsProvider.notifier).setPrayerOffset(key, newVal);
                              await _rescheduleAlarms();
                              setDialogState(() {});
                            }
                          },
                        ),
                        SizedBox(
                          width: 45,
                          child: Text(
                            currentValue >= 0 ? '+$currentValue m' : '$currentValue m',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: () async {
                            final newVal = currentValue + 1;
                            if (newVal <= 60) {
                              await ref.read(settingsProvider.notifier).setPrayerOffset(key, newVal);
                              await _rescheduleAlarms();
                              setDialogState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            final currentSettings = ref.watch(settingsProvider);

            return AlertDialog(
              backgroundColor: AppTheme.surfaceContainerHigh,
              title: Text(
                isEn ? 'Tune Prayer Times' : 'Sesuaikan Waktu Shalat',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildAdjustmentRow('Subuh (Fajr)', 'fajr', currentSettings.fajrOffset),
                      buildAdjustmentRow('Syuruq (Sunrise)', 'sunrise', currentSettings.sunriseOffset),
                      buildAdjustmentRow('Dzuhur (Dhuhr)', 'dhuhr', currentSettings.dhuhrOffset),
                      buildAdjustmentRow('Ashar (Asr)', 'asr', currentSettings.asrOffset),
                      buildAdjustmentRow('Maghrib', 'maghrib', currentSettings.maghribOffset),
                      buildAdjustmentRow('Isya (Isha)', 'isha', currentSettings.ishaOffset),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isEn ? 'Close' : 'Tutup', style: TextStyle(color: AppTheme.primary)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: AppTheme.outline,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
