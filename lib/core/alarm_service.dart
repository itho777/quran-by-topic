import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../features/qibla/qibla_service.dart';
import 'settings_manager.dart';

class AlarmService {
  static final AlarmService instance = AlarmService._internal();
  AlarmService._internal();

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

    _initialized = true;
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

        // Determine title / body / sound per prayer
        bool   isEnabled = false;
        String title     = '';
        String body      = '';
        String soundFile = 'adhan_standard';

        if (key == 'first_adzan' && settings.enableFirstAdzan) {
          isEnabled = true;
          title     = 'Adzan Awal (Tahajjud)';
          body      = 'Waktu Adzan Awal / Tahajjud telah masuk.';
          soundFile = 'adhan_fajr'; // Uses Fajr adhan sound per user requirement
        } else if (key == 'fajr') {
          isEnabled = true;
          title     = 'Subuh (Fajr)';
          body      = 'Waktu shalat Subuh telah masuk.';
          soundFile = 'adhan_fajr';
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

        final androidDetails = AndroidNotificationDetails(
          'prayer_alarms_channel',
          'Prayer Alarms',
          channelDescription: 'Notifications for Daily Muslim Prayers',
          importance: Importance.max,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound(soundFile),
          playSound: true,
        );

        final iosDetails = DarwinNotificationDetails(
          sound: '$soundFile.mp3',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
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
