import 'package:flutter/material.dart';

class TimelinePainter extends CustomPainter {
  final Color morningColor;
  final Color afternoonColor;
  final Color eveningColor;
  final Color nightColor;
  final List<({DateTime timestamp, double amount, Color color, double height})> dosages;

  TimelinePainter({
    required this.morningColor,
    required this.afternoonColor,
    required this.eveningColor,
    required this.nightColor,
    required this.dosages,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // 1. Background with slightly darker tone
    final backgroundGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF1A1A1A),
        const Color(0xFF141414),
        const Color(0xFF0F0F0F),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    final backgroundRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(6),
    );
    
    paint.shader = backgroundGradient.createShader(backgroundRect.outerRect);
    canvas.drawRRect(backgroundRect, paint);
    
    // 2. Time period backgrounds with increased opacity
    final periods = [
      (start: 0.0, color: Colors.grey[900]!.withOpacity(0.12)), // Increased from 0.08
      (start: 0.25, color: Colors.grey[800]!.withOpacity(0.12)),
      (start: 0.5, color: Colors.grey[900]!.withOpacity(0.12)),
      (start: 0.75, color: Colors.grey[800]!.withOpacity(0.12)),
    ];

    for (var period in periods) {
      final rect = Rect.fromLTWH(
        period.start * size.width,
        0,
        size.width * 0.25,
        size.height * 0.8, // Reduced height to make room for labels at bottom
      );
      
      paint.color = period.color;
      canvas.drawRect(rect, paint);
    }

    // 3. Time divisions with increased visibility
    paint.shader = null;
    final dividerColor = Colors.grey[800]!.withOpacity(0.4); // Increased from 0.3
    paint.strokeWidth = 0.5;
    
    for (int hour in [6, 12, 18]) {
      final x = (hour / 24) * size.width;
      paint.color = dividerColor;
      
      double y = size.height * 0.1;
      while (y < size.height * 0.8) {
        canvas.drawCircle(Offset(x, y), 0.5, paint);
        y += 3;
      }
    }

    // 4. Time labels at bottom
    final textStyle = TextStyle(
      color: Colors.grey[600]!.withOpacity(0.8),
      fontSize: 10,
    );
    
    // 6 AM label
    final amLabel = TextPainter(
      text: TextSpan(text: '6 AM', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    
    // 6 PM label
    final pmLabel = TextPainter(
      text: TextSpan(text: '6 PM', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    
    // Position labels at bottom
    amLabel.paint(canvas, Offset(size.width * 0.25 - amLabel.width / 2, size.height - amLabel.height - 2));
    pmLabel.paint(canvas, Offset(size.width * 0.75 - pmLabel.width / 2, size.height - pmLabel.height - 2));

    // 5. Dosage visualization with increased visibility
    for (final dosage in dosages) {
      final minutes = dosage.timestamp.hour * 60 + dosage.timestamp.minute;
      final x = (minutes / (24 * 60)) * size.width;
      
      final startY = size.height * 0.8;
      final endY = startY - (dosage.height * 0.6);
      
      // Enhanced glow effect
      final glowPaint = Paint()
        ..color = dosage.color.withOpacity(0.3) // Increased from 0.2
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        glowPaint,
      );
      
      // Main line with enhanced gradient
      final lineGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          dosage.color.withOpacity(0.9), // Increased from 0.8
          dosage.color,
        ],
      );
      
      paint
        ..shader = lineGradient.createShader(
          Rect.fromPoints(Offset(x, startY), Offset(x, endY))
        )
        ..strokeWidth = 1.5
        ..maskFilter = null;
      
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        paint,
      );
    }

    // 6. Enhanced baseline
    paint.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.transparent,
        Colors.grey[700]!.withOpacity(0.4), // Increased from 0.3
        Colors.grey[700]!.withOpacity(0.4),
        Colors.transparent,
      ],
      stops: const [0.0, 0.2, 0.8, 1.0],
    ).createShader(Rect.fromLTWH(0, size.height * 0.8 - 0.5, size.width, 1));
    
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.8 - 0.5, size.width, 1),
      paint,
    );
  }

  @override
  bool shouldRepaint(TimelinePainter oldDelegate) => 
    oldDelegate.dosages != dosages;
} 