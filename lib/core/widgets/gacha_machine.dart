import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 扭蛋機（零素材，純向量）：上方透明圓罩裡裝著五顏六色的扭蛋球，
/// 下方紅色機身有轉鈕、投幣孔與出蛋口。
///
/// [spinning] 為 true 時，罩子裡的扭蛋球會在裡面翻滾打轉。
class GachaMachine extends StatefulWidget {
  const GachaMachine({super.key, required this.spinning});

  final bool spinning;

  @override
  State<GachaMachine> createState() => _GachaMachineState();
}

class _GachaMachineState extends State<GachaMachine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _c.repeat();
  }

  @override
  void didUpdateWidget(GachaMachine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.spinning && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _GachaPainter(spin: widget.spinning ? _c.value : -1.0),
        );
      },
    );
  }
}

class _GachaPainter extends CustomPainter {
  _GachaPainter({required this.spin});

  /// -1 = 靜止（球堆在底部）；0~1 = 轉動動畫相位。
  final double spin;

  // 扭蛋球顏色（鮮豔、童趣）。
  static const List<Color> _caps = <Color>[
    Color(0xFFFF6B6B), Color(0xFFFFA94D), Color(0xFFFFD43B),
    Color(0xFF69DB7C), Color(0xFF4DABF7), Color(0xFF9775FA),
    Color(0xFFFF8ED4), Color(0xFF3BC9DB), Color(0xFFFFC078),
    Color(0xFF63E6BE), Color(0xFFFF6B9D),
  ];

  // 球的靜止位置（dome 半徑為單位，偏下方堆積）。
  static const List<Offset> _rest = <Offset>[
    Offset(-0.45, 0.40), Offset(0.0, 0.50), Offset(0.45, 0.40),
    Offset(-0.22, 0.18), Offset(0.24, 0.20), Offset(-0.50, 0.06),
    Offset(0.52, 0.08), Offset(0.0, 0.14), Offset(-0.16, 0.42),
    Offset(0.18, 0.40), Offset(0.02, -0.10),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final Paint p = Paint()..isAntiAlias = true;

    final double domeR = w * 0.42;
    final Offset domeC = Offset(cx, h * 0.06 + domeR);
    final double bodyTop = domeC.dy + domeR * 0.52;
    final Rect bodyRect = Rect.fromLTRB(
        cx - w * 0.40, bodyTop, cx + w * 0.40, h * 0.985);
    final double capR = w * 0.082;

    // 地面陰影
    p.color = const Color(0x1A000000);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, h * 0.985), width: w * 0.72, height: h * 0.045),
        p);

    // ---- 機身 ----
    final RRect body =
        RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.11));
    p.color = const Color(0xFFEF5350); // 紅機身
    canvas.drawRRect(body, p);
    // 機身下半較深（立體感）
    p.color = const Color(0x14000000);
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
        Rect.fromLTRB(bodyRect.left, bodyRect.center.dy + h * 0.02,
            bodyRect.right, bodyRect.bottom),
        p);
    canvas.restore();

    // 出蛋口（深色凹槽）
    final Rect trayR = Rect.fromCenter(
        center: Offset(cx, bodyRect.bottom - h * 0.07),
        width: w * 0.46,
        height: h * 0.11);
    p.color = const Color(0xFF7A1F1C);
    canvas.drawRRect(
        RRect.fromRectAndRadius(trayR, Radius.circular(w * 0.05)), p);

    // 轉鈕（白圈 + 中心 + 旋轉指標；轉動時跟著轉）
    final Offset knobC = Offset(cx, bodyRect.top + (trayR.top - bodyRect.top) * 0.45);
    final double knobR = w * 0.11;
    p.color = const Color(0xFFFFF3E0);
    canvas.drawCircle(knobC, knobR, p);
    p.color = const Color(0xFFFFCC80);
    canvas.drawCircle(knobC, knobR * 0.66, p);
    // 旋鈕上的「一字」把手
    final double knobAng = spin >= 0 ? spin * 2 * math.pi : 0.6;
    canvas.save();
    canvas.translate(knobC.dx, knobC.dy);
    canvas.rotate(knobAng);
    p.color = const Color(0xFFEF6C00);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: knobR * 1.5, height: knobR * 0.42),
            Radius.circular(knobR * 0.21)),
        p);
    canvas.restore();
    p.color = const Color(0xFFEF6C00);
    canvas.drawCircle(knobC, knobR * 0.16, p);

    // ---- 圓罩與球 ----
    // 連接頸圈（金屬色梯形）
    final Path collar = Path()
      ..moveTo(cx - domeR * 0.62, domeC.dy + domeR * 0.74)
      ..lineTo(cx + domeR * 0.62, domeC.dy + domeR * 0.74)
      ..lineTo(cx + domeR * 0.82, bodyTop + h * 0.012)
      ..lineTo(cx - domeR * 0.82, bodyTop + h * 0.012)
      ..close();
    p.color = const Color(0xFFB0BEC5);
    canvas.drawPath(collar, p);

    // 玻璃罩底（淡藍透明）
    p.color = const Color(0x335AA9E6);
    canvas.drawCircle(domeC, domeR, p);

    // 球（裁切在圓罩內）
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: domeC, radius: domeR - 1)));
    for (int i = 0; i < _rest.length; i++) {
      final Offset pos = _capPos(i, domeC, domeR);
      _drawCapsule(canvas, p, pos, capR, _caps[i % _caps.length], i);
    }
    canvas.restore();

    // 玻璃罩外框 + 高光
    p
      ..color = const Color(0xFFCFD8DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025;
    canvas.drawCircle(domeC, domeR, p);
    p.style = PaintingStyle.fill;
    // 左上白色反光弧
    final Paint glare = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(
        Rect.fromCircle(center: domeC, radius: domeR * 0.78),
        math.pi * 1.05, math.pi * 0.4, false, glare);
  }

  /// 球的位置：靜止時堆在底部；轉動時繞罩心打轉（每球速度/方向不同 → 翻滾感）。
  Offset _capPos(int i, Offset domeC, double domeR) {
    Offset o = _rest[i];
    if (spin >= 0) {
      final double dir = i.isEven ? 1.0 : -1.0;
      final double th = spin * 2 * math.pi * (1.6 + (i % 3) * 0.7) * dir + i;
      final double ca = math.cos(th), sa = math.sin(th);
      o = Offset(o.dx * ca - o.dy * sa, o.dx * sa + o.dy * ca);
      final double wob = 1 + 0.05 * math.sin(spin * 8 * math.pi + i);
      o = o * wob;
    }
    return domeC + Offset(o.dx * domeR, o.dy * domeR);
  }

  /// 單顆扭蛋：上半彩色、下半白（經典轉蛋雙色），加小高光。
  void _drawCapsule(
      Canvas canvas, Paint p, Offset c, double r, Color color, int i) {
    final Rect box = Rect.fromCircle(center: c, radius: r);
    canvas.save();
    canvas.clipPath(Path()..addOval(box));
    p
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawRect(Rect.fromLTRB(box.left, box.top, box.right, c.dy), p);
    p.color = const Color(0xFFF7F7FA);
    canvas.drawRect(Rect.fromLTRB(box.left, c.dy, box.right, box.bottom), p);
    canvas.restore();
    // 邊線
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16
      ..color = color.withValues(alpha: 0.55);
    canvas.drawCircle(c, r, p);
    p.style = PaintingStyle.fill;
    // 高光
    p.color = const Color(0x88FFFFFF);
    canvas.drawCircle(c.translate(-r * 0.32, -r * 0.34), r * 0.22, p);
  }

  @override
  bool shouldRepaint(covariant _GachaPainter old) => old.spin != spin;
}
