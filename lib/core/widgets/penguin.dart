import 'dart:math';

import 'package:flutter/material.dart';

/// 吉祥物「企企」：圓滾滾的可愛企鵝（白臉＋深色頭罩＋張開翅膀＋呆毛），
/// 向量繪製（零素材），會輕輕搖擺＋眨眼。
class Penguin extends StatefulWidget {
  const Penguin({super.key, this.size = 140, this.animate = true});

  final double size;
  final bool animate;

  @override
  State<Penguin> createState() => _PenguinState();
}

class _PenguinState extends State<Penguin> with SingleTickerProviderStateMixin {
  // 只在需要動畫時才建立控制器；用可空避免 dispose 時才懶初始化而崩潰。
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3200),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AnimationController? c = _c;
    if (c == null) {
      return CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _PenguinPainter(eyeOpen: 1),
      );
    }
    return AnimatedBuilder(
      animation: c,
      builder: (BuildContext context, Widget? child) {
        final double t = c.value;
        final double bob = sin(t * 2 * pi) * widget.size * 0.022;
        double eyeOpen = 1;
        if (t > 0.46 && t < 0.54) {
          final double k = (t - 0.46) / 0.08; // 0..1
          eyeOpen = (1 - (1 - (2 * k - 1).abs())).clamp(0.12, 1.0);
        }
        return Transform.translate(
          offset: Offset(0, bob),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _PenguinPainter(eyeOpen: eyeOpen),
          ),
        );
      },
    );
  }
}

class _PenguinPainter extends CustomPainter {
  _PenguinPainter({required this.eyeOpen});

  final double eyeOpen;

  static const Color _dark = Color(0xFF2E3A59); // 深藍黑
  static const Color _white = Color(0xFFFDFDFF);
  static const Color _beak = Color(0xFFFFB23E);
  static const Color _foot = Color(0xFFFF9F2E);
  static const Color _cheek = Color(0xFFFFB3C1);
  static const Color _eye = Color(0xFF2B2B33);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double cx = s / 2;
    final Paint p = Paint()..isAntiAlias = true;

    // 腳（橘色蹼，帶小凹）
    p.color = _foot;
    for (final double sign in <double>[-1, 1]) {
      final double fx = cx + sign * s * 0.15;
      final Path foot = Path()
        ..moveTo(fx - s * 0.13, s * 0.99)
        ..lineTo(fx - s * 0.04, s * 0.88)
        ..lineTo(fx + s * 0.04, s * 0.88)
        ..lineTo(fx + s * 0.13, s * 0.99)
        ..quadraticBezierTo(fx, s * 1.02, fx - s * 0.13, s * 0.99)
        ..close();
      canvas.drawPath(foot, p);
    }

    // 翅膀（張開、往外，較大）
    p.color = _dark;
    for (final double sign in <double>[-1, 1]) {
      canvas.save();
      canvas.translate(cx + sign * s * 0.37, s * 0.5);
      canvas.rotate(sign * 0.55);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: s * 0.22, height: s * 0.52),
              Radius.circular(s * 0.11)),
          p);
      canvas.restore();
    }

    // 深色身體（頭罩＋背）
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, s * 0.54), width: s * 0.8, height: s * 0.9), p);

    // 呆毛
    final Path tuft = Path()
      ..moveTo(cx - s * 0.02, s * 0.12)
      ..quadraticBezierTo(cx + s * 0.03, -s * 0.01, cx + s * 0.1, s * 0.04)
      ..quadraticBezierTo(cx + s * 0.02, s * 0.08, cx + s * 0.05, s * 0.14)
      ..close();
    canvas.drawPath(tuft, p);

    // 白色臉＋肚子：大肚子 + 兩個圓臉頰（重疊處在眼睛中間留出深色「尖頭罩」）
    p.color = _white;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, s * 0.66), width: s * 0.64, height: s * 0.62), p); // 肚子
    canvas.drawCircle(Offset(cx - s * 0.15, s * 0.42), s * 0.165, p); // 左臉
    canvas.drawCircle(Offset(cx + s * 0.15, s * 0.42), s * 0.165, p); // 右臉

    // 臉頰（粉）
    p.color = _cheek;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - s * 0.24, s * 0.5), width: s * 0.14, height: s * 0.1), p);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + s * 0.24, s * 0.5), width: s * 0.14, height: s * 0.1), p);

    // 眼睛（大、亮、會眨；中間是深色尖罩）
    final double eyeY = s * 0.43;
    final double eyeDx = s * 0.145;
    for (final double sign in <double>[-1, 1]) {
      final Offset ec = Offset(cx + sign * eyeDx, eyeY);
      p.color = _eye;
      canvas.drawOval(
          Rect.fromCenter(center: ec, width: s * 0.18, height: s * 0.21 * eyeOpen), p);
      if (eyeOpen > 0.6) {
        p.color = _white;
        canvas.drawCircle(ec.translate(s * 0.035, -s * 0.04), s * 0.034, p);
        canvas.drawCircle(ec.translate(-s * 0.035, s * 0.03), s * 0.016, p);
      }
    }

    // 嘴巴（橘色小三角，朝下，在兩眼中間下方）
    p.color = _beak;
    final Path beak = Path()
      ..moveTo(cx - s * 0.05, s * 0.5)
      ..lineTo(cx + s * 0.05, s * 0.5)
      ..lineTo(cx, s * 0.58)
      ..close();
    canvas.drawPath(beak, p);
  }

  @override
  bool shouldRepaint(covariant _PenguinPainter old) => old.eyeOpen != eyeOpen;
}
