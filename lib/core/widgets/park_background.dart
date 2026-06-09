import 'dart:math';

import 'package:flutter/material.dart';

/// 動畫遊樂園背景：藍天、太陽、飄動的雲、旋轉的摩天輪、馬戲團帳篷、上升的氣球。
/// 給 3-4 歲「歡樂遊樂園」探索地圖當沉浸式底圖。
class ParkBackground extends StatefulWidget {
  const ParkBackground({super.key});

  @override
  State<ParkBackground> createState() => _ParkBackgroundState();
}

class _ParkBackgroundState extends State<ParkBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParkPainter(_c),
      size: Size.infinite,
    );
  }
}

class _ParkPainter extends CustomPainter {
  _ParkPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const List<Color> _cabinColors = <Color>[
    Color(0xFFEF5350), Color(0xFFFFCA28), Color(0xFF66BB6A),
    Color(0xFF42A5F5), Color(0xFFAB47BC), Color(0xFFFF7043),
  ];
  static const List<Color> _balloonColors = <Color>[
    Color(0xFFEF5350), Color(0xFFFFEE58), Color(0xFF42A5F5),
    Color(0xFFAB47BC), Color(0xFF66BB6A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double p = t.value;

    // 天空
    final Paint sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFFB3E5FC), Color(0xFFE1F5FE)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), sky);

    // 太陽
    final Offset sun = Offset(w * 0.86, h * 0.2);
    canvas.drawCircle(sun, h * 0.13,
        Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.5));
    canvas.drawCircle(sun, h * 0.085, Paint()..color = const Color(0xFFFFD54F));

    // 雲（飄動）
    for (int i = 0; i < 3; i++) {
      final double phase = (p + i / 3) % 1;
      final double cx = phase * (w + 240) - 120;
      final double cy = h * (0.18 + i * 0.12);
      _cloud(canvas, Offset(cx, cy), h * 0.05);
    }

    // 草地
    final Paint ground = Paint()..color = const Color(0xFF9CCC65);
    final double gy = h * 0.78;
    canvas.drawRect(Rect.fromLTWH(0, gy, w, h - gy), ground);
    final Paint hill = Paint()..color = const Color(0xFF7CB342);
    canvas.drawCircle(Offset(w * 0.75, gy + h * 0.12), h * 0.18, hill);
    canvas.drawCircle(Offset(w * 0.1, gy + h * 0.14), h * 0.16, hill);

    // 馬戲團帳篷
    _tent(canvas, Offset(w * 0.62, gy), h * 0.16);

    // 摩天輪（旋轉）
    _ferrisWheel(canvas, Offset(w * 0.24, gy - h * 0.02), h * 0.26, p);

    // 氣球（上升）
    for (int i = 0; i < 5; i++) {
      final double phase = (p * 0.6 + i / 5) % 1;
      final double by = h - phase * (h + 120) + 60;
      final double bx = w * (0.12 + i * 0.18) + sin(phase * 6.28 + i) * 12;
      _balloon(canvas, Offset(bx, by), h * 0.035,
          _balloonColors[i % _balloonColors.length]);
    }
  }

  void _cloud(Canvas c, Offset o, double r) {
    final Paint pnt = Paint()..color = Colors.white.withValues(alpha: 0.9);
    c.drawCircle(o, r, pnt);
    c.drawCircle(o + Offset(r, r * 0.2), r * 0.8, pnt);
    c.drawCircle(o + Offset(-r, r * 0.2), r * 0.8, pnt);
    c.drawCircle(o + Offset(0, r * 0.4), r, pnt);
  }

  void _tent(Canvas c, Offset base, double size) {
    final double w = size * 1.6;
    // 帳身
    final Rect body = Rect.fromLTWH(base.dx - w / 2, base.dy - size, w, size);
    c.drawRect(body, Paint()..color = const Color(0xFFFFF3E0));
    // 紅白條紋屋頂
    final double rx = base.dx;
    final double ry = base.dy - size;
    final Path roof = Path()
      ..moveTo(rx - w / 2 - 8, ry)
      ..lineTo(rx + w / 2 + 8, ry)
      ..lineTo(rx, ry - size * 0.9)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFFEF5350));
    // 條紋
    final Paint stripe = Paint()..color = const Color(0xFFFFFFFF);
    for (int i = -2; i <= 2; i++) {
      final Path s = Path()
        ..moveTo(rx + i * w * 0.16, ry)
        ..lineTo(rx + i * w * 0.16 + w * 0.08, ry)
        ..lineTo(rx, ry - size * 0.9)
        ..close();
      if (i.isEven) c.drawPath(s, stripe);
    }
    // 旗子
    c.drawLine(Offset(rx, ry - size * 0.9), Offset(rx, ry - size * 1.1),
        Paint()..color = Colors.brown..strokeWidth = 2);
  }

  void _ferrisWheel(Canvas c, Offset center, double r, double p) {
    // 支架（不轉）
    final Paint leg = Paint()
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final double groundY = center.dy + r * 1.05;
    c.drawLine(center, Offset(center.dx - r * 0.5, groundY), leg);
    c.drawLine(center, Offset(center.dx + r * 0.5, groundY), leg);

    // 輪圈 + 輻條 + 車廂（轉）
    final double ang = p * 2 * pi;
    final Paint rim = Paint()
      ..color = const Color(0xFF5C6BC0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    c.drawCircle(center, r, rim);
    const int n = 8;
    for (int i = 0; i < n; i++) {
      final double a = ang + i * 2 * pi / n;
      final Offset edge = center + Offset(cos(a) * r, sin(a) * r);
      c.drawLine(center, edge,
          Paint()..color = const Color(0xFF9FA8DA)..strokeWidth = 3);
      c.drawCircle(edge, r * 0.12,
          Paint()..color = _cabinColors[i % _cabinColors.length]);
      c.drawCircle(edge, r * 0.12,
          Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    c.drawCircle(center, r * 0.08, Paint()..color = const Color(0xFF3949AB));
  }

  void _balloon(Canvas c, Offset o, double r, Color color) {
    c.drawLine(o + Offset(0, r), o + Offset(0, r * 3),
        Paint()..color = Colors.grey..strokeWidth = 1.2);
    c.drawOval(
        Rect.fromCenter(center: o, width: r * 1.7, height: r * 2.1),
        Paint()..color = color);
    c.drawCircle(o - Offset(r * 0.3, r * 0.4), r * 0.25,
        Paint()..color = Colors.white.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant _ParkPainter oldDelegate) => false;
}
