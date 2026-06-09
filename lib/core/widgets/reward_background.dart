import 'package:flutter/material.dart';

import '../responsive.dart';

/// 獎勵區（扭蛋 / 收藏室 / 獎盃櫃）的柔和主題背景：
/// 暖色漸層 + 淡淡的星星 / 彩帶點綴，低調不搶內容。
class RewardBackground extends StatelessWidget {
  const RewardBackground({super.key});

  // (emoji, 對齊 x, 對齊 y, 字級, 透明度)
  static const List<(String, double, double, double, double)> _deco =
      <(String, double, double, double, double)>[
    ('⭐', -0.85, -0.8, 72, 0.22),
    ('✨', 0.8, -0.7, 64, 0.26),
    ('🎈', -0.72, 0.72, 68, 0.20),
    ('🎉', 0.86, 0.76, 68, 0.22),
    ('⭐', 0.18, -0.92, 44, 0.18),
    ('✨', -0.28, 0.94, 48, 0.18),
    ('🌟', 0.93, 0.08, 52, 0.20),
    ('🎀', -0.93, 0.02, 50, 0.18),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFFFF6E0), Color(0xFFFFD89B)],
        ),
      ),
      child: Stack(
        children: <Widget>[
          for (final (String, double, double, double, double) d in _deco)
            Align(
              alignment: Alignment(d.$2, d.$3),
              child: Opacity(
                opacity: d.$5,
                child: Text(d.$1, style: TextStyle(fontSize: context.s(d.$4))),
              ),
            ),
        ],
      ),
    );
  }
}
