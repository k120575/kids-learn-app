import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learn_app/core/progress_store.dart';
import 'package:kids_learn_app/games/pick_game.dart';

void main() {
  testWidgets('PickGame：點對的圖會進到下一關', (WidgetTester tester) async {
    await ProgressStore.instance.init(); // 無平台 → 純記憶體

    // prompt 用沒烤過語音的字串：避免測試環境呼叫 audioplayers 外掛而卡住
    // （念題鎖會走 700ms 延遲分支後解除）。測的是遊戲邏輯，不是語音。
    const List<PickRound> rounds = <PickRound>[
      PickRound(prompt: 'zzz1', options: <String>['🍎', '🐶', '🚗', '🐱'], correctIndex: 1),
      PickRound(prompt: 'zzz2', options: <String>['🐟', '🚗', '🍌', '🐶'], correctIndex: 2),
    ];

    await tester.pumpWidget(const MaterialApp(
      home: PickGame(
          gameId: 'test_pick', title: '測試', rounds: rounds, shuffle: false),
    ));
    await tester.pump(); // 跑 postframe 的語音指示
    // 念題期間會鎖住作答（先聽完再選），pump 過語音時間讓鎖解除。
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // 第一關沒有香蕉
    expect(find.text('🍌'), findsNothing);

    // 點正解（小狗）
    await tester.tap(find.text('🐶'));
    // 充足 pump：讓 await（平台通道）與 Future.delayed 計時器都跑完
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // 已進到第二關（出現香蕉）
    expect(find.text('🍌'), findsOneWidget);
  });

  testWidgets('PickGame：點錯不會前進', (WidgetTester tester) async {
    await ProgressStore.instance.init(); // 無平台 → 純記憶體

    const List<PickRound> rounds = <PickRound>[
      PickRound(prompt: 'zzz1', options: <String>['🍎', '🐶', '🚗', '🐱'], correctIndex: 1),
      PickRound(prompt: 'zzz2', options: <String>['🐟', '🚗', '🍌', '🐶'], correctIndex: 2),
    ];

    await tester.pumpWidget(const MaterialApp(
      home: PickGame(
          gameId: 'test_pick2', title: '測試', rounds: rounds, shuffle: false),
    ));
    await tester.pump();
    // 念題期間會鎖住作答，pump 過語音時間讓鎖解除。
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // 點錯（蘋果）
    await tester.tap(find.text('🍎'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    // 仍停在第一關（沒有香蕉）
    expect(find.text('🍌'), findsNothing);
  });
}
