import 'package:flutter/material.dart';

/// A hand-drawn mushaf cartouche marker — the ornament printed in the margin
/// of a Qur'an at a Juz boundary.
///
/// Drawn as a vector path (not a bitmap) so it stays sharp at any size and
/// inherits the current theme colour. Proportions follow the classic marker:
/// width = 0.62 × height, rounded body with a pointed finial top and bottom.
///
/// The optional [label] (e.g. 'جزء') is only painted when the marker is tall
/// enough to carry it — below ~56px the glyph turns to noise, so it is
/// suppressed rather than rendered illegibly.
class JuzMarkerIcon extends StatelessWidget {
  const JuzMarkerIcon({
    super.key,
    required this.height,
    this.color,
    this.label,
    this.labelFontFamily,
  });

  /// Total height of the marker. Width is derived (0.62 × height).
  final double height;

  /// Stroke/fill colour. Defaults to the ambient [IconTheme] colour.
  final Color? color;

  /// Optional short Arabic word to centre inside the body.
  final String? label;

  /// Font family for [label]. Defaults to the platform default, which is
  /// usually all that is needed — the Arabic glyph comes from font fallback.
  final String? labelFontFamily;

  /// Below this height the label is skipped — it cannot be read anyway.
  static const double minLabelHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final resolved = color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.primary;
    final showsLabel =
        label != null && label!.isNotEmpty && height >= minLabelHeight;
    return SizedBox(
      width: height * _CartouchePainter.widthRatio,
      height: height,
      child: CustomPaint(
        painter: _CartouchePainter(
          color: resolved,
          label: showsLabel ? label : null,
          labelFontFamily: labelFontFamily,
        ),
      ),
    );
  }
}

class _CartouchePainter extends CustomPainter {
  _CartouchePainter({required this.color, this.label, this.labelFontFamily});

  final Color color;
  final String? label;
  final String? labelFontFamily;

  static const double widthRatio = 0.62;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final stroke = (w * 0.15).clamp(1.0, w);
    final bx0 = w * 0.07;
    final bx1 = w * 0.93;
    final by0 = h * 0.225;
    final by1 = h * 0.775;

    // Body
    final body = RRect.fromLTRBR(
      bx0,
      by0,
      bx1,
      by1,
      Radius.circular(w * 0.18),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // Finials — pointed caps top and bottom
    final fh = h * 0.105;
    final fx = w / 2;
    final fw = w * 0.22;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    canvas.drawPath(
      Path()
        ..moveTo(fx, by0 - fh)
        ..lineTo(fx + fw, by0)
        ..lineTo(fx - fw, by0)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(fx, by1 + fh)
        ..lineTo(fx + fw, by1)
        ..lineTo(fx - fw, by1)
        ..close(),
      fill,
    );

    final text = label;
    if (text == null) return;

    final innerW = (bx1 - bx0) - stroke * 2;
    final innerH = (by1 - by0) - stroke * 2;
    if (innerW <= 0 || innerH <= 0) return;

    var fontSize = innerH * 0.60;
    TextPainter tp;
    while (true) {
      tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            height: 1.0,
            fontFamily: labelFontFamily,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: 1,
      )..layout(maxWidth: innerW);
      final fits = tp.width <= innerW * 0.92 && tp.height <= innerH * 0.92;
      if (fits || fontSize <= 5.0) break;
      fontSize -= 0.5;
    }
    tp.paint(
      canvas,
      Offset(
        (bx0 + bx1) / 2 - tp.width / 2,
        (by0 + by1) / 2 - tp.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _CartouchePainter old) =>
      old.color != color ||
      old.label != label ||
      old.labelFontFamily != labelFontFamily;
}
