import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ayın en çok okuyanı için altın taç.
class CrownIcon extends StatelessWidget {
  const CrownIcon({super.key, this.size = 30, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size * 0.8), painter: _CrownPainter(color ?? AppColors.inkDeep));
}

class _CrownPainter extends CustomPainter {
  _CrownPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final body = Path()
      ..moveTo(w * 0.06, h * 0.30)
      ..lineTo(w * 0.28, h * 0.58)
      ..lineTo(w * 0.50, h * 0.14)
      ..lineTo(w * 0.72, h * 0.58)
      ..lineTo(w * 0.94, h * 0.30)
      ..lineTo(w * 0.84, h * 0.80)
      ..lineTo(w * 0.16, h * 0.80)
      ..close();
    final fill = Paint()..color = color;
    canvas.drawPath(body, fill);
    // Taban bandı
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.14, h * 0.84, w * 0.72, h * 0.14), Radius.circular(h * 0.04)),
      fill,
    );
    // Uçlardaki inciler
    for (final p in [Offset(w * 0.06, h * 0.27), Offset(w * 0.50, h * 0.10), Offset(w * 0.94, h * 0.27)]) {
      canvas.drawCircle(p, w * 0.07, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _CrownPainter old) => old.color != color;
}
