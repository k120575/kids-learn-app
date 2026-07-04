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
  _ShapePainter({
    required this.kind,
    required this.color,
    required this.filled,
  });

  final ShapeKind kind;
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    // 描邊粗細隨尺寸縮放：大圖粗、小圖細，避免小形狀被粗框糊成一團。
    final double stroke = (size.shortestSide * 0.07).clamp(3.0, 9.0);
    final Paint paint = Paint()
      ..color = filled ? color : color.withValues(alpha: 0.9)
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round;

    final Path path = _path(size, stroke);
    if (!filled) {
      // 外框模式：畫淡底 + 粗框，當作「洞」。
      final Paint bg = Paint()..color = color.withValues(alpha: 0.12);
      canvas.drawPath(path, bg);
    }
    canvas.drawPath(path, paint);
  }

  Path _path(Size size, double stroke) {
    final double w = size.width;
    final double h = size.height;
    // 內縮量隨尺寸縮放，讓外框描邊不被裁切，且小圖不會整塊糊掉。
    final double pad = stroke * 0.75 + w * 0.03;
    final Path p = Path();
    switch (kind) {
      case ShapeKind.circle:
        p.addOval(Rect.fromLTWH(pad, pad, w - 2 * pad, h - 2 * pad));
      case ShapeKind.oval:
        // 橫向橢圓，與正圓有明顯區別。
        p.addOval(Rect.fromLTWH(pad, h * 0.24, w - 2 * pad, h * 0.52));
      case ShapeKind.square:
        // 圓角隨邊長等比 → 小方形也看得出是方形（不會被圓角磨成圓點）。
        final double s = w - 2 * pad;
        p.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(pad, pad, s, h - 2 * pad),
            Radius.circular(s * 0.16),
          ),
        );
      case ShapeKind.triangle:
        p
          ..moveTo(w / 2, pad)
          ..lineTo(w - pad, h - pad)
          ..lineTo(pad, h - pad)
          ..close();
      case ShapeKind.star:
        const int points = 5;
        final double cx = w / 2;
        final double cy = h / 2;
        final double outer = w / 2 - pad;
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
