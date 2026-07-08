import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme.dart';
import '../../../core/local_db.dart';

// The KSU Quran page images share the same aspect ratio as the quranpedia SVG
// coordinate space (viewBox 0 0 345 550). This constant is used to calculate
// the actual rendered image bounds inside a BoxFit.contain container, so that
// click coordinates can be mapped correctly onto the SVG coordinate space.
const double _kPageAspectRatio = 345.0 / 550.0;

Widget buildQuranPageImage(
  BuildContext context,
  int pageNum, {
  VoidCallback? onTap,
  void Function(double relX, double relY)? onTapWithPosition,
  void Function(int surah, int ayah)? onVerseTapped,
  int? selectedVerseId,
  int? playingVerseId,
}) {
  return FutureBuilder<String?>(
    future: LocalDatabase.instance.getMushafPage(pageNum),
    builder: (context, snapshot) {
      final localPath = snapshot.data;
      final bool hasLocalFile = localPath != null && File(localPath).existsSync();

      return LayoutBuilder(
        builder: (ctx, constraints) {
          final containerW = constraints.maxWidth;
          final containerH = constraints.maxHeight;
          final containerRatio = containerW / containerH;

          double renderedW, renderedH, offsetX, offsetY;
          if (containerRatio > _kPageAspectRatio) {
            // Wider container → image is pillarboxed (margins on left/right)
            renderedH = containerH;
            renderedW = containerH * _kPageAspectRatio;
            offsetX = (containerW - renderedW) / 2;
            offsetY = 0.0;
          } else {
            // Taller container → image is letterboxed (margins on top/bottom)
            renderedW = containerW;
            renderedH = containerW / _kPageAspectRatio;
            offsetX = 0.0;
            offsetY = (containerH - renderedH) / 2;
          }

          return GestureDetector(
            onTapUp: (details) {
              if (onTapWithPosition != null) {
                // Map the tap to coordinates within the actual image area
                final localPos = details.localPosition;
                final imgX = localPos.dx - offsetX;
                final imgY = localPos.dy - offsetY;
                final relX = imgX / renderedW;
                final relY = imgY / renderedH;
                // Only fire if the tap is inside the actual image content (not letterbox)
                if (relX >= 0.0 && relX <= 1.0 && relY >= 0.0 && relY <= 1.0) {
                  onTapWithPosition(relX, relY);
                }
              }
              onTap?.call();
            },
            child: hasLocalFile
                ? SvgPicture.file(
                    File(localPath),
                    width: containerW,
                    height: containerH,
                    fit: BoxFit.contain,
                    placeholderBuilder: (context) => Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  )
                : Image.network(
                    'https://quran.ksu.edu.sa/png_big/$pageNum.png',
                    width: containerW,
                    height: containerH,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      );
                    },
                    errorBuilder: (c, e, s) => Center(
                      child: Text(
                        'Page $pageNum image unavailable',
                        style: TextStyle(color: AppTheme.outline),
                      ),
                    ),
                  ),
          );
        },
      );
    },
  );
}
