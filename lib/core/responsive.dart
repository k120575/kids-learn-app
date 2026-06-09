import 'package:flutter/widgets.dart';

/// 響應式尺寸工具（RWD）：以「短邊 400dp」為設計基準，依裝置實際短邊等比縮放。
///
/// 全 App 統一用這套，不要再到處寫死像素或重複 `MediaQuery...shortestSide / 400`。
///
/// 用法：
/// ```dart
/// SizedBox(width: context.s(62))          // 62 是設計基準下的尺寸
/// Text('a', style: TextStyle(fontSize: context.s(24)))
/// Positioned(left: context.w(0.03), bottom: context.h(0.03), child: ...)
/// ```
///
/// 注意：用了 `context.s/w/h` 的 widget 不能再標 `const`（值在 build 時才算出）。
extension Responsive on BuildContext {
  /// 縮放係數：裝置短邊 / 400，夾在 [0.85, 1.6]，避免小手機過小、大平板過大。
  double get scale {
    final double shortest = MediaQuery.of(this).size.shortestSide;
    return (shortest / 400).clamp(0.85, 1.6);
  }

  /// 把「設計基準（短邊 400dp）下的尺寸」[px] 依裝置等比縮放後回傳。
  double s(double px) => px * scale;

  /// 螢幕寬度的 [fraction] 比例（0~1）。用於相對定位 / 相對寬度。
  double w(double fraction) => MediaQuery.of(this).size.width * fraction;

  /// 螢幕高度的 [fraction] 比例（0~1）。用於相對定位 / 相對高度。
  double h(double fraction) => MediaQuery.of(this).size.height * fraction;
}
