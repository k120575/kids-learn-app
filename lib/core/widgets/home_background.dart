import 'dart:math';

import 'package:flutter/material.dart';

/// 首頁（選年齡）動畫背景：一個「輕鬆愉快、孩子會喜歡」的中性場景——
/// 陽光、飄雲、彩虹、草地小花、飛舞的蝴蝶、上升的小泡泡。
/// 刻意「不綁任何世界主題」（遊樂園/宇宙/未來年齡段都不指涉），只走同一套
/// 手繪向量動畫畫風，當任何年齡段的共用首頁底圖都合適。
class HomeBackground extends StatefulWidget {
  const HomeBackground({super.key});

  @override
  State<HomeBackground> createState() => _HomeBackgroundState();
}

class _HomeBackgroundState extends State<HomeBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HomePainter(_c),
      size: Size.infinite,
    );
  }
}

class _HomePainter extends CustomPainter {
  _HomePainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const List<Color> _flowerColors = <Color>[
    Color(0xFFEF5350), Color(0xFFFFCA28), Color(0xFFAB47BC),
    Color(0xFFFF7043), Color(0xFFEC407A),
  ];
  // 花的相對位置（x, 在草地帶內的高度比例）
  static const List<List<double>> _flowers = <List<double>>[
    <double>[0.08, 0.30], <double>[0.22, 0.62], <double>[0.40, 0.40],
    <double>[0.58, 0.66], <double>[0.74, 0.34], <double>[0.90, 0.58],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double p = t.value;

    // 明亮愉快的天空（藍 → 暖奶油）
    final Paint sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF8FD3F4), // 天藍
          Color(0xFFC8E8F7), // 淺藍
          Color(0xFFFFF6D5), // 暖奶油
        ],
        stops: <double>[0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), sky);

    final double shortSide = min(w, h);

    // 中央內容後方的柔和白色暈染：讓對話框/按鈕/年齡卡更好讀，與背景拉開層次。
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.05),
          radius: 0.75,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.45),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // 太陽（右上，光芒緩慢旋轉）
    _sun(canvas, Offset(w * 0.88, h * 0.16), shortSide * 0.07, p);

    // 彩虹：縮小成左下角點綴（半徑用較短邊、腳收進草地、不越過中央內容）。
    _rainbow(canvas, Offset(w * 0.08, h * 0.86), shortSide * 0.42);

    // 飄動的雲
    for (int i = 0; i < 3; i++) {
      final double phase = (p + i / 3) % 1;
      final double cx = phase * (w + 240) - 120;
      final double cy = h * (0.22 + i * 0.12);
      _cloud(canvas, Offset(cx, cy), h * 0.045);
    }

    // 上升的小泡泡（柔和半透明）
    for (int i = 0; i < 6; i++) {
      final double phase = (p * 0.8 + i / 6) % 1;
      final double by = h - phase * (h + 120) + 40;
      final double bx = w * (0.08 + i * 0.16) + sin(phase * 6.28 + i) * 16;
      final double r = h * (0.012 + (i % 3) * 0.006);
      canvas.drawCircle(Offset(bx, by), r,
          Paint()..color = Colors.white.withValues(alpha: 0.28));
      canvas.drawCircle(Offset(bx, by), r,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }

    // 草地（兩層小山，前深後淺，有層次）
    final double gy = h * 0.80;
    canvas.drawCircle(Offset(w * 0.25, gy + h * 0.16), h * 0.22,
        Paint()..color = const Color(0xFFAED581));
    canvas.drawCircle(Offset(w * 0.80, gy + h * 0.15), h * 0.20,
        Paint()..color = const Color(0xFFAED581));
    canvas.drawRect(Rect.fromLTWH(0, gy, w, h - gy),
        Paint()..color = const Color(0xFF9CCC65));
    canvas.drawCircle(Offset(w * 0.55, gy + h * 0.12), h * 0.16,
        Paint()..color = const Color(0xFF7CB342));
    canvas.drawCircle(Offset(w * 0.10, gy + h * 0.14), h * 0.14,
        Paint()..color = const Color(0xFF7CB342));

    // 草地小花
    for (int i = 0; i < _flowers.length; i++) {
      final List<double> f = _flowers[i];
      final Offset o = Offset(w * f[0], gy + (h - gy) * f[1]);
      // 微微搖擺
      final double sway = sin(p * 6.28 + i) * h * 0.004;
      _flower(canvas, o.translate(sway, 0), h * 0.02,
          _flowerColors[i % _flowerColors.length]);
    }

    // 飛舞的蝴蝶
    _butterfly(canvas, w, h, p, 0.0, const Color(0xFFFF7043), 0.0);
    _butterfly(canvas, w, h, p, 0.45, const Color(0xFFAB47BC), 0.33);
    _butterfly(canvas, w, h, p, 0.75, const Color(0xFF42A5F5), 0.66);
  }

  void _sun(Canvas c, Offset o, double r, double p) {
    final double ang = p * 2 * pi;
    final Paint ray = Paint()
      ..color = const Color(0xFFFFD54F)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 12; i++) {
      final double a = ang + i * pi / 6;
      c.drawLine(o + Offset(cos(a) * r * 1.35, sin(a) * r * 1.35),
          o + Offset(cos(a) * r * 1.75, sin(a) * r * 1.75), ray);
    }
    c.drawCircle(o, r * 1.3,
        Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.5));
    c.drawCircle(o, r, Paint()..color = const Color(0xFFFFD54F));
    // 笑臉
    final Paint face = Paint()
      ..color = const Color(0xFFF9A825)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    c.drawCircle(o.translate(-r * 0.35, -r * 0.15), r * 0.08,
        Paint()..color = const Color(0xFFF9A825));
    c.drawCircle(o.translate(r * 0.35, -r * 0.15), r * 0.08,
        Paint()..color = const Color(0xFFF9A825));
    final Path smile = Path()
      ..addArc(
          Rect.fromCircle(center: o.translate(0, r * 0.05), radius: r * 0.45),
          0.2 * pi, 0.6 * pi);
    c.drawPath(smile, face);
  }

  void _rainbow(Canvas c, Offset center, double r) {
    const List<Color> bands = <Color>[
      Color(0xFFEF5350), Color(0xFFFFA726), Color(0xFFFFEE58),
      Color(0xFF66BB6A), Color(0xFF42A5F5), Color(0xFFAB47BC),
    ];
    final double bw = r * 0.05;
    for (int i = 0; i < bands.length; i++) {
      c.drawArc(
        Rect.fromCircle(center: center, radius: r - i * bw),
        pi, // 半圓拱橋（上半）
        pi,
        false,
        Paint()
          ..color = bands[i].withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bw,
      );
    }
  }

  void _cloud(Canvas c, Offset o, double r) {
    final Paint pnt = Paint()..color = Colors.white.withValues(alpha: 0.92);
    c.drawCircle(o, r, pnt);
    c.drawCircle(o + Offset(r, r * 0.2), r * 0.8, pnt);
    c.drawCircle(o + Offset(-r, r * 0.2), r * 0.8, pnt);
    c.drawCircle(o + Offset(0, r * 0.4), r, pnt);
  }

  void _flower(Canvas c, Offset o, double r, Color color) {
    // 莖
    c.drawLine(o, o + Offset(0, r * 3),
        Paint()..color = const Color(0xFF558B2F)..strokeWidth = 3);
    // 花瓣
    for (int i = 0; i < 5; i++) {
      final double a = i * 2 * pi / 5 - pi / 2;
      c.drawCircle(o + Offset(cos(a) * r * 0.7, sin(a) * r * 0.7), r * 0.5,
          Paint()..color = color);
    }
    // 花心
    c.drawCircle(o, r * 0.45, Paint()..color = const Color(0xFFFFEB3B));
  }

  void _butterfly(
      Canvas c, double w, double h, double p, double offset, Color color,
      double yBase) {
    // 沿緩和的正弦路徑飄移
    final double phase = (p + offset) % 1;
    final double x = phase * (w + 120) - 60;
    final double y = h * (0.30 + yBase * 0.25) + sin(phase * 6.28 * 2) * h * 0.05;
    final Offset o = Offset(x, y);
    // 翅膀拍動（寬度隨時間縮放）
    final double flap = 0.55 + 0.45 * (sin(p * 2 * pi * 8 + offset * 10).abs());
    final double s = h * 0.022;
    final Paint wing = Paint()..color = color.withValues(alpha: 0.9);
    final Paint wingLight = Paint()..color = color.withValues(alpha: 0.55);
    for (final double sign in <double>[-1, 1]) {
      // 上翅
      c.drawOval(
          Rect.fromCenter(
              center: o + Offset(sign * s * flap, -s * 0.4),
              width: s * 1.6 * flap,
              height: s * 1.5),
          wing);
      // 下翅
      c.drawOval(
          Rect.fromCenter(
              center: o + Offset(sign * s * 0.8 * flap, s * 0.6),
              width: s * 1.2 * flap,
              height: s * 1.1),
          wingLight);
    }
    // 身體
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: o, width: s * 0.3, height: s * 1.9),
            Radius.circular(s * 0.15)),
        Paint()..color = const Color(0xFF4E342E));
  }

  @override
  bool shouldRepaint(covariant _HomePainter oldDelegate) => false;
}
