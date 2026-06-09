import 'dart:math';

import 'package:flutter/material.dart';

/// 動畫宇宙背景：漸層星空、閃爍的星星、土星環、彩色星球、月亮、飛過的火箭。
/// 給 4-5 歲「太空探險」探索地圖當沉浸式底圖。
class SpaceBackground extends StatefulWidget {
  const SpaceBackground({super.key});

  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends State<SpaceBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpacePainter(_c),
      size: Size.infinite,
    );
  }
}

class _SpacePainter extends CustomPainter {
  _SpacePainter(this.t) : super(repaint: t);
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double p = t.value;

    // 太空漸層
    final Paint bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF4527A0),
          Color(0xFF283593),
          Color(0xFF1A237E),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bg);

    // 星星（固定位置、閃爍）
    final Random rng = Random(7);
    for (int i = 0; i < 70; i++) {
      final double x = rng.nextDouble() * w;
      final double y = rng.nextDouble() * h;
      final double base = 0.6 + rng.nextDouble() * 1.6;
      final double tw = 0.4 + 0.6 * (0.5 + 0.5 * sin(p * 2 * pi + i));
      canvas.drawCircle(Offset(x, y), base,
          Paint()..color = Colors.white.withValues(alpha: tw));
    }
    // 幾顆大亮星
    for (int i = 0; i < 5; i++) {
      final double x = rng.nextDouble() * w;
      final double y = rng.nextDouble() * h * 0.7;
      _sparkle(canvas, Offset(x, y), 5 + rng.nextDouble() * 3,
          0.5 + 0.5 * sin(p * 2 * pi + i * 2));
    }

    // 月亮
    final Offset moon = Offset(w * 0.12, h * 0.22);
    canvas.drawCircle(moon, h * 0.07,
        Paint()..color = const Color(0xFFECEFF1));
    canvas.drawCircle(moon + Offset(-h * 0.02, -h * 0.015), h * 0.015,
        Paint()..color = const Color(0xFFB0BEC5));
    canvas.drawCircle(moon + Offset(h * 0.025, h * 0.02), h * 0.012,
        Paint()..color = const Color(0xFFB0BEC5));

    // 土星（含環）
    _saturn(canvas, Offset(w * 0.82, h * 0.28), h * 0.1);

    // 另一顆星球
    final Offset planet = Offset(w * 0.7, h * 0.72);
    canvas.drawCircle(planet, h * 0.06,
        Paint()..color = const Color(0xFF4DD0E1));
    canvas.drawCircle(planet + Offset(-h * 0.02, -h * 0.02), h * 0.018,
        Paint()..color = Colors.white.withValues(alpha: 0.3));

    // 火箭（飛過）
    final double rx = (p % 1) * (w + 240) - 120;
    final double ry = h * 0.55 + sin(p * 2 * pi) * 24;
    _rocket(canvas, Offset(rx, ry), h * 0.06);
  }

  void _sparkle(Canvas c, Offset o, double r, double a) {
    final Paint pnt = Paint()
      ..color = Colors.white.withValues(alpha: a.clamp(0.2, 1.0))
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    c.drawLine(o + Offset(-r, 0), o + Offset(r, 0), pnt);
    c.drawLine(o + Offset(0, -r), o + Offset(0, r), pnt);
  }

  void _saturn(Canvas c, Offset o, double r) {
    c.drawCircle(o, r, Paint()..color = const Color(0xFFFFB74D));
    c.drawCircle(o + Offset(-r * 0.3, -r * 0.3), r * 0.35,
        Paint()..color = const Color(0xFFFFE0B2).withValues(alpha: 0.5));
    // 環
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(-0.4);
    c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: r * 3.4, height: r * 1.1),
        Paint()
          ..color = const Color(0xFFFFE082)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.18);
    c.restore();
  }

  void _rocket(Canvas c, Offset o, double s) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(0.35); // 朝右上飛
    // 火焰
    final Path flame = Path()
      ..moveTo(-s * 0.5, 0)
      ..lineTo(-s * 1.2, s * 0.18)
      ..lineTo(-s * 1.2, -s * 0.18)
      ..close();
    c.drawPath(flame, Paint()..color = const Color(0xFFFF7043));
    // 機身
    final Path body = Path()
      ..moveTo(s, 0)
      ..lineTo(-s * 0.5, s * 0.3)
      ..lineTo(-s * 0.5, -s * 0.3)
      ..close();
    c.drawPath(body, Paint()..color = Colors.white);
    // 窗
    c.drawCircle(Offset(s * 0.2, 0), s * 0.14,
        Paint()..color = const Color(0xFF42A5F5));
    // 尾翼
    c.drawPath(
        Path()
          ..moveTo(-s * 0.5, s * 0.3)
          ..lineTo(-s * 0.7, s * 0.5)
          ..lineTo(-s * 0.3, s * 0.28)
          ..close(),
        Paint()..color = const Color(0xFFEF5350));
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _SpacePainter oldDelegate) => false;
}
