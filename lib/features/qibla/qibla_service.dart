import 'dart:math' as math;
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';

// ─── Data classes ─────────────────────────────────────────────────────────────

class PrayerTimesResult {
  final DateTime fajr;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final Prayer nextPrayer;
  final Duration timeUntilNext;
  final String nextPrayerName;

  const PrayerTimesResult({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.nextPrayer,
    required this.timeUntilNext,
    required this.nextPrayerName,
  });

  static String prayerName(Prayer p) {
    switch (p) {
      case Prayer.fajr: return 'Fajr';
      case Prayer.sunrise: return 'Sunrise';
      case Prayer.dhuhr: return 'Dhuhr';
      case Prayer.asr: return 'Asr';
      case Prayer.maghrib: return 'Maghrib';
      case Prayer.isha: return 'Isha';
      case Prayer.none: return 'Fajr'; // past Isha → next is tomorrow's Fajr
    }
  }
}

class QiblaResult {
  /// Bearing in degrees (0–360) from user's location to the Ka'bah
  final double bearing;
  /// Distance in kilometres
  final double distanceKm;

  const QiblaResult({required this.bearing, required this.distanceKm});
}

// ─── Service ──────────────────────────────────────────────────────────────────

class QiblaService {
  // Ka'bah coordinates (Masjid al-Haram, Mecca)
  static const double _kaabahLat = 21.4225;
  static const double _kaabahLng = 39.8262;

  // ── GPS ─────────────────────────────────────────────────────────────────────

  /// Requests location permission then returns current [Position].
  /// Throws [Exception] with a user-friendly message on failure.
  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permission permanently denied. Please enable it in Settings.');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  // ── Prayer Times ─────────────────────────────────────────────────────────────

  static CalculationMethod _parseMethod(String method) {
    switch (method) {
      case 'karachi': return CalculationMethod.karachi;
      case 'isna': return CalculationMethod.north_america;
      case 'mwl': return CalculationMethod.muslim_world_league;
      case 'egyptian': return CalculationMethod.egyptian;
      case 'makkah': return CalculationMethod.umm_al_qura;
      case 'dubai': return CalculationMethod.dubai;
      case 'kuwait': return CalculationMethod.kuwait;
      case 'qatar': return CalculationMethod.qatar;
      case 'tehran': return CalculationMethod.tehran;
      case 'turkey': return CalculationMethod.turkey;
      case 'singapore':
      default:
        return CalculationMethod.singapore;
    }
  }

  /// Calculates today's prayer times using the selected calculation method.
  static PrayerTimesResult getPrayerTimes(double lat, double lng, String method) {
    final coords = Coordinates(lat, lng);
    final params = _parseMethod(method).getParameters()
      ..madhab = Madhab.shafi;

    final date = DateComponents.from(DateTime.now());
    final pt = PrayerTimes(coords, date, params);
    final now = DateTime.now();

    final nextPrayer = pt.nextPrayer();
    final nextTime = pt.timeForPrayer(nextPrayer) ?? pt.fajr;
    final until = nextTime.isAfter(now)
        ? nextTime.difference(now)
        : const Duration(hours: 0);

    return PrayerTimesResult(
      fajr: pt.fajr,
      dhuhr: pt.dhuhr,
      asr: pt.asr,
      maghrib: pt.maghrib,
      isha: pt.isha,
      nextPrayer: nextPrayer,
      timeUntilNext: until,
      nextPrayerName: PrayerTimesResult.prayerName(nextPrayer),
    );
  }

  // ── Qibla Bearing ────────────────────────────────────────────────────────────

  /// Returns [QiblaResult] with the Great Circle bearing and distance
  /// from [lat]/[lng] to the Ka'bah.
  static QiblaResult getQibla(double lat, double lng) {
    final bearing = _greatCircleBearing(lat, lng, _kaabahLat, _kaabahLng);
    final dist = _haversineKm(lat, lng, _kaabahLat, _kaabahLng);
    return QiblaResult(bearing: bearing, distanceKm: dist);
  }

  /// Spherical trig: forward azimuth (0–360° clockwise from North).
  static double _greatCircleBearing(
      double lat1, double lon1, double lat2, double lon2) {
    final latRad1 = _deg2rad(lat1);
    final latRad2 = _deg2rad(lat2);
    final dLon = _deg2rad(lon2 - lon1);

    final y = math.sin(dLon) * math.cos(latRad2);
    final x = math.cos(latRad1) * math.sin(latRad2) -
        math.sin(latRad1) * math.cos(latRad2) * math.cos(dLon);

    final theta = math.atan2(y, x);
    return (_rad2deg(theta) + 360) % 360;
  }

  /// Haversine formula for distance in km.
  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth radius km
    final latRad1 = _deg2rad(lat1);
    final latRad2 = _deg2rad(lat2);
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(latRad1) * math.cos(latRad2) * math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double deg) => deg * math.pi / 180;
  static double _rad2deg(double rad) => rad * 180 / math.pi;
}
