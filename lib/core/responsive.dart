import 'package:flutter/widgets.dart';

/// 縮放係數的純函式（方便單元測試）。
///
/// 基準：短邊 400dp → 1.0，夾在 [0.8, 1.6]（避免小手機過小、大平板過大）。
///
/// **高度感知**：App 鎖橫向，手機橫向的「高度」只有平板的一半（~390 vs ~768dp），
/// 是真正稀缺的資源。當高度 < [_shortScreenH]（手機橫向）時，額外依高度再縮小，
/// 讓內容不必上下捲動就放得下。平板／一般螢幕（高度足夠）完全不受影響、維持原縮放。
double scaleFor(Size size) {
  double s = size.shortestSide / 400;
  if (size.height < _shortScreenH) {
    final double byHeight = size.height / _designContentH;
    if (byHeight < s) s = byHeight;
  }
  return s.clamp(0.8, 1.6);
}

/// 視為「矮螢幕」（手機橫向）的高度門檻；以上的螢幕不做高度縮放。
const double _shortScreenH = 480;

/// 排版設計的內容高度基準：矮螢幕依此把內容縮到放得下。
const double _designContentH = 430;

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
  /// 縮放係數，見 [scaleFor]。
  double get scale => scaleFor(MediaQuery.of(this).size);

  /// 把「設計基準（短邊 400dp）下的尺寸」[px] 依裝置等比縮放後回傳。
  double s(double px) => px * scale;

  /// 螢幕寬度的 [fraction] 比例（0~1）。用於相對定位 / 相對寬度。
  double w(double fraction) => MediaQuery.of(this).size.width * fraction;

  /// 螢幕高度的 [fraction] 比例（0~1）。用於相對定位 / 相對高度。
  double h(double fraction) => MediaQuery.of(this).size.height * fraction;
}
