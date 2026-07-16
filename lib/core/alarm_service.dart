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

    // Explicitly create notification channels for Android to support different sounds
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // 1. Standard channel (Dhuhr, Asr, Maghrib, Isha) -> adhan_standard
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'prayer_alarms_standard',
        'Daily Prayer Alarms',
        description: 'Notifications with Standard Adhan Sound',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('adhan_standard'),
      ));

      // 2. Fajr channel (Fajr, Adzan Awal) -> adhan_fajr
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'prayer_alarms_fajr',
        'Fajr & Tahajjud Alarms',
        description: 'Notifications with Fajr Adhan Sound',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('adhan_fajr'),
      ));
    }

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

        // Determine sound file based on user preferences
        // enableAdzanSound=false → silent (no sound)
        // adzanSoundType='fajr'     → fajr adhan for Fajr/Tahajjud, standard for others (default)
        // adzanSoundType='standard' → standard adhan for ALL prayers
        final isFajrOrTahajjud = (key == 'fajr' || key == 'first_adzan');
        String soundFile;
        if (!settings.enableAdzanSound) {
          soundFile = ''; // silent
        } else if (settings.adzanSoundType == 'standard') {
          soundFile = 'adhan_standard';
        } else {
          // 'fajr' type (default): fajr recitation for Fajr/Tahajjud, standard for others
          soundFile = isFajrOrTahajjud ? 'adhan_fajr' : 'adhan_standard';
        }

        // Pick channel accordingly
        final String channelId;
        final String channelName;
        final String channelDesc;
        if (!settings.enableAdzanSound) {
          channelId   = 'prayer_alarms_silent';
          channelName = 'Prayer Alarms (Silent)';
          channelDesc = 'Silent prayer time notifications';
        } else if (isFajrOrTahajjud && settings.adzanSoundType == 'fajr') {
          channelId   = 'prayer_alarms_fajr';
          channelName = 'Fajr & Tahajjud Alarms';
          channelDesc = 'Notifications with Fajr Adhan Sound';
        } else {
          channelId   = 'prayer_alarms_standard';
          channelName = 'Daily Prayer Alarms';
          channelDesc = 'Notifications with Standard Adhan Sound';
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
