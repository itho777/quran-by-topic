import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quran_library/quran_library.dart';

/// Renders a Mushaf page using the QPC Tajweed font engine (Android/iOS only).
/// On web, returns a SizedBox.shrink() — web falls back to SVG CDN rendering.
class TajweedPageWidget extends StatelessWidget {
  final int pageNumber;
  final bool isDark;

  const TajweedPageWidget({
    super.key,
    required this.pageNumber,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return QuranPagesScreen(
      isDark: isDark,
      startPage: pageNumber,
      endPage: pageNumber,
      parentContext: context,
    );
  }
}
