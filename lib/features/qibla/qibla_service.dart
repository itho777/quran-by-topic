import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';

// ─── Data classes ─────────────────────────────────────────────────────────────

class PrayerTimesResult {
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuha;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final DateTime firstAdzan;
  final Prayer nextPrayer;
  final Duration timeUntilNext;
  final String nextPrayerName;

  const PrayerTimesResult({
    required this.fajr,
    required this.sunrise,
    required this.dhuha,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.firstAdzan,
    required this.nextPrayer,
    required this.timeUntilNext,
    required this.nextPrayerName,
  });

  static String prayerName(Prayer p) {
    switch (p) {
      case Prayer.fajr: return 'Fajr';
      case Prayer.sunrise: return 'Syuruq';
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

  /// Reverse geocode city/district name from latitude and longitude.
  static Future<String> getCityName(double lat, double lng) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=10');
      final req = await http.get(uri, headers: {'User-Agent': 'TafseerApp/1.0'});
      if (req.statusCode == 200) {
        final data = req.body;
        // Parse city/town/county/state
        if (data.contains('"city":')) {
          final match = RegExp(r'"city":\s*"([^"]+)"').firstMatch(data);
          if (match != null) return match.group(1)!;
        }
        if (data.contains('"town":')) {
          final match = RegExp(r'"town":\s*"([^"]+)"').firstMatch(data);
          if (match != null) return match.group(1)!;
        }
        if (data.contains('"county":')) {
          final match = RegExp(r'"county":\s*"([^"]+)"').firstMatch(data);
          if (match != null) return match.group(1)!;
        }
        if (data.contains('"state":')) {
          final match = RegExp(r'"state":\s*"([^"]+)"').firstMatch(data);
          if (match != null) return match.group(1)!;
        }
      }
    } catch (_) {}
    return 'Jakarta';
  }

  // ── Prayer Times ─────────────────────────────────────────────────────────────

  static CalculationParameters _getParams(String method) {
    CalculationParameters params;
    switch (method) {
      case 'kemenag':
        params = CalculationParameters(fajrAngle: 20.0, ishaAngle: 18.0);
        break;
      case 'singapore':
        params = CalculationMethod.singapore.getParameters();
        break;
      case 'karachi':
        params = CalculationMethod.karachi.getParameters();
        break;
      case 'isna':
        params = CalculationMethod.north_america.getParameters();
        break;
      case 'mwl':
        params = CalculationMethod.muslim_world_league.getParameters();
        break;
      case 'egyptian':
        params = CalculationMethod.egyptian.getParameters();
        break;
      case 'makkah':
        params = CalculationMethod.umm_al_qura.getParameters();
        break;
      case 'turkey':
        params = CalculationMethod.turkey.getParameters();
        break;
      case 'tehran':
        params = CalculationMethod.tehran.getParameters();
        break;
      default:
        params = CalculationMethod.singapore.getParameters();
        break;
    }
    params.madhab = Madhab.shafi;
    return params;
  }

  /// Calculates today's prayer times using the selected calculation method.
  static PrayerTimesResult getPrayerTimes(
    double lat,
    double lng,
    String method, {
    DateTime? date,
    int fajrOffset = 0,
    int sunriseOffset = 0,
    int dhuhrOffset = 0,
    int asrOffset = 0,
    int maghribOffset = 0,
    int ishaOffset = 0,
    int firstAdzanOffset = 60,
  }) {
    final coords = Coordinates(lat, lng);
    final params = _getParams(method);

    final targetDate = date ?? DateTime.now();
    final dateComponents = DateComponents.from(targetDate);
    final pt = PrayerTimes(coords, dateComponents, params);
    final now = DateTime.now();

    // Apply manual adjustments (offsets in minutes)
    final fajr = pt.fajr.add(Duration(minutes: fajrOffset));
    final sunrise = pt.sunrise.add(Duration(minutes: sunriseOffset));
    final dhuhr = pt.dhuhr.add(Duration(minutes: dhuhrOffset));
    final asr = pt.asr.add(Duration(minutes: asrOffset));
    final maghrib = pt.maghrib.add(Duration(minutes: maghribOffset));
    final isha = pt.isha.add(Duration(minutes: ishaOffset));
    
    // Dhuha starts 20 mins after sunrise/syuruq
    final dhuha = sunrise.add(const Duration(minutes: 20));

    // First Adzan is firstAdzanOffset minutes before fajr
    final firstAdzan = fajr.subtract(Duration(minutes: firstAdzanOffset));

    // Determine the next prayer using adjusted times
    Prayer nextPrayer = Prayer.none;
    DateTime nextTime;

    if (fajr.isAfter(now)) {
      nextPrayer = Prayer.fajr;
      nextTime = fajr;
    } else if (sunrise.isAfter(now)) {
      nextPrayer = Prayer.sunrise;
      nextTime = sunrise;
    } else if (dhuhr.isAfter(now)) {
      nextPrayer = Prayer.dhuhr;
      nextTime = dhuhr;
    } else if (asr.isAfter(now)) {
      nextPrayer = Prayer.asr;
      nextTime = asr;
    } else if (maghrib.isAfter(now)) {
      nextPrayer = Prayer.maghrib;
      nextTime = maghrib;
    } else if (isha.isAfter(now)) {
      nextPrayer = Prayer.isha;
      nextTime = isha;
    } else {
      // Past Isha: next is tomorrow's Fajr
      nextPrayer = Prayer.fajr;
      final tomorrowDate = DateComponents.from(DateTime.now().add(const Duration(days: 1)));
      final tomorrowPt = PrayerTimes(coords, tomorrowDate, params);
      nextTime = tomorrowPt.fajr.add(Duration(minutes: fajrOffset));
    }

    final until = nextTime.isAfter(now)
        ? nextTime.difference(now)
        : const Duration(hours: 0);

    return PrayerTimesResult(
      fajr: fajr,
      sunrise: sunrise,
      dhuha: dhuha,
      dhuhr: dhuhr,
      asr: asr,
      maghrib: maghrib,
      isha: isha,
      firstAdzan: firstAdzan,
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
