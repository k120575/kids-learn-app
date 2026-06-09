import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 首頁標題「寶貝學習樂園」：蓬鬆白雲包裹 + 圓胖字型、每字不同粉彩色、
/// 故意像蠟筆塗鴉一樣斜斜的。
class CloudTitle extends StatelessWidget {
  const CloudTitle({
    super.key,
    this.text = '寶貝學習樂園',
    this.fontSize = 32,
  });

  final String text;
  final double fontSize;

  /// 每字一色（粉彩），不足則循環。
  static const List<Color> _palette = <Color>[
    Color(0xFFEF7C8E), // 粉紅
    Color(0xFFF6A14B), // 橘
    Color(0xFFD9A43A), // 金黃（比預覽稍深，白底上更清楚）
    Color(0xFF5FB87A), // 綠
    Color(0xFF5AA9E6), // 藍
    Color(0xFFA77BD6), // 紫
  ];

  /// 每字傾斜角度（度），刻意不規則，像手畫的。不足則循環。
  static const List<double> _tilt = <double>[-6, 4, -3, 5, -4, 3];

  @override
  Widget build(BuildContext context) {
    final List<Widget> chars = <Widget>[];
    for (int i = 0; i < text.length; i++) {
      chars.add(Transform.rotate(
        angle: _tilt[i % _tilt.length] * math.pi / 180,
        child: Text(
          text[i],
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: TextStyle(
            fontFamily: 'TitleFont',
            fontSize: fontSize,
            color: _palette[i % _palette.length],
            height: 1.0,
          ),
        ),
      ));
      if (i != text.length - 1) {
        chars.add(SizedBox(width: fontSize * 0.06));
      }
    }
    // 雲朵要把字「鬆鬆地」包住，四周留比較多空間：水平 0.8em、垂直 0.72em。
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(painter: _CloudPainter()),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: fontSize * 0.8,
            vertical: fontSize * 0.72,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: chars,
          ),
        ),
      ],
    );
  }
}

/// 遊戲／地圖頂列的品牌標題：與首頁 [CloudTitle] 同字型（TitleFont）、
/// 同「每字粉彩、微微傾斜」的塗鴉風，但**不包白雲**——改用深色描邊 + 柔和陰影，
/// 讓彩色字在深色（宇宙）或淺色（遊樂園 / 白月亮）背景上都清楚跳出、不融入背景。
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, required this.text, this.fontSize = 24});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chars = <Widget>[];
    for (int i = 0; i < text.length; i++) {
      // 不逐字傾斜：頂列小標題擺正才整齊。傾斜（像首頁那樣）在大字 + 白雲框住時
      // 才耐看，縮到小字又沒雲，逐字斜會像剪貼字條一樣雜亂。
      chars.add(_OutlinedChar(
        char: text[i],
        fontSize: fontSize,
        color: CloudTitle._palette[i % CloudTitle._palette.length],
      ));
      if (i != text.length - 1) {
        chars.add(SizedBox(width: fontSize * 0.06));
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: chars,
    );
  }
}

/// 單字：深色描邊層（背）+ 粉彩填色層（前），確保任何背景都有對比。
class _OutlinedChar extends StatelessWidget {
  const _OutlinedChar({
    required this.char,
    required this.fontSize,
    required this.color,
  });

  final String char;
  final double fontSize;
  final Color color;

  static const Color _stroke = Color(0xFF4A3F63); // 深紫灰描邊：深淺背景都壓得住

  @override
  Widget build(BuildContext context) {
    const TextHeightBehavior thb = TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    );
    return Stack(
      children: <Widget>[
        // 描邊層（沿輪廓加粗，當作外框）
        Text(
          char,
          textHeightBehavior: thb,
          style: TextStyle(
            fontFamily: 'TitleFontM',
            fontSize: fontSize,
            height: 1.0,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              // 小字級用 Medium 字重 + 極細邊框（0.04）：只負責跟背景分離，
              // 不能再粗，否則密筆畫字內部會糊。對比主要靠下方陰影。
              ..strokeWidth = fontSize * 0.04
              ..strokeJoin = StrokeJoin.round
              ..color = _stroke,
          ),
        ),
        // 填色層（粉彩 + 柔和陰影，讓字更立體、淺底上更分明）
        Text(
          char,
          textHeightBehavior: thb,
          style: TextStyle(
            fontFamily: 'TitleFontM',
            fontSize: fontSize,
            height: 1.0,
            color: color,
            shadows: const <Shadow>[
              // 細邊框 + 這層較實的陰影一起撐住對比，淺色背景上也不融入。
              Shadow(color: Color(0x80000000), blurRadius: 3, offset: Offset(0, 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CloudPainter extends CustomPainter {
  // 雲朵凸起：x、y（佔寬高比例）、半徑（佔高度比例）。
  static const List<List<double>> _bumps = <List<double>>[
    <double>[0.16, 0.42, 0.30],
    <double>[0.33, 0.30, 0.37],
    <double>[0.50, 0.25, 0.42],
    <double>[0.67, 0.30, 0.38],
    <double>[0.84, 0.42, 0.31],
    <double>[0.18, 0.66, 0.29],
    <double>[0.40, 0.72, 0.31],
    <double>[0.60, 0.72, 0.31],
    <double>[0.82, 0.66, 0.28],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 用 Path 聯集所有圓 + 中央橢圓，畫出單一柔和雲朵輪廓。
    final Path cloud = Path();
    cloud.addOval(Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      width: w * 0.92,
      height: h * 0.64,
    ));
    for (final List<double> b in _bumps) {
      final double r = h * b[2];
      cloud.addOval(Rect.fromCircle(
        center: Offset(w * b[0], h * b[1]),
        radius: r,
      ));
    }

    // 柔和陰影（drawShadow 在各平台與影像擷取下都穩定）。
    canvas.drawShadow(
      cloud.shift(const Offset(0, 2)),
      const Color(0x5578A2C8),
      4.0,
      false,
    );
    // 白色雲體。
    canvas.drawPath(cloud, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) => false;
}
