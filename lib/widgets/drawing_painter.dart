
import 'package:flutter/material.dart';

class DrawingPainter extends CustomPainter {
  final List<Rect> rectangles;
  final Map<Rect, String> rectangleFields;

  DrawingPainter(this.rectangles, this.rectangleFields);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final rect in rectangles) {
      canvas.drawRect(rect, paint);

      final field = rectangleFields[rect];
      if (field != null) {
        textPainter.text = TextSpan(
          text: field,
          style: TextStyle(color: Colors.red, fontSize: 16),
        );
        textPainter.layout();
        textPainter.paint(canvas, rect.topLeft - Offset(0, textPainter.height));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}