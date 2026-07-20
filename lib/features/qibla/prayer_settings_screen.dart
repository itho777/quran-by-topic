import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/settings_manager.dart';
import '../../core/alarm_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'qibla_providers.dart';

class PrayerSettingsScreen extends ConsumerStatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  ConsumerState<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends ConsumerState<PrayerSettingsScreen> {
  bool _notificationGranted = false;
  bool _batteryOptimizationIgnored = false;
  bool _autoStartSupported = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notifGranted = await Permission.notification.isGranted;
    bool batteryIgnored = true;
    bool autoStartSup = false;
    if (Platform.isAndroid) {
      batteryIgnored = await Permission.ignoreBatteryOptimizations.isGranted;
      autoStartSup = await AlarmService.instance.isAutoStartSupported();
    }
    if (mounted) {
      setState(() {
        _notificationGranted = notifGranted;
        _batteryOptimizationIgnored = batteryIgnored;
        _autoStartSupported = autoStartSup;
      });
    }
  }

  @override
  void dispose() {
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
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ─── SECTION 1: CALCULATION ────────────────────────────────────────
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
                ListTile(
                  leading: _iconBox(Icons.explore_outlined, AppTheme.primary),
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
                      PopupMenuItem(value: 'kemenag',   child: Text('Kemenag (Indonesia) / MUI')),
                      PopupMenuItem(value: 'makkah',    child: Text('MAKKAH (UMM AL-QURA)')),
                      PopupMenuItem(value: 'karachi',   child: Text('KARACHI (UIS)')),
                      PopupMenuItem(value: 'isna',      child: Text('NORTH AMERICA (ISNA)')),
                      PopupMenuItem(value: 'mwl',       child: Text('WORLD LEAGUE (MWL)')),
                      PopupMenuItem(value: 'egyptian',  child: Text('EGYPTIAN SURVEY')),
                      PopupMenuItem(value: 'turkey',    child: Text('TURKEY (DIYANET)')),
                      PopupMenuItem(value: 'tehran',    child: Text('TEHRAN (UNIVERSITY)')),
                    ],
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _iconBox(Icons.edit_calendar_outlined, AppTheme.secondary),
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

          // ─── SECTION 2: SOUND MASTER SWITCH ───────────────────────────────
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
                // Master sound on/off
                ListTile(
                  leading: _iconBox(Icons.volume_up_outlined, AppTheme.primary),
                  title: Text(
                    isEn ? 'Sound Notification' : 'Notifikasi Suara',
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isEn ? 'Play sound with prayer notifications' : 'Putar suara saat notifikasi shalat',
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

                if (settings.enableAdzanSound) ...[
                  Divider(height: 1, indent: 16, endIndent: 16),

                  // ── Syuruq & Dhuha info row (tone only, no adzan) ──────────
                  ListTile(
                    leading: _iconBox(Icons.wb_sunny_outlined, Colors.orange),
                    title: Text(
                      isEn ? 'Syuruk & Dhuha — Notification Tone Only' : 'Syuruq & Dhuha — Nada Notifikasi Saja',
                      style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      isEn
                          ? 'These two times never play adzan — only a notification tone'
                          : 'Dua waktu ini tidak memainkan adzan, hanya nada notifikasi',
                      style: TextStyle(color: AppTheme.outline, fontSize: 11),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        isEn ? 'Tone only' : 'Nada saja',
                        style: TextStyle(color: Colors.orange.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16),

                  // ── Syuruq & Dhuha: custom tone picker ───────────────────
                  ListTile(
                    leading: const SizedBox(width: 34),
                    title: Text(
                      isEn ? 'Tone for Syuruk & Dhuha' : 'Nada untuk Syuruq & Dhuha',
                      style: TextStyle(color: AppTheme.onSurface, fontSize: 13),
                    ),
                    subtitle: Text(
                      settings.customSoundTitle ?? (isEn ? 'System Default' : 'Default Sistem'),
                      style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    trailing: Icon(Icons.chevron_right, color: AppTheme.outline),
                    onTap: () => _pickCustomTone(context, isEn),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16),

                  // ── Subuh & First Adzan voice picker ──────────────────────
                  _buildMuadzinRow(
                    context: context,
                    settings: settings,
                    isEn: isEn,
                    icon: Icons.nights_stay_outlined,
                    iconColor: AppTheme.primary,
                    label: isEn ? 'Subuh & First Adzan' : 'Subuh & Adzan Awal',
                    subtitle: isEn
                        ? 'Supports "As-Salatu khayrun minan-nawm" style'
                        : 'Mendukung gaya "As-Salatu Khairum minan-naum"',
                    currentKey: settings.adzanMuadzinFajr,
                    onSelect: (val) async {
                      ref.read(settingsProvider.notifier).setAdzanMuadzinFajr(val);
                      await _rescheduleAlarms();
                    },
                    menuItems: [
                      _muadzinMenuItem('fajr',    '🌙 Fajr Style', isEn ? 'Special "As-salatu khayrun minan-nawm"' : 'Adzan Subuh dengan "As-Salatu Khairum"', settings.adzanMuadzinFajr),
                      _muadzinMenuItem('makkah',  '🕌 Makkah',     'Masjid al-Haram',         settings.adzanMuadzinFajr),
                      _muadzinMenuItem('madinah', '🕌 Madinah',    'Masjid Nabawi',            settings.adzanMuadzinFajr),
                      _muadzinMenuItem('afasi',   '🎙 Mishary Al-Afasi', 'Most popular worldwide', settings.adzanMuadzinFajr),
                      _muadzinMenuItem('qatami',  '🎙 Nasser Al-Qatami', 'Beautiful recitation', settings.adzanMuadzinFajr),
                      _muadzinMenuItem('standard','🔔 Standard',   isEn ? 'Classic notification' : 'Notifikasi klasik', settings.adzanMuadzinFajr),
                      _muadzinMenuItem('tone',    isEn ? '🔔 Notification Tone' : '🔔 Nada Notifikasi', isEn ? 'System default or custom tone' : 'Bawaan sistem atau nada kustom', settings.adzanMuadzinFajr),
                    ],
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16),

                  // ── Zuhr / Asr / Maghrib / Isha voice picker ──────────────
                  _buildMuadzinRow(
                    context: context,
                    settings: settings,
                    isEn: isEn,
                    icon: Icons.mic_none_outlined,
                    iconColor: AppTheme.secondary,
                    label: isEn ? 'Zuhr / Asr / Maghrib / Isha' : 'Zhuhur / Ashar / Maghrib / Isya',
                    subtitle: isEn ? 'Regular adzan voices' : 'Suara adzan biasa',
                    currentKey: settings.adzanMuadzin,
                    onSelect: (val) async {
                      ref.read(settingsProvider.notifier).setAdzanMuadzin(val);
                      await _rescheduleAlarms();
                    },
                    menuItems: [
                      // Note: 'fajr' (As-salatu khayrun) is NOT included here
                      _muadzinMenuItem('makkah',  '🕌 Makkah',     'Masjid al-Haram',         settings.adzanMuadzin),
                      _muadzinMenuItem('madinah', '🕌 Madinah',    'Masjid Nabawi',            settings.adzanMuadzin),
                      _muadzinMenuItem('afasi',   '🎙 Mishary Al-Afasi', 'Most popular worldwide', settings.adzanMuadzin),
                      _muadzinMenuItem('qatami',  '🎙 Nasser Al-Qatami', 'Beautiful recitation', settings.adzanMuadzin),
                      _muadzinMenuItem('standard','🔔 Standard',   isEn ? 'Classic notification' : 'Notifikasi klasik', settings.adzanMuadzin),
                      _muadzinMenuItem('tone',    isEn ? '🔔 Notification Tone' : '🔔 Nada Notifikasi', isEn ? 'System default or custom tone' : 'Bawaan sistem atau nada kustom', settings.adzanMuadzin),
                    ],
                  ),
                ],

                // Tahajjud / First Adzan toggle
                Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _iconBox(Icons.nights_stay_outlined, AppTheme.primary),
                  title: Text(
                    isEn ? 'First Adzan (Tahajjud)' : 'Adzan Awal (Tahajjud)',
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isEn ? 'Schedule a notification before Fajr' : 'Jadwalkan notifikasi sebelum Subuh',
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
          const SizedBox(height: 20),

          // ─── SECTION 3: PERMISSIONS & OPTIMIZATIONS ───────────────────────
          _SectionLabel(isEn ? 'Permissions & Background Running' : 'Izin & Berjalan di Latar Belakang'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                // Notification permission
                ListTile(
                  leading: _iconBox(
                    Icons.notifications_active_outlined,
                    _notificationGranted ? const Color(0xFF4CAF50) : AppTheme.error,
                  ),
                  title: Text(
                    isEn ? 'Notification Alert Permission' : 'Izin Notifikasi Peringatan',
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _notificationGranted
                        ? (isEn ? 'Granted — visual alerts will display' : 'Diizinkan — peringatan visual akan muncul')
                        : (isEn ? 'Denied — notifications will not show' : 'Ditolak — notifikasi tidak akan muncul'),
                    style: TextStyle(color: AppTheme.outline, fontSize: 11),
                  ),
                  trailing: _notificationGranted
                      ? Icon(Icons.check_circle_outline, color: const Color(0xFF4CAF50))
                      : ElevatedButton(
                          onPressed: () async {
                            final granted = await AlarmService.instance.requestNotificationPermissions();
                            setState(() => _notificationGranted = granted);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(isEn ? 'Grant' : 'Izinkan', style: const TextStyle(fontSize: 12)),
                        ),
                ),

                if (Platform.isAndroid) ...[
                  Divider(height: 1, indent: 16, endIndent: 16),
                  // Battery optimizations
                  ListTile(
                    leading: _iconBox(
                      Icons.battery_saver_outlined,
                      _batteryOptimizationIgnored ? const Color(0xFF4CAF50) : Colors.orange,
                    ),
                    title: Text(
                      isEn ? 'Ignore Battery Optimization' : 'Abaikan Optimasi Baterai',
                      style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _batteryOptimizationIgnored
                          ? (isEn ? 'Ignored — adzan triggers reliably' : 'Diabaikan — adzan berjalan lancar')
                          : (isEn ? 'Optimizing — system might delay/silence adzan' : 'Mengoptimasi — sistem dapat menunda/membungkam adzan'),
                      style: TextStyle(color: AppTheme.outline, fontSize: 11),
                    ),
                    trailing: _batteryOptimizationIgnored
                        ? Icon(Icons.check_circle_outline, color: const Color(0xFF4CAF50))
                        : ElevatedButton(
                            onPressed: () async {
                              final ignored = await AlarmService.instance.requestIgnoreBatteryOptimizations();
                              setState(() => _batteryOptimizationIgnored = ignored);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(isEn ? 'Exempt' : 'Bebaskan', style: const TextStyle(fontSize: 12)),
                          ),
                  ),
                  if (_autoStartSupported) ...[
                    Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: _iconBox(
                        Icons.settings_power_outlined,
                        Colors.blue,
                      ),
                      title: Text(
                        isEn ? 'Enable Autostart' : 'Aktifkan Autostart',
                        style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isEn
                            ? 'Required to receive adzan alarms when the app is closed'
                            : 'Wajib agar adzan berbunyi saat aplikasi ditutup',
                        style: TextStyle(color: AppTheme.outline, fontSize: 11),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          await AlarmService.instance.openAutoStartSettings();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(isEn ? 'Setup' : 'Atur', style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── SECTION 4: TEST NOTIFICATION ─────────────────────────────────
          _SectionLabel(isEn ? 'Testing Tools' : 'Alat Pengujian'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.25)),
            ),
            child: ListTile(
              leading: _iconBox(Icons.timer_outlined, AppTheme.primary),
              title: Text(
                isEn ? 'Schedule 5-Second Test' : 'Jadwalkan Uji Coba (5 Detik)',
                style: TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                isEn
                    ? 'Trigger a test adzan notification in 5 seconds to verify'
                    : 'Picu notifikasi uji coba adzan dalam 5 detik untuk memverifikasi',
                style: TextStyle(color: AppTheme.outline, fontSize: 11),
              ),
              trailing: Icon(Icons.arrow_circle_right_outlined, color: AppTheme.primary),
              onTap: () async {
                if (!_notificationGranted) {
                  // Prompt permission first
                  final ok = await AlarmService.instance.requestNotificationPermissions();
                  setState(() => _notificationGranted = ok);
                  if (!ok) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isEn
                          ? 'Cannot schedule test without notification permission!'
                          : 'Tidak dapat menjadwalkan uji coba tanpa izin notifikasi!'),
                      backgroundColor: AppTheme.error,
                    ));
                    return;
                  }
                }

                // Schedule a notification (tests lock-screen/background delivery and sound)
                try {
                  final debugInfo = await AlarmService.instance.scheduleTestAlarm(
                    settings: settings,
                    secondsFromNow: 10,
                  );

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isEn
                        ? 'Scheduled! [$debugInfo]'
                        : 'Dijadwalkan! [$debugInfo]'),
                    duration: const Duration(seconds: 12),
                    action: SnackBarAction(
                      label: 'OK',
                      textColor: Colors.white,
                      onPressed: () {},
                    ),
                  ));
                } catch (e) {
                  if (!context.mounted) return;
                  final packageInfo = await PackageInfo.fromPlatform();
                  final pName = packageInfo.packageName;
                  final pVersion = packageInfo.version;
                  final pBuild = packageInfo.buildNumber;
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isEn
                        ? 'Notification scheduling failed (Pkg: $pName, Ver: $pVersion+$pBuild): $e'
                        : 'Gagal menjadwalkan notifikasi (Pkg: $pName, Ver: $pVersion+$pBuild): $e'),
                    backgroundColor: AppTheme.error,
                    duration: const Duration(seconds: 8),
                  ));
                }
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Helper: icon box decoration ───────────────────────────────────────────
  Widget _iconBox(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  // ── Muadzin row: icon + label + play/stop + picker ────────────────────────
  Widget _buildMuadzinRow({
    required BuildContext context,
    required SettingsState settings,
    required bool isEn,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required String currentKey,
    required Future<void> Function(String) onSelect,
    required List<PopupMenuEntry<String>> menuItems,
  }) {
    return ListTile(
      enabled: settings.enableAdzanSound,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: settings.enableAdzanSound
              ? iconColor.withValues(alpha: 0.12)
              : AppTheme.outline.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: settings.enableAdzanSound ? iconColor : AppTheme.outline,
          size: 18,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: settings.enableAdzanSound ? AppTheme.onSurface : AppTheme.outline,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: TextStyle(color: AppTheme.outline, fontSize: 10),
          ),
          Text(
            AlarmService.muadzinLabel(currentKey, isEn: isEn),
            style: TextStyle(
              color: settings.enableAdzanSound ? AppTheme.primary : AppTheme.outline.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: AlarmService.instance.previewNotifier,
            builder: (context, activePreview, _) {
              final isPlayingThis = activePreview == currentKey;
              return IconButton(
                icon: Icon(
                  isPlayingThis ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                  color: settings.enableAdzanSound
                      ? AppTheme.primary
                      : AppTheme.outline.withValues(alpha: 0.3),
                  size: 22,
                ),
                tooltip: isPlayingThis
                    ? (isEn ? 'Stop preview' : 'Hentikan adzan')
                    : (isEn ? 'Preview adzan' : 'Dengarkan adzan'),
                onPressed: settings.enableAdzanSound
                    ? () {
                        if (isPlayingThis) {
                          AlarmService.instance.stopAdzanPreview();
                        } else {
                          AlarmService.instance.playAdzanPreview(
                            currentKey,
                            customSoundUri: settings.customSoundUri,
                          );
                        }
                      }
                    : null,
              );
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.expand_more,
              color: settings.enableAdzanSound
                  ? AppTheme.outline
                  : AppTheme.outline.withValues(alpha: 0.3),
              size: 20,
            ),
            color: AppTheme.surfaceContainerHigh,
            enabled: settings.enableAdzanSound,
            onSelected: onSelect,
            itemBuilder: (context) => menuItems,
          ),
        ],
      ),
    );
  }

  // ── Custom tone picker (Android ringtone picker / iOS info) ───────────────
  Future<void> _pickCustomTone(BuildContext context, bool isEn) async {
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('com.example.tafseer_id/ringtone_picker');
        final result = await channel.invokeMethod('pickRingtone');
        if (result != null && result is Map) {
          final uri   = result['uri']   as String;
          final title = result['title'] as String;
          await ref.read(settingsProvider.notifier).setCustomSound(uri, title);
          await _rescheduleAlarms();
        }
      } catch (e) {
        debugPrint('Error invoking ringtone picker: $e');
      }
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEn
            ? 'iOS manages notification sounds via system settings.'
            : 'iOS mengelola suara notifikasi lewat pengaturan sistem.'),
      ));
    }
  }

  Future<void> _updateFirstAdzanOffset(int val) async {
    ref.read(settingsProvider.notifier).setFirstAdzanOffset(val);
    await _rescheduleAlarms();
  }

  Future<void> _rescheduleAlarms() async {
    final location = ref.read(currentLocationProvider).value;
    if (location != null) {
      await AlarmService.instance.schedulePrayerAlarms(
        latitude:  location.latitude,
        longitude: location.longitude,
        settings:  ref.read(settingsProvider),
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
                Text(label,    style: const TextStyle(fontWeight: FontWeight.w600)),
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
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.left,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
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
                          width: 50,
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
                      buildAdjustmentRow(isEn ? 'Fajr'    : 'Subuh',  'fajr',    currentSettings.fajrOffset),
                      buildAdjustmentRow(isEn ? 'Shuruk'  : 'Syuruq', 'sunrise', currentSettings.sunriseOffset),
                      buildAdjustmentRow(isEn ? 'Zuhr'    : 'Zhuhur', 'dhuhr',   currentSettings.dhuhrOffset),
                      buildAdjustmentRow(isEn ? 'Asr'     : 'Ashar',  'asr',     currentSettings.asrOffset),
                      buildAdjustmentRow('Maghrib',                    'maghrib', currentSettings.maghribOffset),
                      buildAdjustmentRow(isEn ? 'Isha'    : 'Isya',   'isha',    currentSettings.ishaOffset),
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
