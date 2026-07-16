import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/settings_manager.dart';
import '../../core/alarm_service.dart';
import 'qibla_service.dart';

/// Provider for streaming the current phone heading from the magnetometer.
/// Emits values between 0.0 and 360.0 (degrees from North).
final compassHeadingProvider = StreamProvider<double>((ref) {
  final events = FlutterCompass.events;
  if (events == null) {
    return Stream.value(0.0);
  }
  return events.map((event) {
    // If heading is null, default to 0.0. Ensure we normalize it.
    final heading = event.heading ?? 0.0;
    return (heading + 360.0) % 360.0;
  });
});

/// Provider for one-time geolocation fetch, returning [latitude, longitude].
final currentLocationProvider = FutureProvider<Position>((ref) async {
  return await QiblaService.getCurrentPosition();
});

/// Provider for Qibla calculation results based on current GPS location.
final qiblaResultProvider = FutureProvider<QiblaResult>((ref) async {
  final position = await ref.watch(currentLocationProvider.future);
  return QiblaService.getQibla(position.latitude, position.longitude);
});

/// Provider for daily prayer times based on current GPS location.
final prayerTimesProvider = FutureProvider<PrayerTimesResult>((ref) async {
  final position = await ref.watch(currentLocationProvider.future);
  final settings = ref.watch(settingsProvider);
  final pt = QiblaService.getPrayerTimes(
    position.latitude,
    position.longitude,
    settings.prayerCalculationMethod,
    fajrOffset: settings.fajrOffset,
    sunriseOffset: settings.sunriseOffset,
    dhuhrOffset: settings.dhuhrOffset,
    asrOffset: settings.asrOffset,
    maghribOffset: settings.maghribOffset,
    ishaOffset: settings.ishaOffset,
    firstAdzanOffset: settings.firstAdzanOffset,
  );

  // Schedule local notification alarms asynchronously
  AlarmService.instance.schedulePrayerAlarms(
    latitude: position.latitude,
    longitude: position.longitude,
    settings: settings,
  );

  return pt;
});
