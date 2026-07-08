import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme.dart';
import '../../../core/local_db.dart';

// Quranpedia vector SVG base URL (same source as the web version).
const _kSvgBaseUrl =
    'https://cdn.jsdelivr.net/gh/quranpedia/quran-svg@main/mushafs/hafs/kfqc/svg';

// The quranpedia SVG pages use viewBox "0 0 345 550".
const double _kPageAspectRatio = 345.0 / 550.0;

// In-memory SVG cache so that toggling verse selection does not re-fetch.
final Map<int, String> _svgTextCache = {};

/// Fetches the raw SVG XML for [pageNum]:
///   1. Local SQLite cache → read file bytes
///   2. In-memory network cache
///   3. Remote quranpedia CDN
Future<String> _loadSvgText(int pageNum) async {
  // 1. Local file cached by the Library download manager
  final localPath = await LocalDatabase.instance.getMushafPage(pageNum);
  if (localPath != null && File(localPath).existsSync()) {
    return File(localPath).readAsString();
  }

  // 2. In-memory cache (avoids re-downloading on rebuild)
  if (_svgTextCache.containsKey(pageNum)) {
    return _svgTextCache[pageNum]!;
  }

  // 3. Network fetch
  final paddedPage = pageNum.toString().padLeft(3, '0');
  final url = '$_kSvgBaseUrl/$paddedPage.svg';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final text = response.body;
    _svgTextCache[pageNum] = text;
    return text;
  }
  throw Exception('Failed to load SVG for page $pageNum (HTTP ${response.statusCode})');
}

/// Injects a CSS <style> block into the SVG XML to highlight the selected
/// and playing verses by their `id="verse-N"` attribute.
String _applyVerseStyles(String svgText, int? selectedId, int? playingId) {
  // Build the style block
  final selectedCss = selectedId != null
      ? '#verse-$selectedId { fill: #E9C176 !important; fill-opacity: 0.25 !important; }'
      : '';
  final playingCss = playingId != null
      ? '#verse-$playingId { fill: #95D1D1 !important; fill-opacity: 0.30 !important; }'
      : '';

  final styleBlock = '''
<style>
  .ayahPolygon { fill: #000000; fill-opacity: 0; }
  $selectedCss
  $playingCss
</style>''';

  // Insert right before </svg> so it takes highest specificity
  final idx = svgText.lastIndexOf('</svg>');
  if (idx != -1) {
    return svgText.substring(0, idx) + styleBlock + svgText.substring(idx);
  }
  return svgText;
}

/// Builds the Quran page widget for native (Android/iOS/desktop) targets.
///
/// Loads a vector SVG from the local cache (downloaded via Library) or
/// directly from the quranpedia CDN, then injects dynamic CSS to highlight
/// the selected and playing verses.
///
/// [fullWidth] — when true the page fills the container width and may extend
/// beyond the visible height (user can pan/zoom). When false (default) the
/// entire page fits inside the container with letterboxing.
Widget buildQuranPageImage(
  BuildContext context,
  int pageNum, {
  VoidCallback? onTap,
  void Function(double relX, double relY)? onTapWithPosition,
  void Function(int surah, int ayah)? onVerseTapped,
  int? selectedVerseId,
  int? playingVerseId,
  bool fullWidth = false,
}) {
  return FutureBuilder<String>(
    future: _loadSvgText(pageNum),
    builder: (context, snapshot) {
      return LayoutBuilder(
        builder: (ctx, constraints) {
          final containerW = constraints.maxWidth;
          final containerH = constraints.maxHeight;

          double renderedW, renderedH, offsetX, offsetY;

          if (fullWidth) {
            // ── Full-width mode ──────────────────────────────────────────────
            // Page spans the full container width; height scales proportionally.
            renderedW = containerW;
            renderedH = containerW / _kPageAspectRatio;
            offsetX = 0.0;
            offsetY = 0.0;
          } else {
            // ── Fit-page mode (BoxFit.contain) ──────────────────────────────
            final containerRatio = containerW / containerH;
            if (containerRatio > _kPageAspectRatio) {
              // Wider container → pillarboxed (margins left/right)
              renderedH = containerH;
              renderedW = containerH * _kPageAspectRatio;
              offsetX = (containerW - renderedW) / 2;
              offsetY = 0.0;
            } else {
              // Taller container → letterboxed (margins top/bottom)
              renderedW = containerW;
              renderedH = containerW / _kPageAspectRatio;
              offsetX = 0.0;
              offsetY = (containerH - renderedH) / 2;
            }
          }

          // ── Content ────────────────────────────────────────────────────────
          Widget pageContent;

          if (snapshot.connectionState == ConnectionState.waiting) {
            // Loading skeleton
            pageContent = Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          } else if (snapshot.hasError) {
            // Offline and not cached
            pageContent = Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_outlined, color: AppTheme.outline, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      'Page $pageNum not available offline.\nDownload it in the Library.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.outline, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Inject dynamic verse highlight styles, then render SVG
            final styledSvg = _applyVerseStyles(
              snapshot.data!,
              selectedVerseId,
              playingVerseId,
            );
            pageContent = SvgPicture.string(
              styledSvg,
              width: renderedW,
              height: renderedH,
              fit: BoxFit.fill, // We already calculated the exact size above
              placeholderBuilder: (_) =>
                  Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            );
          }

          return GestureDetector(
            onTapUp: (details) {
              if (onTapWithPosition != null) {
                final localPos = details.localPosition;
                final imgX = localPos.dx - offsetX;
                final imgY = localPos.dy - offsetY;
                final relX = imgX / renderedW;
                final relY = imgY / renderedH;
                // Only fire if the tap is inside the actual image area
                if (relX >= 0.0 && relX <= 1.0 && relY >= 0.0 && relY <= 1.0) {
                  onTapWithPosition(relX, relY);
                }
              }
              onTap?.call();
            },
            child: SizedBox(
              width: containerW,
              height: fullWidth ? renderedH : containerH,
              child: Stack(
                children: [
                  Positioned(
                    left: offsetX,
                    top: offsetY,
                    child: pageContent,
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
