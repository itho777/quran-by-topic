import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

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

      // Trigger update for all 3 prayer time widget variations
      await HomeWidget.updateWidget(name: 'PrayerC1WidgetProvider');
      await HomeWidget.updateWidget(name: 'PrayerC2WidgetProvider');
      await HomeWidget.updateWidget(name: 'PrayerC4WidgetProvider');
      debugPrint('Updated Prayer Widget Providers (C1, C2, C4)');
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

      await HomeWidget.updateWidget(name: 'LastReadWidgetProvider');
      debugPrint('Updated LastReadWidgetProvider');
    } catch (e) {
      debugPrint('Error updating LastReadWidgetProvider: $e');
    }
  }
}
