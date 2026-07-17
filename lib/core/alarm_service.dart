import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:audioplayers/audioplayers.dart';
import '../features/qibla/qibla_service.dart';
import 'settings_manager.dart';

class AlarmService {
  static final AlarmService instance = AlarmService._internal();
  AlarmService._internal();

  static final AudioPlayer _previewPlayer = AudioPlayer();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // v22 API: `settings` is a named parameter
    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap if needed
      },
    );

    // Create one Android notification channel per muadzin so Android
    // honours the correct sound even after the channel is created once.
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      for (final entry in _muadzinChannels.entries) {
        await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
          entry.value['channelId']!,
          entry.value['channelName']!,
          description: 'Prayer notification — ${entry.value["label"]}',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(entry.value['file']!),
        ));
      }
      // Silent channel for when adzan sound is disabled
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'prayer_alarms_silent',
        'Prayer Alarms (Silent)',
        description: 'Silent prayer time reminders',
        importance: Importance.max,
        playSound: false,
      ));
    }

    _initialized = true;
  }

  // ── Muadzin catalogue ──────────────────────────────────────────────────
  static const Map<String, Map<String, String>> _muadzinChannels = {
    'standard': {
      'file': 'adhan_standard', 'channelId': 'prayer_alarms_standard',
      'channelName': 'Daily Prayer Alarms', 'label': 'Standard',
    },
    'fajr': {
      'file': 'adhan_fajr', 'channelId': 'prayer_alarms_fajr',
      'channelName': 'Fajr & Tahajjud Alarms', 'label': 'Fajr Adzan',
    },
    'makkah': {
      'file': 'adhan_makkah', 'channelId': 'prayer_alarms_makkah',
      'channelName': 'Makkah Adzan', 'label': 'Makkah (Masjid al-Haram)',
    },
    'madinah': {
      'file': 'adhan_madinah', 'channelId': 'prayer_alarms_madinah',
      'channelName': 'Madinah Adzan', 'label': 'Madinah (Masjid Nabawi)',
    },
    'afasi': {
      'file': 'adhan_afasi', 'channelId': 'prayer_alarms_afasi',
      'channelName': 'Mishary Al-Afasi Adzan', 'label': 'Mishary Al-Afasi',
    },
    'qatami': {
      'file': 'adhan_qatami', 'channelId': 'prayer_alarms_qatami',
      'channelName': 'Nasser Al-Qatami Adzan', 'label': 'Nasser Al-Qatami',
    },
  };

  static String muadzinLabel(String key) =>
      _muadzinChannels[key]?['label'] ?? key;

  static String muadzinFile(String key) =>
      _muadzinChannels[key]?['file'] ?? 'adhan_standard';

  static List<String> get muadzinKeys => _muadzinChannels.keys.toList();

  // ── Preview: play the sound directly via AudioPlayer so user can hear it ─
  /// If [isFajr] is true, previews the Subuh/First Adzan voice.
  /// For Makkah or Madinah with isFajr=true, the special 'fajr' style asset
  /// is played instead (matching the scheduled alarm behaviour).
  Future<void> playAdzanPreview(String muadzin, {bool isFajr = false}) async {
    String resolvedKey = muadzin;
    if (isFajr && (muadzin == 'makkah' || muadzin == 'madinah')) {
      // Makkah/Madinah use the fajr adzan style for Subuh & First Adzan
      resolvedKey = 'fajr';
    }
    if (!_muadzinChannels.containsKey(resolvedKey)) return;
    final info = _muadzinChannels[resolvedKey]!;
    final file = info['file']!;
    try {
      await _previewPlayer.stop();
      await _previewPlayer.play(AssetSource('audio/$file.mp3'));
    } catch (_) {}
  }

  Future<void> stopAdzanPreview() async {
    try {
      await _previewPlayer.stop();
    } catch (_) {}
  }


  Future<void> schedulePrayerAlarms({
    required double latitude,
    required double longitude,
    required SettingsState settings,
  }) async {
    await init();
    // Cancel all previously scheduled alarms first
    await _notificationsPlugin.cancelAll();

    final now = DateTime.now();

    // Schedule alarms for the next 7 days
    int notificationId = 1;
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final date = now.add(Duration(days: dayOffset));

      // Calculate prayer times for this day
      final pt = QiblaService.getPrayerTimes(
        latitude,
        longitude,
        settings.prayerCalculationMethod,
        date: date,
        fajrOffset: settings.fajrOffset,
        sunriseOffset: settings.sunriseOffset,
        dhuhrOffset: settings.dhuhrOffset,
        asrOffset: settings.asrOffset,
        maghribOffset: settings.maghribOffset,
        ishaOffset: settings.ishaOffset,
        firstAdzanOffset: settings.firstAdzanOffset,
      );

      // Map of prayer key -> scheduled DateTime
      final Map<String, DateTime> times = {
        'first_adzan': pt.firstAdzan,
        'fajr':        pt.fajr,
        'dhuhr':       pt.dhuhr,
        'asr':         pt.asr,
        'maghrib':     pt.maghrib,
        'isha':        pt.isha,
      };

      for (final entry in times.entries) {
        final key  = entry.key;
        final time = entry.value;

        // Skip past times
        if (time.isBefore(now)) continue;

        // Determine title / body per prayer
        bool   isEnabled = false;
        String title     = '';
        String body      = '';

        if (key == 'first_adzan' && settings.enableFirstAdzan) {
          isEnabled = true;
          title     = 'Adzan Awal (Tahajjud)';
          body      = 'Waktu Adzan Awal / Tahajjud telah masuk.';
        } else if (key == 'fajr') {
          isEnabled = true;
          title     = 'Subuh (Fajr)';
          body      = 'Waktu shalat Subuh telah masuk.';
        } else if (key == 'dhuhr') {
          isEnabled = true;
          title     = 'Dzuhur (Dhuhr)';
          body      = 'Waktu shalat Dzuhur telah masuk.';
        } else if (key == 'asr') {
          isEnabled = true;
          title     = 'Ashar (Asr)';
          body      = 'Waktu shalat Ashar telah masuk.';
        } else if (key == 'maghrib') {
          isEnabled = true;
          title     = 'Maghrib';
          body      = 'Waktu shalat Maghrib telah masuk.';
        } else if (key == 'isha') {
          isEnabled = true;
          title     = 'Isya (Isha)';
          body      = 'Waktu shalat Isya telah masuk.';
        }

        if (!isEnabled) continue;

        // Build notification details
        final scheduledTzTime = tz.TZDateTime.from(time, tz.local);

        // Determine sound & channel from muadzin setting
        final String soundFile;
        final String channelId;
        final String channelName;
        final String channelDesc;

        // Check if sound is enabled for this specific prayer key
        bool soundEnabled = settings.enableAdzanSound;
        if (soundEnabled) {
          if (key == 'first_adzan') {
            soundEnabled = settings.soundFirstAdzan;
          } else if (key == 'fajr') {
            soundEnabled = settings.soundFajr;
          } else if (key == 'dhuhr') {
            soundEnabled = settings.soundDhuhr;
          } else if (key == 'asr') {
            soundEnabled = settings.soundAsr;
          } else if (key == 'maghrib') {
            soundEnabled = settings.soundMaghrib;
          } else if (key == 'isha') {
            soundEnabled = settings.soundIsha;
          }
        }

        if (!soundEnabled) {
          soundFile   = '';
          channelId   = 'prayer_alarms_silent';
          channelName = 'Prayer Alarms (Silent)';
          channelDesc = 'Silent prayer time reminders';
        } else {
          // Subuh & First Adzan use the dedicated Fajr muadzin voice.
          // For Makkah/Madinah, real mosques use a special Fajr adzan
          // (with extra "Ash-shalatu khayrun minan nawm") so we map
          // those to the 'fajr' audio asset for first_adzan and fajr.
          final bool isFajrPrayer = key == 'first_adzan' || key == 'fajr';
          String muadzinKey = isFajrPrayer
              ? settings.adzanMuadzinFajr
              : settings.adzanMuadzin;
          if (isFajrPrayer &&
              (muadzinKey == 'makkah' || muadzinKey == 'madinah')) {
            muadzinKey = 'fajr';
          }
          final info  = _muadzinChannels[muadzinKey] ?? _muadzinChannels['fajr']!;
          soundFile   = info['file']!;
          channelId   = info['channelId']!;
          channelName = info['channelName']!;
          channelDesc = 'Prayer notification \u2014 ${info["label"]}';
        }

        final androidDetails = AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          sound: soundFile.isNotEmpty ? RawResourceAndroidNotificationSound(soundFile) : null,
          playSound: soundFile.isNotEmpty,
        );

        final iosDetails = DarwinNotificationDetails(
          sound: soundFile.isNotEmpty ? '$soundFile.mp3' : null,
          presentAlert: true,
          presentBadge: true,
          presentSound: soundFile.isNotEmpty,
        );

        final notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        // v22 API: all named parameters, no UILocalNotificationDateInterpretation
        await _notificationsPlugin.zonedSchedule(
          id: notificationId++,
          title: title,
          body: body,
          scheduledDate: scheduledTzTime,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
  }
}
