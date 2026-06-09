import 'dart:math';

import 'package:flutter/material.dart';

/// 動畫魔法學院背景：深紫夜空、大圓月與光暈、閃爍星塵、霍格華茲式城堡剪影
/// （高低錯落的尖塔＋暖黃燈窗）、飄浮的魔法燭光，以及一位騎掃帚飛過月亮的小魔法師。
/// 給 5-6 歲「魔法學院」探索地圖當沉浸式底圖。
class MagicBackground extends StatefulWidget {
  const MagicBackground({super.key});

  @override
  State<MagicBackground> createState() => _MagicBackgroundState();
}

class _MagicBackgroundState extends State<MagicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MagicPainter(_c), size: Size.infinite);
  }
}

class _MagicPainter extends CustomPainter {
  _MagicPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const Color _castle = Color(0xFF130A2E);
  static const Color _castleFront = Color(0xFF1C0F3F);
  static const Color _win = Color(0xFFFFD54F);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double p = t.value;

    // 夜空漸層
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF3A2A86),
            Color(0xFF2A1C66),
            Color(0xFF150C38),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // 大圓月＋光暈（城堡後方）
    final Offset moon = Offset(w * 0.74, h * 0.26);
    final double mr = h * 0.13;
    canvas.drawCircle(
      moon,
      mr * 1.9,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFFF9C4).withValues(alpha: 0.35),
            const Color(0xFFFFF9C4).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: moon, radius: mr * 1.9)),
    );
    canvas.drawCircle(moon, mr, Paint()..color = const Color(0xFFFFF6D5));
    // 月面陰影紋理
    canvas.drawCircle(moon + Offset(-mr * 0.3, -mr * 0.25), mr * 0.16,
        Paint()..color = const Color(0xFFEFE3A8).withValues(alpha: 0.6));
    canvas.drawCircle(moon + Offset(mr * 0.35, mr * 0.2), mr * 0.12,
        Paint()..color = const Color(0xFFEFE3A8).withValues(alpha: 0.5));

    // 星塵（固定位置、閃爍）
    final Random rng = Random(21);
    for (int i = 0; i < 90; i++) {
      final double x = rng.nextDouble() * w;
      final double y = rng.nextDouble() * h * 0.85;
      final double base = 0.5 + rng.nextDouble() * 1.4;
      final double tw = 0.25 + 0.75 * (0.5 + 0.5 * sin(p * 2 * pi + i));
      canvas.drawCircle(Offset(x, y), base,
          Paint()..color = Colors.white.withValues(alpha: tw));
    }
    // 幾顆大亮星（十字芒）
    for (int i = 0; i < 5; i++) {
      final double x = rng.nextDouble() * w;
      final double y = rng.nextDouble() * h * 0.5;
      _sparkle(canvas, Offset(x, y), 6 + rng.nextDouble() * 3,
          0.4 + 0.6 * sin(p * 2 * pi + i * 1.7), const Color(0xFFE1BEE7));
    }

    // 騎掃帚的小魔法師（橫越月亮、輕微上下擺動）
    final double bx = (p % 1) * (w + 260) - 130;
    final double by = h * 0.30 + sin(p * 2 * pi) * 22;
    _broomRider(canvas, Offset(bx, by), h * 0.05, p);

    // 城堡剪影
    _castleScene(canvas, w, h, rng);

    // 飄浮魔法燭光（暖黃、緩慢上浮）
    for (int i = 0; i < 6; i++) {
      final double cx = w * (0.08 + i * 0.16);
      final double drift = (p + i * 0.17) % 1.0;
      final double cy = h * 0.86 - drift * h * 0.42;
      final double a = sin(drift * pi).clamp(0.0, 1.0) * 0.9;
      _candle(canvas, Offset(cx, cy), 3.2 + (i % 3), a);
    }
  }

  void _sparkle(Canvas c, Offset o, double r, double a, Color color) {
    final Paint pnt = Paint()
      ..color = color.withValues(alpha: a.clamp(0.15, 1.0))
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    c.drawLine(o + Offset(-r, 0), o + Offset(r, 0), pnt);
    c.drawLine(o + Offset(0, -r), o + Offset(0, r), pnt);
    c.drawLine(o + Offset(-r * 0.55, -r * 0.55), o + Offset(r * 0.55, r * 0.55),
        pnt..strokeWidth = 1.0);
    c.drawLine(o + Offset(-r * 0.55, r * 0.55), o + Offset(r * 0.55, -r * 0.55),
        pnt);
  }

  void _candle(Canvas c, Offset o, double r, double a) {
    c.drawCircle(
        o,
        r * 2.4,
        Paint()
          ..color = const Color(0xFFFFE082).withValues(alpha: a * 0.25));
    c.drawCircle(
        o, r, Paint()..color = const Color(0xFFFFF3C0).withValues(alpha: a));
  }

  /// 騎掃帚飛行的小魔法師剪影（尖帽＋斗篷＋掃帚與飄動鬚毛）。
  void _broomRider(Canvas c, Offset o, double s, double p) {
    final Paint dark = Paint()..color = const Color(0xFF0E0726);
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(-0.12);
    // 掃帚桿
    c.drawLine(Offset(-s * 1.6, s * 0.2), Offset(s * 1.4, -s * 0.1),
        Paint()
          ..color = const Color(0xFF5D4037)
          ..strokeWidth = s * 0.16
          ..strokeCap = StrokeCap.round);
    // 掃帚鬚毛（後方扇形，輕微擺動）
    final double sway = sin(p * 2 * pi * 4) * s * 0.1;
    final Paint br = Paint()
      ..color = const Color(0xFFC9A227)
      ..strokeWidth = s * 0.06
      ..strokeCap = StrokeCap.round;
    for (int i = -3; i <= 3; i++) {
      c.drawLine(Offset(-s * 1.4, s * 0.15),
          Offset(-s * 2.4, s * 0.15 + i * s * 0.12 + sway), br);
    }
    // 斗篷飄動
    final Path cape = Path()
      ..moveTo(0, -s * 0.2)
      ..quadraticBezierTo(-s * 1.2, s * 0.1 + sway, -s * 1.5, s * 0.7 + sway)
      ..quadraticBezierTo(-s * 0.6, s * 0.2, 0, s * 0.4)
      ..close();
    c.drawPath(cape, Paint()..color = const Color(0xFF4527A0));
    // 身體
    c.drawCircle(Offset(0, -s * 0.1), s * 0.42, dark);
    // 頭
    c.drawCircle(Offset(s * 0.15, -s * 0.7), s * 0.3, dark);
    // 尖帽
    final Path hat = Path()
      ..moveTo(s * 0.15 - s * 0.45, -s * 0.95)
      ..lineTo(s * 0.55, -s * 1.9)
      ..lineTo(s * 0.15 + s * 0.4, -s * 0.95)
      ..close();
    c.drawPath(hat, Paint()..color = const Color(0xFF311B92));
    c.restore();
  }

  /// 霍格華茲式城堡：山丘上高低錯落的尖塔群＋連接城牆＋暖黃燈窗。
  void _castleScene(Canvas c, double w, double h, Random rng) {
    final double baseY = h * 0.93;

    // 山丘
    final Path hill = Path()
      ..moveTo(0, baseY)
      ..quadraticBezierTo(w * 0.25, baseY - h * 0.05, w * 0.5, baseY - h * 0.035)
      ..quadraticBezierTo(w * 0.78, baseY - h * 0.015, w, baseY - h * 0.05)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    c.drawPath(hill, Paint()..color = const Color(0xFF0B0620));

    final Random wr = Random(99); // 燈窗點亮的決定（固定）

    // 一座塔：塔身＋（尖頂或城垛）＋暖黃燈窗。
    void tower(double cx, double width, double height,
        {bool cone = true, bool flag = false, Color body = _castle}) {
      final double left = cx - width / 2;
      final double top = baseY - height;
      c.drawRect(Rect.fromLTWH(left, top, width, height),
          Paint()..color = body);
      if (cone) {
        final Path roof = Path()
          ..moveTo(left - width * 0.14, top)
          ..lineTo(cx, top - width * 1.25)
          ..lineTo(left + width + width * 0.14, top)
          ..close();
        c.drawPath(roof, Paint()..color = body);
        if (flag) {
          final double tipY = top - width * 1.25;
          c.drawLine(Offset(cx, tipY), Offset(cx, tipY - height * 0.12),
              Paint()
                ..color = body
                ..strokeWidth = 2.2);
          final double fy = tipY - height * 0.12;
          final Path f = Path()
            ..moveTo(cx, fy)
            ..lineTo(cx + width * 0.55, fy + width * 0.16)
            ..lineTo(cx, fy + width * 0.32)
            ..close();
          c.drawPath(f, Paint()..color = const Color(0xFF7C4DFF));
        }
      } else {
        // 城垛
        final double bw = width / 5;
        for (int i = 0; i < 5; i += 2) {
          c.drawRect(
              Rect.fromLTWH(left + i * bw, top - bw, bw, bw),
              Paint()..color = body);
        }
      }
      // 燈窗（拱形小窗，隨機點亮）
      final int rows = max(1, (height / (width * 1.0)).floor());
      for (int r = 0; r < rows; r++) {
        final double wy = top + width * 0.55 + r * width * 1.0;
        if (wy > baseY - width * 0.4) break;
        if (wr.nextDouble() < 0.7) {
          final Rect rect = Rect.fromCenter(
              center: Offset(cx, wy),
              width: width * 0.32,
              height: width * 0.46);
          c.drawRRect(
              RRect.fromRectAndCorners(rect,
                  topLeft: Radius.circular(width * 0.16),
                  topRight: Radius.circular(width * 0.16)),
              Paint()..color = _win.withValues(alpha: 0.92));
        }
      }
    }

    final double cx = w * 0.5;

    // 後排細尖塔（較暗）
    tower(cx - w * 0.20, w * 0.045, h * 0.30, body: _castle);
    tower(cx + w * 0.21, w * 0.05, h * 0.34, flag: true, body: _castle);
    tower(cx - w * 0.07, w * 0.05, h * 0.40, body: _castle);

    // 連接城牆（含城垛與一排燈窗）
    final double wallTop = baseY - h * 0.15;
    c.drawRect(Rect.fromLTWH(cx - w * 0.17, wallTop, w * 0.34, h * 0.15),
        Paint()..color = _castleFront);
    final double bw = w * 0.34 / 9;
    for (int i = 0; i < 9; i += 2) {
      c.drawRect(
          Rect.fromLTWH(cx - w * 0.17 + i * bw, wallTop - bw * 0.7, bw, bw * 0.7),
          Paint()..color = _castleFront);
    }
    for (int i = 0; i < 5; i++) {
      final double wx = cx - w * 0.13 + i * w * 0.065;
      if (wr.nextDouble() < 0.75) {
        final Rect rect = Rect.fromCenter(
            center: Offset(wx, wallTop + h * 0.07),
            width: w * 0.022,
            height: h * 0.05);
        c.drawRRect(
            RRect.fromRectAndCorners(rect,
                topLeft: Radius.circular(w * 0.011),
                topRight: Radius.circular(w * 0.011)),
            Paint()..color = _win.withValues(alpha: 0.9));
      }
    }

    // 前排主塔群（較亮、較前）
    tower(cx - w * 0.13, w * 0.085, h * 0.26, cone: false, body: _castleFront);
    tower(cx + w * 0.13, w * 0.075, h * 0.30, flag: true, body: _castleFront);
    // 中央最高主塔
    tower(cx, w * 0.12, h * 0.46, flag: true, body: _castleFront);
  }

  @override
  bool shouldRepaint(covariant _MagicPainter oldDelegate) => false;
}
