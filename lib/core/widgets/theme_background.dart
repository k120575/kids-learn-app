import 'package:flutter/material.dart';

import '../../content/themes.dart';
import '../../models/age_band.dart';
import 'magic_background.dart';
import 'park_background.dart';
import 'space_background.dart';

/// 依年齡段回傳沉浸式主題背景：優先用童書插畫場景圖（`assets/images/{bg}.png`），
/// 缺圖時自動退回向量動畫背景。沒主題回 null。
Widget? worldBackground(AgeBand band) {
  final WorldTheme? world = worldFor(band);
  final Widget? fallback = _vectorFallback(band);
  if (world?.bg != null) {
    return Image.asset(
      'assets/images/${world!.bg}.png',
      fit: BoxFit.cover,
      errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
          fallback ?? const SizedBox.shrink(),
    );
  }
  return fallback;
}

Widget? _vectorFallback(AgeBand band) {
  switch (band) {
    case AgeBand.age3_4:
      return const ParkBackground();
    case AgeBand.age4_5:
      return const SpaceBackground();
    case AgeBand.age5_6:
      return const MagicBackground();
  }
}

/// 該主題是否為深色底（決定標題文字用白色）。
bool worldIsDark(AgeBand band) =>
    band == AgeBand.age4_5 || band == AgeBand.age5_6;
