import 'package:flutter/material.dart';

/// 幼兒友善主題：明亮、大字、圓角。
ThemeData buildTheme() {
  final ThemeData base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF42A5F5)),
    scaffoldBackgroundColor: const Color(0xFFFFFDF6),
    // 把彩色 emoji 字型放全 App 字型 fallback：題目/關卡大量用 emoji，靠系統字型
    // 在部分裝置會缺字變空白方框，改用自帶字型確保各裝置一致顯示。
    // 註：自帶的 NotoColorEmoji 已 subset 掉 ASCII（0-9 等），避免它搶走一般數字
    //（否則「3-4」會變成寬間距的 emoji 數字）。詳見 tool/subset_emoji_font.py。
    fontFamilyFallback: const <String>['NotoColorEmoji'],
  );

  return base.copyWith(
    // 注意：不要用 fontSizeFactor（M3 部分 textStyle 的 fontSize 為 null，
    // 套用縮放因子會觸發斷言崩潰）。字級各畫面已明確指定。
    textTheme: base.textTheme.apply(
      bodyColor: const Color(0xFF40454F),
      displayColor: const Color(0xFF40454F),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: Color(0xFF40454F),
      ),
    ),
  );
}

/// 共用圓角半徑與間距常數。
class Sizes {
  static const double radius = 28;
  static const double gap = 16;
  static const double bigGap = 28;

  /// 最小觸控熱區（幼兒 ≥ ~1.5cm）。
  static const double minTouch = 96;
}
