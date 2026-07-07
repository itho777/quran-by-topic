import 'dart:math' as math;
import 'package:flutter/material.dart';

class IslamicStar extends StatelessWidget {
  final Widget child;
  final double size;
  final Color color;
  final Color borderColor;

  const IslamicStar({
    super.key,
    required this.child,
    this.size = 32,
    required this.color,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IslamicStarPainter(
          color: color,
          borderColor: borderColor,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _IslamicStarPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _IslamicStarPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.75; // Standard Rub el Hizb ratio

    final path = Path();
    final step = math.pi / 8; // 16 points (8 outer, 8 inner)

    for (int i = 0; i < 16; i++) {
      final angle = i * step - (math.pi / 2); // Start pointing straight up
      final r = (i % 2 == 0) ? outerRadius : innerRadius;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _IslamicStarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.borderColor != borderColor;
  }
}
