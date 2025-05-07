import 'dart:ui';
import 'package:flutter/material.dart';

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(this.imageSize, this.boundingBox, this.message);

  final Size imageSize;
  late double scaleX, scaleY;
  final Rect? boundingBox;
  final String message;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.white;
    if (boundingBox != null) {
      scaleX = size.width / imageSize.width;
      scaleY = size.height / imageSize.height;
      canvas.drawRRect(
        _scaleRect(
          rect: boundingBox!,
          imageSize: imageSize,
          widgetSize: size,
          scaleX: scaleX,
          scaleY: scaleY,
        ),
        paint,
      );
      TextSpan span = TextSpan(
        style: TextStyle(color: Colors.white, fontSize: 16),
        text: message,
      );
      TextPainter textPainter = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          size.width - (200 + boundingBox!.left.toDouble()) * scaleX,
          (boundingBox!.top.toDouble() - 40) * scaleY,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.imageSize != imageSize ||
        oldDelegate.boundingBox != boundingBox;
  }
}

RRect _scaleRect({
  required Rect rect,
  required Size imageSize,
  required Size widgetSize,
  double scaleX = 1,
  double scaleY = 1,
}) {
  return RRect.fromLTRBR(
    (widgetSize.width - rect.left.toDouble() * scaleX),
    rect.top.toDouble() * scaleY,
    widgetSize.width - rect.right.toDouble() * scaleX,
    rect.bottom.toDouble() * scaleY,
    Radius.circular(12),
  );
}
