import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learn_app/core/responsive.dart';

void main() {
  group('scaleFor 高度感知縮放', () {
    test('平板橫向（高度足夠）→ 維持上限 1.6，不受高度影響', () {
      // iPad 類：1024×768 landscape。
      expect(scaleFor(const Size(1024, 768)), 1.6);
    });

    test('預設測試畫面 800×600（高度 ≥ 480）→ 不做高度縮放，等同短邊/400', () {
      // 600/400 = 1.5；高度 600 ≥ 480 門檻，維持原行為，避免既有測試位移。
      expect(scaleFor(const Size(800, 600)), 1.5);
    });

    test('手機橫向（矮螢幕）→ 依高度縮小到放得下', () {
      // 高度 390 < 480：byHeight = 390/430 ≈ 0.907，比短邊基準小，故取它。
      expect(scaleFor(const Size(844, 390)), closeTo(0.907, 0.001));
    });

    test('很矮的舊手機 → 夾在下限 0.8，不會無限縮小', () {
      // 320/430 ≈ 0.744 → clamp 到 0.8。
      expect(scaleFor(const Size(800, 320)), 0.8);
    });

    test('剛好在門檻上（高度 = 480）→ 不做高度縮放', () {
      // 480 不 < 480，走短邊基準：shortestSide 480 / 400 = 1.2。
      expect(scaleFor(const Size(900, 480)), 1.2);
    });
  });
}
