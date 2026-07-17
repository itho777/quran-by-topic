import 'package:flutter/foundation.dart';
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

  final ValueNotifier<String?> previewNotifier = ValueNotifier<String?>(null);

  // ── Preview: play the sound directly via AudioPlayer so user can hear it ─
  Future<void> playAdzanPreview(String muadzin) async {
    if (!_muadzinChannels.containsKey(muadzin)) return;
    final info = _muadzinChannels[muadzin]!;
    final file = info['file']!;
    try {
      await _previewPlayer.stop();
      previewNotifier.value = muadzin;
      
      // Auto-clear active preview on completion
      _previewPlayer.onPlayerComplete.first.then((_) {
        if (previewNotifier.value == muadzin) {
          previewNotifier.value = null;
        }
      });

      await _previewPlayer.play(AssetSource('audio/$file.mp3'));
    } catch (_) {
      previewNotifier.value = null;
    }
  }

  Future<void> stopAdzanPreview() async {
    try {
      await _previewPlayer.stop();
      previewNotifier.value = null;
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
        'sunrise':     pt.sunrise,
        'dhuha':       pt.dhuha,
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

        final bool isEn = settings.appLanguage == 'en';

        if (key == 'first_adzan' && settings.enableFirstAdzan) {
          isEnabled = true;
          title     = isEn ? 'First Adzan (Tahajjud)' : 'Adzan Awal (Tahajjud)';
          body      = isEn ? 'First Adzan / Tahajjud time has entered.' : 'Waktu Adzan Awal / Tahajjud telah masuk.';
        } else if (key == 'fajr') {
          isEnabled = true;
          title     = isEn ? 'Fajr' : 'Subuh (Fajr)';
          body      = isEn ? 'Fajr prayer time has entered.' : 'Waktu shalat Subuh telah masuk.';
        } else if (key == 'sunrise') {
          isEnabled = true;
          title     = isEn ? 'Shuruk (Sunrise)' : 'Syuruq';
          body      = isEn ? 'Sunrise time has entered.' : 'Waktu Syuruq (Matahari terbit) telah masuk.';
        } else if (key == 'dhuha') {
          isEnabled = true;
          title     = 'Dhuha';
          body      = isEn ? 'Dhuha prayer time has entered.' : 'Waktu shalat Dhuha telah masuk.';
        } else if (key == 'dhuhr') {
          isEnabled = true;
          title     = isEn ? 'Zuhr' : 'Dzuhur (Dhuhr)';
          body      = isEn ? 'Zuhr prayer time has entered.' : 'Waktu shalat Dzuhur telah masuk.';
        } else if (key == 'asr') {
          isEnabled = true;
          title     = isEn ? 'Asr' : 'Ashar (Asr)';
          body      = isEn ? 'Asr prayer time has entered.' : 'Waktu shalat Ashar telah masuk.';
        } else if (key == 'maghrib') {
          isEnabled = true;
          title     = 'Maghrib';
          body      = isEn ? 'Maghrib prayer time has entered.' : 'Waktu shalat Maghrib telah masuk.';
        } else if (key == 'isha') {
          isEnabled = true;
          title     = isEn ? 'Isha' : 'Isya (Isha)';
          body      = isEn ? 'Isha prayer time has entered.' : 'Waktu shalat Isya telah masuk.';
        }

        if (!isEnabled) continue;

        // Build notification details
        final scheduledTzTime = tz.TZDateTime.from(time, tz.local);

        // Determine sound & channel
        String soundFile = '';
        String channelId = 'prayer_alarms_silent';
        String channelName = 'Prayer Alarms (Silent)';
        String channelDesc = 'Silent prayer time reminders';

        // Check if sound is enabled for this specific prayer key
        bool soundEnabled = settings.enableAdzanSound;
        if (soundEnabled) {
          if (key == 'first_adzan') {
            soundEnabled = settings.soundFirstAdzan;
          } else if (key == 'fajr') {
            soundEnabled = settings.soundFajr;
          } else if (key == 'sunrise') {
            soundEnabled = settings.soundSunrise;
          } else if (key == 'dhuha') {
            soundEnabled = settings.soundDhuha;
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

        final bool isToneOnlyPrayer = key == 'sunrise' || key == 'dhuha';

        if (soundEnabled) {
          if (settings.playToneOnly || isToneOnlyPrayer) {
            final uri = settings.customSoundUri;
            if (uri != null && uri.isNotEmpty) {
              channelId = 'prayer_alarms_tone_${uri.hashCode}';
              channelName = 'Prayer Alarms (Custom Tone)';
              channelDesc = 'Custom prayer time tone';
              soundFile = uri;
              
              // Register custom tone channel dynamically if Android
              final androidPlugin = _notificationsPlugin
                  .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
              if (androidPlugin != null) {
                await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
                  channelId,
                  channelName,
                  description: channelDesc,
                  importance: Importance.max,
                  playSound: true,
                  sound: UriAndroidNotificationSound(uri),
                ));
              }
            } else {
              channelId = 'prayer_alarms_tone_default';
              channelName = 'Prayer Alarms (System Default)';
              channelDesc = 'Default system prayer tone';
              soundFile = 'system_default';

              // Register default tone channel dynamically if Android
              final androidPlugin = _notificationsPlugin
                  .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
              if (androidPlugin != null) {
                await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
                  channelId,
                  channelName,
                  description: channelDesc,
                  importance: Importance.max,
                  playSound: true,
                ));
              }
            }
          } else {
            // Subuh & First Adzan use the dedicated Fajr muadzin voice;
            // other prayers use the regular muadzin voice.
            final bool isFajrPrayer = key == 'first_adzan' || key == 'fajr';
            final String muadzinKey = isFajrPrayer
                ? settings.adzanMuadzinFajr
                : settings.adzanMuadzin;
            final info  = _muadzinChannels[muadzinKey] ?? _muadzinChannels['makkah']!;
            soundFile   = info['file']!;
            channelId   = info['channelId']!;
            channelName = info['channelName']!;
            channelDesc = 'Prayer notification — ${info["label"]}';
          }
        }

        final androidDetails = AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          sound: soundFile.isEmpty
              ? null
              : (soundFile == 'system_default'
                  ? null
                  : ((settings.playToneOnly || isToneOnlyPrayer)
                      ? UriAndroidNotificationSound(soundFile)
                      : RawResourceAndroidNotificationSound(soundFile))),
          playSound: soundFile.isNotEmpty,
        );

        final iosDetails = DarwinNotificationDetails(
          sound: soundFile.isEmpty
              ? null
              : (soundFile == 'system_default'
                  ? null
                  : ((settings.playToneOnly || isToneOnlyPrayer)
                      ? null // default iOS sound
                      : '$soundFile.mp3')),
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
