import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'qibla_providers.dart';
import '../../core/theme.dart';
import '../../core/settings_manager.dart';

class QiblaArScreen extends ConsumerStatefulWidget {
  const QiblaArScreen({super.key});

  @override
  ConsumerState<QiblaArScreen> createState() => _QiblaArScreenState();
}

class _QiblaArScreenState extends ConsumerState<QiblaArScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _permissionDenied = false;
  List<CameraDescription> _cameras = [];
  bool _hasSensorData = false;
  bool _dialogShown = false;
  StreamSubscription? _sensorCheckSub;

  @override
  void initState() {
    super.initState();
    // Lock orientation to portrait for AR consistency
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _initializeCamera();
    _startSensorCheck();
  }

  Future<void> _initializeCamera() async {
    // Request camera permission explicitly using permission_handler
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
        });
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // Find the back camera
      final backCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _sensorCheckSub?.cancel();
    // Restore orientation settings
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _cameraController?.dispose();
    super.dispose();
  }

  void _startSensorCheck() {
    final events = FlutterCompass.events;
    if (events == null) {
      _showSensorWarning();
      return;
    }

    _sensorCheckSub = events.listen(
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceContainerHigh,
          title: Row(
            children: [
              Icon(Icons.sensors_off_outlined, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text(
                isEn ? 'Hardware Sensor Required' : 'Butuh Sensor Perangkat',
                style: TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            isEn
                ? 'This device does not have a compass/magnetometer or gyroscope sensor. The AR Qibla Finder will not work properly.'
                : 'Perangkat ini tidak memiliki sensor kompas/magnetometer atau giroskop. Fitur AR Pencari Kiblat tidak akan berfungsi dengan baik.',
            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // dismiss dialog
                Navigator.of(context).pop(); // navigate back
              },
              child: Text(isEn ? 'OK' : 'Mengerti', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(settingsProvider).appLanguage == 'en';
    final compassAsync = ref.watch(compassHeadingProvider);
    final qiblaAsync = ref.watch(qiblaResultProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── CAMERA FEED BACKGROUND ───────────────────────────────────────
          if (_isCameraInitialized && _cameraController != null)
            Center(
              child: CameraPreview(_cameraController!),
            )
          else if (_permissionDenied)
            _buildPermissionDeniedView(isEn)
          else
            _buildCameraLoadingView(isEn),

          // ─── AR KA'BAH OVERLAY ───────────────────────────────────────────
          if (_isCameraInitialized)
            qiblaAsync.when(
              data: (qibla) {
                final heading = compassAsync.value ?? 0.0;
                return _buildArOverlay(context, heading, qibla.bearing, isEn);
              },
              loading: () => const SizedBox.shrink(),
              error: (err, _) => const SizedBox.shrink(),
            ),

          // ─── TOP STATUS BAR & BACK BUTTON ─────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                ClipOval(
                  child: Material(
                    color: Colors.black.withOpacity(0.5),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                // Heading Indicator Badge
                compassAsync.when(
                  data: (heading) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${heading.toStringAsFixed(0)}° ${isEn ? 'Heading' : 'Arah'}',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (err, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArOverlay(
    BuildContext context,
    double heading,
    double qiblaBearing,
    bool isEn,
  ) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;

    // Calculate angular offset (-180 to 180 degrees)
    double offset = qiblaBearing - heading;
    if (offset > 180) {
      offset -= 360;
    } else if (offset < -180) {
      offset += 360;
    }

    // Camera field of view (horizontal) is roughly 60 degrees.
    // So if the offset is between -30 and +30 degrees, it should be visible on screen.
    const fov = 60.0;
    final isVisible = offset.abs() <= (fov / 2);

    // Map offset to horizontal screen position
    // offset = 0 => center of screen (screenWidth / 2)
    // offset = -30 => left edge (0)
    // offset = +30 => right edge (screenWidth)
    final double kaabahX = (screenWidth / 2) + (offset / (fov / 2)) * (screenWidth / 2);

    // Aligned status
    final isAligned = offset.abs() < 3.0; // aligned within 3 degrees

    return Stack(
      fit: StackFit.expand,
      children: [
        // Center Target Crosshair / Guideline
        Center(
          child: Container(
            width: 2,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isAligned ? AppTheme.primary : AppTheme.secondary.withOpacity(0.5),
                  isAligned ? AppTheme.primary : AppTheme.secondary.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Ka'bah Image Object Overlay
        if (isVisible)
          Positioned(
            left: kaabahX - 100, // image width is 200
            top: (size.height / 2) - 100, // center vertically
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: isAligned
                    ? [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.6),
                          blurRadius: 30,
                          spreadRadius: 8,
                        )
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  // Animated Pointer pointing down to Ka'bah
                  if (isAligned)
                    Icon(
                      Icons.arrow_downward_rounded,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                  Expanded(
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/kaabah_overlay.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Alignment Prompt at the bottom
        Positioned(
          bottom: 48,
          left: 32,
          right: 32,
          child: Column(
            children: [
              if (isAligned) ...[
                // Success alignment banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '🕋',
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEn ? 'You are facing the Ka\'bah' : 'Anda menghadap Ka\'bah',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Direction guide arrow
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        offset > 0 ? Icons.arrow_forward : Icons.arrow_back,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        offset > 0
                            ? (isEn ? 'Turn Right' : 'Putar ke Kanan')
                            : (isEn ? 'Turn Left' : 'Putar ke Kiri'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionDeniedView(bool isEn) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              isEn ? 'Camera Permission Required' : 'Izin Kamera Dibutuhkan',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isEn
                  ? 'We need camera permission to display the live AR Ka\'bah view.'
                  : 'Kami membutuhkan akses kamera untuk menampilkan AR Ka\'bah.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
              ),
              onPressed: () {
                openAppSettings();
              },
              child: Text(isEn ? 'Open Settings' : 'Buka Pengaturan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraLoadingView(bool isEn) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 16),
          Text(
            isEn ? 'Initializing camera...' : 'Menyiapkan kamera...',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
