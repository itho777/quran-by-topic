import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:adhan/adhan.dart';
import '../../features/qibla/qibla_service.dart';

/// Service layer for synchronizing Tafseer.id app state with Home Screen Widgets
/// (Ayah of the Day, Prayer Times C1/C2/C4, Last Read)
///
/// Uses home_widget ^0.9.x API — `updateWidget(name:)` only.
/// The `androidName` parameter was removed in home_widget 0.6.0.
class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  /// Group ID for iOS AppGroup / Android SharedPrefs
  static const String appGroupId = 'group.id.tafseer.app';

  /// Shared prefs key that widgets read to determine UI language ('id' or 'en')
  static const String langKey = 'hw_language';

  /// Update "Ayah of the Day" Widget Payload
  Future<void> updateAyahWidget({
    required String arabic,
    required String translation,
    required String surahRef,
    required int surahNo,
    required int ayahNo,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('hw_ayah_arabic', arabic);
      await HomeWidget.saveWidgetData<String>('hw_ayah_translation', translation);
      await HomeWidget.saveWidgetData<String>('hw_ayah_surah_ref', surahRef);
      await HomeWidget.saveWidgetData<int>('hw_ayah_surah_no', surahNo);
      await HomeWidget.saveWidgetData<int>('hw_ayah_ayah_no', ayahNo);

      await HomeWidget.saveWidgetData<String>('flutter.hw_ayah_arabic', arabic);
      await HomeWidget.saveWidgetData<String>('flutter.hw_ayah_translation', translation);
      await HomeWidget.saveWidgetData<String>('flutter.hw_ayah_surah_ref', surahRef);
      await HomeWidget.saveWidgetData<int>('flutter.hw_ayah_surah_no', surahNo);
      await HomeWidget.saveWidgetData<int>('flutter.hw_ayah_ayah_no', ayahNo);

      await HomeWidget.updateWidget(name: 'AyahWidgetProvider');
      debugPrint('Updated AyahWidgetProvider');
    } catch (e) {
      debugPrint('Error updating AyahWidgetProvider: $e');
    }
  }

  /// Update "Prayer Times & Countdown" Widgets (C1, C2, C4)
  Future<void> updatePrayerTimesWidget({
    required String subuh,
    required String dzuhur,
    required String ashar,
    required String maghrib,
    required String isya,
    required String nextPrayerName,
    required String nextPrayerTime,
    required String countdown,
    required String hijriDate,
    String location = 'Jakarta',
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('hw_prayer_subuh', subuh);
      await HomeWidget.saveWidgetData<String>('hw_prayer_dzuhur', dzuhur);
      await HomeWidget.saveWidgetData<String>('hw_prayer_ashar', ashar);
      await HomeWidget.saveWidgetData<String>('hw_prayer_maghrib', maghrib);
      await HomeWidget.saveWidgetData<String>('hw_prayer_isya', isya);
      await HomeWidget.saveWidgetData<String>('hw_next_prayer_name', nextPrayerName);
      await HomeWidget.saveWidgetData<String>('hw_next_prayer_time', nextPrayerTime);
      await HomeWidget.saveWidgetData<String>('hw_countdown', countdown);
      await HomeWidget.saveWidgetData<String>('hw_hijri_date', hijriDate);
      await HomeWidget.saveWidgetData<String>('hw_location', location);

      await HomeWidget.saveWidgetData<String>('flutter.hw_prayer_subuh', subuh);
      await HomeWidget.saveWidgetData<String>('flutter.hw_prayer_dzuhur', dzuhur);
      await HomeWidget.saveWidgetData<String>('flutter.hw_prayer_ashar', ashar);
      await HomeWidget.saveWidgetData<String>('flutter.hw_prayer_maghrib', maghrib);
      await HomeWidget.saveWidgetData<String>('flutter.hw_prayer_isya', isya);
      await HomeWidget.saveWidgetData<String>('flutter.hw_next_prayer_name', nextPrayerName);
      await HomeWidget.saveWidgetData<String>('flutter.hw_next_prayer_time', nextPrayerTime);
      await HomeWidget.saveWidgetData<String>('flutter.hw_countdown', countdown);
      await HomeWidget.saveWidgetData<String>('flutter.hw_hijri_date', hijriDate);
      await HomeWidget.saveWidgetData<String>('flutter.hw_location', location);

      // Trigger update for all prayer time widget variations
      await HomeWidget.updateWidget(name: 'PrayerC1WidgetProvider');
      await HomeWidget.updateWidget(name: 'PrayerC2WidgetProvider');
      await HomeWidget.updateWidget(name: 'PrayerC4WidgetProvider');
      await HomeWidget.updateWidget(name: 'PrayerC5WidgetProvider');
      debugPrint('Updated Prayer Widget Providers (C1, C2, C4, C5)');
    } catch (e) {
      debugPrint('Error updating Prayer Widget Providers: $e');
    }
  }

  /// Update "Last Read & Quick Bookmark" Widget
  Future<void> updateLastReadWidget({
    required String surahName,
    required int surahNo,
    required int ayahNo,
    required double progress,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('hw_last_surah_name', surahName);
      await HomeWidget.saveWidgetData<int>('hw_last_surah_no', surahNo);
      await HomeWidget.saveWidgetData<int>('hw_last_ayah_no', ayahNo);
      await HomeWidget.saveWidgetData<double>('hw_last_progress', progress);

      await HomeWidget.saveWidgetData<String>('flutter.hw_last_surah_name', surahName);
      await HomeWidget.saveWidgetData<int>('flutter.hw_last_surah_no', surahNo);
      await HomeWidget.saveWidgetData<int>('flutter.hw_last_ayah_no', ayahNo);
      await HomeWidget.saveWidgetData<double>('flutter.hw_last_progress', progress);

      await HomeWidget.updateWidget(name: 'LastReadWidgetProvider');
      await HomeWidget.updateWidget(name: 'PrayerC5WidgetProvider');
      debugPrint('Updated LastReadWidgetProvider & PrayerC5WidgetProvider');
    } catch (e) {
      debugPrint('Error updating LastReadWidgetProvider: $e');
    }
  }

  /// Sync the app language to home-screen widgets.
  /// Call this on startup and whenever the user changes language in settings.
  Future<void> syncLanguage(String lang) async {
    try {
      await HomeWidget.saveWidgetData<String>(langKey, lang);
      await HomeWidget.saveWidgetData<String>('flutter.$langKey', lang);
      // Refresh all widget types so labels update immediately
      await HomeWidget.updateWidget(name: 'AyahWidgetProvider');
      await HomeWidget.updateWidget(name: 'PrayerC1WidgetProvider');
      await HomeWidget.updateWidget(name: 'PrayerC2WidgetProvider');
      await HomeWidget.updateWidget(name: 'PrayerC4WidgetProvider');
      await HomeWidget.updateWidget(name: 'PrayerC5WidgetProvider');
      await HomeWidget.updateWidget(name: 'LastReadWidgetProvider');
      debugPrint('Synced widget language: $lang');
    } catch (e) {
      debugPrint('Error syncing widget language: $e');
    }
  }

  /// Centralized sync of Featured Ayah of the Day to Home Widget
  Future<void> syncFeaturedAyah({String lang = 'id'}) async {
    try {
      final db = Supabase.instance.client;
      final cfgRes = await db
          .from('site_config')
          .select('key, value')
          .inFilter('key', [
            'featured_ayah_key',
            'featured_ayah_note',
            'featured_rotation_mode'
          ]);

      String verseKey = '2:255';
      String rotationMode = 'manual';

      for (final row in List<Map<String, dynamic>>.from(cfgRes)) {
        final k = row['key'] as String?;
        if (k == null) continue;
        final v = (row['value'] as String?) ?? '';
        if (k == 'featured_ayah_key') verseKey = v;
        if (k == 'featured_rotation_mode') rotationMode = v;
      }

      int suraId = 2;
      int ayahNum = 255;

      if (rotationMode == 'daily_random') {
        final now = DateTime.now();
        final seed = now.year * 365 + now.month * 31 + now.day;
        final verseDbId = (seed % 6236) + 1;
        final vRes = await db
            .from('verses')
            .select('sura_id, ayah_number, verse_key')
            .eq('id', verseDbId)
            .maybeSingle();
        if (vRes != null) {
          suraId = vRes['sura_id'] as int;
          ayahNum = vRes['ayah_number'] as int;
          verseKey = (vRes['verse_key'] as String?) ?? '$suraId:$ayahNum';
        }
      } else if (rotationMode == 'daily_playlist') {
        final playlistRes = await db
            .from('featured_playlist')
            .select('verse_key')
            .order('id');
        final playlist = List<Map<String, dynamic>>.from(playlistRes);
        if (playlist.isNotEmpty) {
          final now = DateTime.now();
          final daysSinceEpoch = now.difference(DateTime(1970, 1, 1)).inDays;
          final item = playlist[daysSinceEpoch % playlist.length];
          verseKey = (item['verse_key'] as String?) ?? '2:255';
          final parts = verseKey.split(':');
          suraId = int.tryParse(parts[0]) ?? 2;
          ayahNum = int.tryParse(parts.length > 1 ? parts[1] : '255') ?? 255;
        }
      } else {
        final parts = verseKey.split(':');
        suraId = int.tryParse(parts[0]) ?? 2;
        ayahNum = int.tryParse(parts.length > 1 ? parts[1] : '255') ?? 255;
      }

      final verseRes = await db
          .from('verses')
          .select('text_ar')
          .eq('sura_id', suraId)
          .eq('ayah_number', ayahNum)
          .maybeSingle();
      final arabic = (verseRes?['text_ar'] as String?) ?? '';

      final verseIdRes = await db
          .from('verses')
          .select('id')
          .eq('sura_id', suraId)
          .eq('ayah_number', ayahNum)
          .maybeSingle();

      String translation = '';
      if (verseIdRes != null) {
        final tid = verseIdRes['id'] as int;
        final sourceId = lang == 'en' ? 'en.sahih' : 'id.kemenag';
        final tRes = await db
            .from('translations')
            .select('text')
            .eq('verse_id', tid)
            .eq('source_id', sourceId)
            .maybeSingle();
        translation = (tRes?['text'] as String?) ?? '';
      }

      final suraRes = await db
          .from('surahs')
          .select('name_en')
          .eq('id', suraId)
          .maybeSingle();
      final sName = (suraRes?['name_en'] as String?) ?? 'Surah $suraId';
      final surahRef = '$sName: $ayahNum';

      await updateAyahWidget(
        arabic: arabic,
        translation: translation,
        surahRef: surahRef,
        surahNo: suraId,
        ayahNo: ayahNum,
      );
      debugPrint('Synced featured ayah widget: $surahRef');
    } catch (e) {
      debugPrint('Error syncing featured ayah widget: $e');
    }
  }

  /// Centralized sync of Device Location and Prayer Times to Home Widgets
  Future<void> syncDeviceLocationAndPrayerTimes({
    String calculationMethod = 'kemenag',
  }) async {
    try {
      final position = await QiblaService.getCurrentPosition();
      final cityName = await QiblaService.getCityName(position.latitude, position.longitude);
      final pt = QiblaService.getPrayerTimes(
        position.latitude,
        position.longitude,
        calculationMethod,
      );

      final formatTime = (DateTime dt) =>
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

      await updatePrayerTimesWidget(
        subuh: formatTime(pt.fajr),
        dzuhur: formatTime(pt.dhuhr),
        ashar: formatTime(pt.asr),
        maghrib: formatTime(pt.maghrib),
        isya: formatTime(pt.isha),
        nextPrayerName: pt.nextPrayerName,
        nextPrayerTime: formatTime(pt.nextPrayer == Prayer.fajr ? pt.fajr : pt.dhuhr),
        countdown: '${pt.timeUntilNext.inHours}h ${pt.timeUntilNext.inMinutes % 60}m',
        hijriDate: '14 Muharram 1447H',
        location: cityName,
      );
      debugPrint('Synced device location ($cityName) & prayer times to widget');
    } catch (e) {
      debugPrint('Error syncing device location to widget: $e');
    }
  }
}
