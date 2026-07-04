import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learn_app/core/progress_store.dart';
import 'package:kids_learn_app/core/widgets/shape_view.dart';
import 'package:kids_learn_app/games/block_copy_game.dart';
import 'package:kids_learn_app/games/tangram_game.dart';

/// 4-5 空間新招牌關的煙霧測試：確保隨機版面產生器 + 建構不丟執行期斷言，
/// 且拖曳來源（托盤）與放置目標（外框）都有畫出來。互動正確性靠真機觸控。
void main() {
  setUp(() async {
    await ProgressStore.instance.init(); // 無平台 → 純記憶體
    ProgressStore.instance.soundEnabled = false; // 走靜音後備，不碰語音外掛
  });

  testWidgets('積木照樣蓋：多次隨機版面能建構 + 有調色盤與待填格', (WidgetTester tester) async {
    for (int run = 0; run < 6; run++) {
      await tester.pumpWidget(MaterialApp(
        home: BlockCopyGame(gameId: 'test_block_$run', title: '積木照樣蓋'),
      ));
      await tester.pump(); // postframe 引導語
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      // 調色盤至少 2 色可拖；盤面至少有一個待填格。
      expect(find.byType(Draggable<Color>), findsWidgets);
      expect(find.byType(DragTarget<Color>), findsWidgets);
      expect(find.text('完成圖'), findsOneWidget);
    }
  });

  testWidgets('拼出圖形：多次隨機圖案能建構 + 有可拖形狀與外框', (WidgetTester tester) async {
    for (int run = 0; run < 6; run++) {
      await tester.pumpWidget(MaterialApp(
        home: TangramGame(gameId: 'test_tangram_$run', title: '拼出圖形'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      // 形狀統一色 → 靠形狀配對；拖曳來源與外框都以 ShapeKind 傳遞。
      expect(find.byType(Draggable<ShapeKind>), findsWidgets);
      expect(find.byType(DragTarget<ShapeKind>), findsWidgets);
      expect(find.text('完成圖'), findsOneWidget);
    }
  });
}
