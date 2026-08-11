import 'package:flutter/material.dart';

/// Ambient 24h dose texture. No framed panel, no fill, no hour labels — just
/// quiet ticks and dose marks drawn on the card surface itself.
class TimelinePainter extends CustomPainter {
  const TimelinePainter({
    required this.dividerColor,
    required this.dosages,
  });

  final Color dividerColor;
  final List<({DateTime timestamp, double amount, Color color, double height})>
      dosages;

  @override
  void paint(Canvas canvas, Size size) {
    final axisY = size.height - 2;
    final paint = Paint()..style = PaintingStyle.fill;

    // Soft vertical band hints at morning / afternoon / evening thirds.
    paint.color = dividerColor.withValues(alpha: 0.08);
    for (var i = 0; i < 3; i++) {
      if (i.isEven) continue;
      canvas.drawRect(
        Rect.fromLTWH(i * size.width / 3, 0, size.width / 3, axisY),
        paint,
      );
    }

    // Dotted vertical references at 6 / 12 / 18 — no labels; the ticks alone
    // read as a day and stay quieter than spelled-out hour marks.
    paint.color = dividerColor.withValues(alpha: 0.55);
    for (final hour in [6, 12, 18]) {
      final x = hour * size.width / 24;
      for (double y = 2; y < axisY - 1; y += 3.5) {
        canvas.drawCircle(Offset(x, y), 0.45, paint);
      }
    }

    for (final dose in dosages) {
      final minute = dose.timestamp.hour * 60 + dose.timestamp.minute;
      final x = minute * size.width / 1440;
      final startY = axisY;
      final endY = startY - dose.height * 0.55;
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        Paint()
          ..color = dose.color.withValues(alpha: 0.28)
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        Paint()
          ..color = dose.color.withValues(alpha: 0.85)
          ..strokeWidth = 1.5,
      );
    }

    // Hairline base edge of the card.
    paint.color = dividerColor.withValues(alpha: 0.7);
    canvas.drawRect(
      Rect.fromLTWH(0, axisY - 0.5, size.width, 1),
      paint,
    );
  }

  @override
  bool shouldRepaint(TimelinePainter oldDelegate) =>
      oldDelegate.dosages != dosages ||
      oldDelegate.dividerColor != dividerColor;
}
