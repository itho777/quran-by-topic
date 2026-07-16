import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme.dart';
import '../../core/settings_manager.dart';
import 'qibla_providers.dart';
import 'qibla_service.dart';

class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> with SingleTickerProviderStateMixin {
  late AnimationController _compassAnimController;
  double _lastHeading = 0.0;
  bool _hasSensorData = false;
  bool _dialogShown = false;
  StreamSubscription? _sensorCheckSub;

  @override
  void initState() {
    super.initState();
    _compassAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _startSensorCheck();
  }

  void _startSensorCheck() {
    // Listen to compass events. If no event is received within 2 seconds,
    // or if heading is null/invalid, show a SnackBar.
    _sensorCheckSub = FlutterCompass.events?.listen(
      (event) {
        if (event.heading != null) {
          _hasSensorData = true;
        }
      },
      onError: (_) {
        _showSensorWarning();
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!_hasSensorData && mounted && !_dialogShown) {
        _showSensorWarning();
      }
    });
  }

  void _showSensorWarning() {
    if (!mounted) return;
    _dialogShown = true;
    final isEn = ref.read(settingsProvider).appLanguage == 'en';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEn
              ? 'To use this feature properly your device needs to have compass & gyroscope sensors'
              : 'Untuk menggunakan fitur ini dengan baik, perangkat Anda harus memiliki sensor kompas & giroskop',
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _sensorCheckSub?.cancel();
    _compassAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(currentLocationProvider);
    final isEn = ref.watch(settingsProvider).appLanguage == 'en';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        title: Text(
          isEn ? 'Qibla & Prayer Times' : 'Kiblat & Waktu Shalat',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: locationAsync.when(
        data: (position) => _buildContent(context, position, isEn),
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                isEn ? 'Acquiring GPS location...' : 'Mencari lokasi GPS...',
                style: TextStyle(color: AppTheme.outline, fontSize: 14),
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off_outlined, size: 64, color: AppTheme.primary),
                const SizedBox(height: 16),
                Text(
                  isEn ? 'Location Access Required' : 'Akses Lokasi Dibutuhkan',
                  style: TextStyle(
                    color: AppTheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString().replaceAll('Exception:', '').trim(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.outline, fontSize: 14),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onPrimary,
                  ),
                  onPressed: () {
                    ref.invalidate(currentLocationProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(isEn ? 'Retry' : 'Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Position position, bool isEn) {
    final qiblaAsync = ref.watch(qiblaResultProvider);
    final prayerTimesAsync = ref.watch(prayerTimesProvider);
    final compassAsync = ref.watch(compassHeadingProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentLocationProvider);
        ref.invalidate(qiblaResultProvider);
        ref.invalidate(prayerTimesProvider);
      },
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ─── PRAYER TIMES CARD ─────────────────────────────────────────────
          prayerTimesAsync.when(
            data: (pt) => _buildPrayerTimesCard(pt, isEn),
            loading: () => Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            ),
            error: (err, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Error loading prayer times: $err',
                style: TextStyle(color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── QIBLA COMPASS CARD ───────────────────────────────────────────
          qiblaAsync.when(
            data: (qibla) {
              final heading = compassAsync.value ?? 0.0;
              // Smooth compass rotation logic
              double diff = heading - _lastHeading;
              if (diff < -180.0) {
                _lastHeading -= 360.0;
              } else if (diff > 180.0) {
                _lastHeading += 360.0;
              }
              _lastHeading = heading;

              return Card(
                color: AppTheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppTheme.outlineVariant.withValues(alpha: 0.15),
                  ),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                  child: Column(
                    children: [
                      Text(
                        isEn ? 'Qibla Direction' : 'Arah Kiblat',
                        style: TextStyle(
                          color: AppTheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${qibla.bearing.toStringAsFixed(1)}° NW  •  ${qibla.distanceKm.toStringAsFixed(0)} km',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Circular Compass Widget
                      SizedBox(
                        height: 220,
                        width: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer rotating compass dial
                            AnimatedRotation(
                              turns: -heading / 360.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              child: CustomPaint(
                                size: const Size(220, 220),
                                painter: CompassDialPainter(
                                  qiblaBearing: qibla.bearing,
                                  accentColor: AppTheme.primary,
                                  outlineColor: AppTheme.outline,
                                ),
                              ),
                            ),
                            // Fixed top alignment indicator (Device orientation)
                            Positioned(
                              top: 0,
                              child: Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 36,
                                color: AppTheme.secondary,
                              ),
                            ),
                            // Center Ka'bah Icon
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primary.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '🕋',
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // AR View Launch Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: AppTheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            context.push('/qibla/ar');
                          },
                          icon: const Text('🕋', style: TextStyle(fontSize: 16)),
                          label: Text(
                            isEn ? 'Open AR Ka\'bah View' : 'Buka AR Tampilan Ka\'bah',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => Container(
              height: 300,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            ),
            error: (err, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('Error: $err'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPrayerTimesCard(PrayerTimesResult pt, bool isEn) {
    String formatTime(DateTime dt) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    String countdownStr(Duration d) {
      final hrs = d.inHours;
      final mins = d.inMinutes.remainder(60);
      if (isEn) {
        if (hrs > 0) {
          return 'in $hrs hr $mins min';
        }
        return 'in $mins min';
      } else {
        if (hrs > 0) {
          return 'dalam $hrs jam $mins menit';
        }
        return 'dalam $mins menit';
      }
    }

    final settings = ref.watch(settingsProvider);

    final hijri = HijriCalendar.now();
    final hijriStr = isEn
        ? '${hijri.hDay} ${hijri.getLongMonthName()} ${hijri.hYear} AH'
        : '${hijri.hDay} ${hijri.getLongMonthName()} ${hijri.hYear} H';

    final pTimes = [
      if (settings.enableFirstAdzan)
        {
          'name': isEn ? 'First Adzan' : 'Adzan Awal',
          'time': pt.firstAdzan,
          'key': 'firstadzan'
        },
      {'name': 'Subuh (Fajr)', 'time': pt.fajr, 'key': 'fajr'},
      {'name': 'Syuruq (Sunrise)', 'time': pt.sunrise, 'key': 'sunrise'},
      {'name': 'Dhuha', 'time': pt.dhuha, 'key': 'dhuha'},
      {'name': 'Dzuhur (Dhuhr)', 'time': pt.dhuhr, 'key': 'dhuhr'},
      {'name': 'Ashar (Asr)', 'time': pt.asr, 'key': 'asr'},
      {'name': 'Maghrib', 'time': pt.maghrib, 'key': 'maghrib'},
      {'name': 'Isya (Isha)', 'time': pt.isha, 'key': 'isha'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEn ? 'Prayer Schedule' : 'Jadwal Shalat Hari Ini',
                style: TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                hijriStr,
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isEn
                ? 'Next: ${pt.nextPrayerName} ${countdownStr(pt.timeUntilNext)}'
                : 'Berikutnya: ${pt.nextPrayerName} ${countdownStr(pt.timeUntilNext)}',
            style: TextStyle(
              color: AppTheme.secondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Divider(height: 24),
          Column(
            children: pTimes.map((item) {
              final String key = item['key'] as String;
              final DateTime time = item['time'] as DateTime;
              final String name = item['name'] as String;
              final isNext = pt.nextPrayerName.toLowerCase() == key ||
                  (key == 'sunrise' && pt.nextPrayerName == 'Syuruq');

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isNext
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isNext
                      ? Border.all(color: AppTheme.primary.withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isNext ? Icons.notifications_active : Icons.notifications_none,
                          color: isNext ? AppTheme.primary : AppTheme.outline,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          name,
                          style: TextStyle(
                            color: isNext ? AppTheme.primary : AppTheme.onSurface,
                            fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      formatTime(time),
                      style: TextStyle(
                        color: isNext ? AppTheme.primary : AppTheme.onSurface,
                        fontWeight: isNext ? FontWeight.bold : FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class CompassDialPainter extends CustomPainter {
  final double qiblaBearing;
  final Color accentColor;
  final Color outlineColor;

  CompassDialPainter({
    required this.qiblaBearing,
    required this.accentColor,
    required this.outlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final dialPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final circlePaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius, dialPaint);
    canvas.drawCircle(center, radius, circlePaint);

    // Draw Cardinal ticks and letters
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final cardinals = {
      0.0: 'N',
      90.0: 'E',
      180.0: 'S',
      270.0: 'W',
    };

    for (var angle in cardinals.keys) {
      final rad = (angle - 90.0) * math.pi / 180.0;
      final text = cardinals[angle]!;

      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: text == 'N' ? Colors.red : outlineColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();

      final x = center.dx + (radius - 20) * math.cos(rad) - textPainter.width / 2;
      final y = center.dy + (radius - 20) * math.sin(rad) - textPainter.height / 2;

      textPainter.paint(canvas, Offset(x, y));
    }

    // Draw minor ticks
    final tickPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    for (var i = 0; i < 360; i += 15) {
      if (i % 90 == 0) continue; // skip cardinal points
      final rad = (i - 90.0) * math.pi / 180.0;
      final innerRadius = radius - 8;
      final outerRadius = radius;

      final p1 = Offset(
        center.dx + innerRadius * math.cos(rad),
        center.dy + innerRadius * math.sin(rad),
      );
      final p2 = Offset(
        center.dx + outerRadius * math.cos(rad),
        center.dy + outerRadius * math.sin(rad),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Draw Qibla pointer line & Ka'bah direction arrow
    final qiblaRad = (qiblaBearing - 90.0) * math.pi / 180.0;
    
    // Line from center to edge pointing to Ka'bah
    final linePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    final endPoint = Offset(
      center.dx + (radius - 35) * math.cos(qiblaRad),
      center.dy + (radius - 35) * math.sin(qiblaRad),
    );
    canvas.drawLine(center, endPoint, linePaint);

    // Beautiful indicator at the edge for Qibla
    final qiblaIndicatorPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final path = Path();
    // Triangular needle pointing outward
    final pArrow = Offset(
      center.dx + (radius - 12) * math.cos(qiblaRad),
      center.dy + (radius - 12) * math.sin(qiblaRad),
    );
    final pLeft = Offset(
      center.dx + (radius - 28) * math.cos(qiblaRad - 0.12),
      center.dy + (radius - 28) * math.sin(qiblaRad - 0.12),
    );
    final pRight = Offset(
      center.dx + (radius - 28) * math.cos(qiblaRad + 0.12),
      center.dy + (radius - 28) * math.sin(qiblaRad + 0.12),
    );

    path.moveTo(pArrow.dx, pArrow.dy);
    path.lineTo(pLeft.dx, pLeft.dy);
    path.lineTo(pRight.dx, pRight.dy);
    path.close();

    canvas.drawPath(path, qiblaIndicatorPaint);
  }

  @override
  bool shouldRepaint(covariant CompassDialPainter oldDelegate) {
    return oldDelegate.qiblaBearing != qiblaBearing ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.outlineColor != outlineColor;
  }
}
