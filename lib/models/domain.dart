import 'package:flutter/material.dart';

/// 多元智能四大領域。每個領域有代表色與 emoji，用於選單與遊戲標題。
enum Domain {
  language('語文', '🗣️', Color(0xFFFFA726)),
  logicMath('邏輯數學', '🔢', Color(0xFF42A5F5)),
  spatial('空間', '🧩', Color(0xFF66BB6A)),
  music('音樂', '🎵', Color(0xFFAB47BC)),
  brain('動腦', '🧠', Color(0xFF26A69A));

  const Domain(this.label, this.emoji, this.color);

  final String label;
  final String emoji;
  final Color color;
}
