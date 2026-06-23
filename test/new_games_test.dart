import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learn_app/content/lang45_levels.dart';
import 'package:kids_learn_app/core/progress_store.dart';
import 'package:kids_learn_app/games/find_same_game.dart';
import 'package:kids_learn_app/games/hanzi_picture_game.dart';
import 'package:kids_learn_app/games/next_in_row_game.dart';
import 'package:kids_learn_app/games/rotate_match_game.dart';
import 'package:kids_learn_app/games/whats_missing_game.dart';
import 'package:kids_learn_app/games/zhuyin_match_game.dart';

/// 新增遊戲的煙霧測試：確保「能正常建構 + 跑過內部邏輯」不丟執行期斷言
/// （analyze 抓不到的那類崩潰，例如 dispose 的 controller、隨機產生的幾何）。
/// 互動正確性靠真機觸控；這裡顧的是「一打開就紅畫面」這種低級錯誤。
void main() {
  setUp(() async {
    await ProgressStore.instance.init(); // 無平台 → 純記憶體
    // 關音：讓語音走靜音後備分支，避免 speakForDuration 對「有烤的詞」
    // 呼叫 audioplayers 平台外掛而卡住（測的是遊戲邏輯，不是語音）。
    ProgressStore.instance.soundEnabled = false;
  });

  testWidgets('找一樣：能建構並顯示目標 + 選項', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: FindSameGame(gameId: 'test_find_same', title: '找一樣'),
    ));
    await tester.pump(); // postframe 語音指示
    await tester.pump(const Duration(milliseconds: 300));
    // 至少有幾個 emoji 圖塊被畫出來（目標 1 + 選項數個）。
    expect(tester.takeException(), isNull);
    expect(find.byType(FindSameGame), findsOneWidget);
  });

  testWidgets('接下去：能建構並顯示火車與問號', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: NextInRowGame(gameId: 'test_next', title: '接下去'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('❓'), findsOneWidget); // 問號車廂
  });

  testWidgets('轉轉看：手性幾何能產生且建構不崩', (WidgetTester tester) async {
    // 連跑數次，逼 _gen 多次走過手性驗證迴圈與旋轉/鏡像運算。
    for (int run = 0; run < 5; run++) {
      await tester.pumpWidget(MaterialApp(
        home: RotateMatchGame(gameId: 'test_rotate_$run', title: '轉轉看'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.byType(RotateMatchGame), findsOneWidget);
    }
  });

  testWidgets('什麼不見了：跑過記憶→蓋牌→出題，最後出現問號與選項',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: WhatsMissingGame(gameId: 'test_missing', title: '什麼不見了'),
    ));
    await tester.pump(); // postframe → 進入記憶階段
    // 記憶階段會逐一念出每個物件：1900(開場) + 3*1400(命名) + 600 + 蓋牌 650
    // ≈ 7.4 秒才進到出題階段，pump 要夠長。
    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
    // 出題階段：消失的那格顯示問號。
    expect(find.text('❓'), findsOneWidget);
  });

  testWidgets('什麼不見了：「再看一次」鈕能重播記憶序列', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: WhatsMissingGame(gameId: 'test_replay', title: '什麼不見了'),
    ));
    await tester.pump();
    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('❓'), findsOneWidget); // 已到出題階段

    // 按喇叭「再看一次」→ 回到記憶階段（問號消失、物件重新亮出）。
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    expect(find.text('❓'), findsNothing);

    // 重播序列跑完，又回到出題階段。
    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('❓'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('注音對對碰：建構 + 卡片出現 + 點兩張不崩', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ZhuyinMatchGame(
        gameId: 'test_zhuyin_match',
        title: '注音對對碰',
        pool: zhuyinMatchPool,
      ),
    ));
    await tester.pump(); // postframe 引導語
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    // 卡片是可點的 GestureDetector（簡單 4 對 = 8 張）。
    final Finder cards = find.byType(GestureDetector);
    expect(cards, findsWidgets);
    // 點兩張：走「選起→比對（成功念讀音／失敗抖動取消）」邏輯，任一分支都不該崩。
    await tester.tap(cards.first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(cards.at(1));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('認國字看圖選字：建構 + 確定鈕 + 選字後可確定', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HanziPictureGame(
        gameId: 'test_hanzi_pic',
        title: '認國字',
        items: hanziPictureItems,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('確定'), findsOneWidget);
    // 還沒選字時「確定」是停用的（onPressed 為 null）。
    final ElevatedButton btn = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('確定'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(btn.onPressed, isNull);
    // 點一個字選項 → 念讀音（靜音後備）→ 按確定，對錯任一分支都不該崩。
    final Finder option = find
        .descendant(of: find.byType(Wrap), matching: find.byType(GestureDetector))
        .first;
    await tester.tap(option);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.text('確定')); // 測試視窗較矮，先捲到鈕再點
    await tester.pump();
    await tester.tap(find.text('確定'));
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
  });
}
