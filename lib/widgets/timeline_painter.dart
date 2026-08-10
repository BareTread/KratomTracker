import 'package:flutter/material.dart';

class TimelinePainter extends CustomPainter {
  const TimelinePainter({
    required this.backgroundColor,
    required this.bandColor,
    required this.dividerColor,
    required this.labelColor,
    required this.dosages,
  });

  final Color backgroundColor;
  final Color bandColor;
  final Color dividerColor;
  final Color labelColor;
  final List<({DateTime timestamp, double amount, Color color, double height})>
      dosages;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final background = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(6),
    );
    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [backgroundColor, backgroundColor.withValues(alpha: 0.82)],
    ).createShader(background.outerRect);
    canvas.drawRRect(background, paint);

    paint.shader = null;
    for (var i = 0; i < 4; i++) {
      if (i.isEven) continue;
      paint.color = bandColor.withValues(alpha: 0.18);
      canvas.drawRect(
        Rect.fromLTWH(i * size.width / 4, 0, size.width / 4, size.height * 0.8),
        paint,
      );
    }

    paint.color = dividerColor;
    for (final hour in [6, 12, 18]) {
      final x = hour * size.width / 24;
      for (double y = 3; y < size.height * 0.8; y += 3) {
        canvas.drawCircle(Offset(x, y), 0.5, paint);
      }
    }

    final labelStyle = TextStyle(color: labelColor, fontSize: 10);
    _paintLabel(canvas, size, '6 AM', 0.25, labelStyle);
    _paintLabel(canvas, size, '6 PM', 0.75, labelStyle);

    for (final dose in dosages) {
      final minute = dose.timestamp.hour * 60 + dose.timestamp.minute;
      final x = minute * size.width / 1440;
      final startY = size.height * 0.8;
      final endY = startY - dose.height * 0.6;
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        Paint()
          ..color = dose.color.withValues(alpha: 0.3)
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        Paint()
          ..color = dose.color
          ..strokeWidth = 1.5,
      );
    }

    paint.color = dividerColor;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.8 - 0.5, size.width, 1),
      paint,
    );
  }

  void _paintLabel(
    Canvas canvas,
    Size size,
    String text,
    double position,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        size.width * position - painter.width / 2,
        size.height - painter.height - 2,
      ),
    );
  }

  @override
  bool shouldRepaint(TimelinePainter oldDelegate) =>
      oldDelegate.dosages != dosages ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.bandColor != bandColor ||
      oldDelegate.dividerColor != dividerColor ||
      oldDelegate.labelColor != labelColor;
}
