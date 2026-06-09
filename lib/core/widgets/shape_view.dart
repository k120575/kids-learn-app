import 'dart:math';

import 'package:flutter/material.dart';

enum ShapeKind { circle, oval, square, triangle, star }

const Map<ShapeKind, String> shapeNames = <ShapeKind, String>{
  ShapeKind.circle: '圓形',
  ShapeKind.oval: '橢圓形',
  ShapeKind.square: '正方形',
  ShapeKind.triangle: '三角形',
  ShapeKind.star: '星形',
};

/// 用向量繪製基本形狀（圓/方/三角/星），可填色或只畫外框。
/// 不需任何圖片素材。
class ShapeView extends StatelessWidget {
  const ShapeView({
    super.key,
    required this.kind,
    required this.color,
    this.size = 110,
    this.filled = true,
  });

  final ShapeKind kind;
  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ShapePainter(kind: kind, color: color, filled: filled),
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter({required this.kind, required this.color, required this.filled});

  final ShapeKind kind;
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = filled ? color : color.withValues(alpha: 0.9)
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeJoin = StrokeJoin.round;

    final Path path = _path(size);
    if (!filled) {
      // 外框模式：畫淡底 + 粗框，當作「洞」。
      final Paint bg = Paint()..color = color.withValues(alpha: 0.12);
      canvas.drawPath(path, bg);
    }
    canvas.drawPath(path, paint);
  }

  Path _path(Size size) {
    final double w = size.width;
    final double h = size.height;
    final Path p = Path();
    switch (kind) {
      case ShapeKind.circle:
        p.addOval(Rect.fromLTWH(6, 6, w - 12, h - 12));
      case ShapeKind.oval:
        // 橫向橢圓，與正圓有明顯區別。
        p.addOval(Rect.fromLTWH(2, h * 0.24, w - 4, h * 0.52));
      case ShapeKind.square:
        p.addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(8, 8, w - 16, h - 16), const Radius.circular(10)));
      case ShapeKind.triangle:
        p
          ..moveTo(w / 2, 8)
          ..lineTo(w - 8, h - 10)
          ..lineTo(8, h - 10)
          ..close();
      case ShapeKind.star:
        const int points = 5;
        final double cx = w / 2;
        final double cy = h / 2;
        final double outer = w / 2 - 6;
        final double inner = outer * 0.42;
        for (int i = 0; i < points * 2; i++) {
          final double r = i.isEven ? outer : inner;
          final double a = -pi / 2 + i * pi / points;
          final double x = cx + r * cos(a);
          final double y = cy + r * sin(a);
          if (i == 0) {
            p.moveTo(x, y);
          } else {
            p.lineTo(x, y);
          }
        }
        p.close();
    }
    return p;
  }

  @override
  bool shouldRepaint(covariant _ShapePainter old) =>
      old.kind != kind || old.color != color || old.filled != filled;
}
