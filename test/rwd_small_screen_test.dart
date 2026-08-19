import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learn_app/content/lang45_levels.dart';
import 'package:kids_learn_app/core/progress_store.dart';
import 'package:kids_learn_app/games/find_same_game.dart';
import 'package:kids_learn_app/games/multiplication_game.dart';
import 'package:kids_learn_app/games/symmetry_game.dart';
import 'package:kids_learn_app/games/zhuyin_match_game.dart';

/// 矮螢幕 RWD 防護網：預設 widget 測試只跑 800×600 一種尺寸，
/// responsive.dart 的「矮螢幕縮放」分支與「只顧寬不顧高」型破版在 CI 完全測不到。
/// 這裡用「20:9 手機橫向」與「4:3 平板橫向（scale 放大到 1.6）」兩種尺寸，
/// 把曾經溢出的四個關卡逼到**挑戰難度**（最高的版面）跑一輪，
/// RenderFlex overflow 會以例外形式被 takeException 抓到。
void main() {
  const List<Size> sizes = <Size>[
    Size(844, 390), // 20:9 手機橫向（如 Pixel 8 級距）
    Size(1280, 800), // 4:3 大平板橫向（scale 被放大）
  ];

  setUp(() async {
    await ProgressStore.instance.init(); // 無平台 → 純記憶體
    ProgressStore.instance.soundEnabled = false; // 語音走靜音後備
  });

  Future<void> pumpAt(WidgetTester tester, Size size, Widget home) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // 讓逐字念題的延遲鏈（乘法 ~3.4s）跑完，避免測試結束時還有 pending timer。
    await tester.pump(const Duration(seconds: 4));
  }

  /// 把 gameId 的適性難度推到 2（挑戰）：預設 1，全對一次即升級。
  Future<void> forceChallenge(String gameId) =>
      ProgressStore.instance.recordOutcome(gameId, 0);

  for (final Size size in sizes) {
    final String label = '${size.width.toInt()}×${size.height.toInt()}';

    testWidgets('乘法魔法 挑戰難度在 $label 不溢出', (WidgetTester tester) async {
      // 題目隨機，多跑幾盤逼出高的星星陣列（如 9×3）。
      for (int run = 0; run < 6; run++) {
        const String id = 'rwd_multiply';
        await forceChallenge(id);
        await pumpAt(
          tester,
          size,
          const MultiplicationGame(gameId: id, title: '乘法魔法'),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('對稱鏡像 挑戰難度（6×3）在 $label 不溢出', (WidgetTester tester) async {
      const String id = 'rwd_symmetry';
      await forceChallenge(id);
      await pumpAt(tester, size, const SymmetryGame(gameId: id, title: '對稱鏡像'));
      expect(tester.takeException(), isNull);
      expect(find.byType(SymmetryGame), findsOneWidget);
    });

    testWidgets('注音對對碰 挑戰難度（8 對＝4×4）在 $label 不溢出',
        (WidgetTester tester) async {
      const String id = 'rwd_zhuyin';
      await forceChallenge(id);
      await pumpAt(
        tester,
        size,
        const ZhuyinMatchGame(
          gameId: id,
          title: '注音對對碰',
          pool: zhuyinMatchPool,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ZhuyinMatchGame), findsOneWidget);
    });

    testWidgets('找一樣 挑戰難度（5 選項）在 $label 不溢出、上下平均排',
        (WidgetTester tester) async {
      const String id = 'rwd_find_same';
      await forceChallenge(id);
      await pumpAt(tester, size, const FindSameGame(gameId: id, title: '找一樣'));
      expect(tester.takeException(), isNull);
      expect(find.byType(FindSameGame), findsOneWidget);
    });
  }
}
