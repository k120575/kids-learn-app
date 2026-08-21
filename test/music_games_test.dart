import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learn_app/content/music_levels.dart';
import 'package:kids_learn_app/core/progress_store.dart';
import 'package:kids_learn_app/games/listen_choose_game.dart';

/// 音樂領域聽辨新遊戲（共用 ListenChooseGame 引擎）的煙霧測試：
/// 建構 → 跑過「念引導 + 播題（靜音後備）」→ 選項卡出現 → 點一張不崩。
/// 互動正確性（聽聲音選對屬性）靠真機；這裡顧「一打開就紅畫面」與題庫接線。
void main() {
  setUp(() async {
    await ProgressStore.instance.init(); // 無平台 → 純記憶體
    ProgressStore.instance.soundEnabled = false; // 走靜音後備，不呼叫 audioplayers
  });

  Widget wrap(String id, String title, String intro,
          List<SoundChoice> choices, List<SoundQuestion> questions,
          {bool vertical = false}) =>
      MaterialApp(
        home: ListenChooseGame(
          gameId: id,
          title: title,
          intro: intro,
          choices: choices,
          questions: questions,
          vertical: vertical,
        ),
      );

  /// 把引導語 + 第一題播放（靜音後備約 800ms）跑完，進到可作答狀態。
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(); // postframe → _runRound
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  final List<({String id, String title, String intro, List<SoundChoice> ch,
      List<SoundQuestion> q, bool v})> games = [
    (id: 'm_pitch', title: '高高低低', intro: '高低', ch: pitchHiLoChoices,
        q: pitchHiLoBank, v: true),
    (id: 'm_tempo', title: '快快慢慢', intro: '快慢', ch: tempoChoices,
        q: tempoBank, v: false),
    (id: 'm_dyn', title: '大聲小聲', intro: '大小', ch: dynamicsChoices,
        q: dynamicsBank, v: false),
    (id: 'm_dur', title: '音的長短', intro: '長短', ch: durationChoices,
        q: durationBank, v: false),
    (id: 'm_dir', title: '音往哪裡走', intro: '上下', ch: directionChoices,
        q: directionBank, v: true),
    (id: 'm_tune', title: '哪個音不對', intro: '對錯', ch: tuningChoices,
        q: tuningBank, v: false),
  ];

  for (final game in games) {
    testWidgets('${game.title}：建構 + 選項卡出現 + 可點', (WidgetTester tester) async {
      await tester.pumpWidget(
          wrap(game.id, game.title, game.intro, game.ch, game.q, vertical: game.v));
      await settle(tester);
      expect(tester.takeException(), isNull);
      // 用卡片 key 定位（標籤可能跟標題單字撞名，emoji 又可能被自訂圖示取代）。
      for (int k = 0; k < game.ch.length; k++) {
        expect(find.byKey(ValueKey<String>('choice_$k')), findsOneWidget);
      }
      // 點第一張卡：不論對錯都不應崩。點到正解會進下一題、重念歌名（測試環境
      // 取不到音檔長度 → 退回約 2.8 秒），pump 夠久把整串 timer 沖掉（避免
      // !timersPending）。pump 總時長要蓋過「850ms 慶祝 + 念歌名 + 播音效」。
      await tester.tap(find.byKey(const ValueKey<String>('choice_0')));
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull);
    });
  }

  test('每組題庫（含 hard 池）的正解索引都落在選項範圍內', () {
    void check(List<SoundChoice> ch, List<SoundQuestion> q) {
      for (final SoundQuestion x in q) {
        expect(x.answer, inInclusiveRange(0, ch.length - 1));
        expect(x.sfx.endsWith('.mp3'), isTrue);
      }
    }

    check(pitchHiLoChoices, pitchHiLoBank);
    check(tempoChoices, tempoBank);
    check(dynamicsChoices, dynamicsBank);
    check(durationChoices, durationBank);
    check(directionChoices, directionBank);
    check(tuningChoices, tuningBank);
    check(pitchHiLoChoices, pitchHiLoBankHard);
    check(tempoChoices, tempoBankHard);
    check(dynamicsChoices, dynamicsBankHard);
    check(durationChoices, durationBankHard);
    check(directionChoices, directionBankHard);
    check(tuningChoices, tuningBankHard);
  });

  test('hard 池用的是 *_h clip（「對的」melody_ok 沿用除外）', () {
    for (final List<SoundQuestion> bank in <List<SoundQuestion>>[
      pitchHiLoBankHard,
      tempoBankHard,
      dynamicsBankHard,
      durationBankHard,
      directionBankHard,
    ]) {
      for (final SoundQuestion q in bank) {
        expect(q.sfx, contains('_h'));
      }
    }
    for (final SoundQuestion q in tuningBankHard) {
      expect(q.sfx, q.answer == 1 ? contains('_h') : startsWith('melody_ok'));
    }
  });

  testWidgets('適性難度：挑戰階（level 2）改抽 hard 題池', (WidgetTester tester) async {
    // 全對一局 → 難度 1→2。
    await ProgressStore.instance.recordOutcome('m_adaptive', 0);
    expect(ProgressStore.instance.levelFor('m_adaptive'), 2);
    // base 題沒有歌名、hard 題掛歌名「挑戰」→ 畫面出現歌名牌＝抽到 hard 池。
    final List<SoundQuestion> base = <SoundQuestion>[
      const SoundQuestion('tone_hi1.mp3', 0),
    ];
    final List<SoundQuestion> hard = <SoundQuestion>[
      const SoundQuestion('tone_hi_h1.mp3', 0, name: '挑戰'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: ListenChooseGame(
        gameId: 'm_adaptive',
        title: '適性測試',
        intro: '引導',
        choices: pitchHiLoChoices,
        questions: base,
        hardQuestions: hard,
      ),
    ));
    await settle(tester);
    expect(find.textContaining('挑戰'), findsOneWidget);
    // 念歌名的靜音後備約 2.8s → 多 pump 把整串 timer 沖掉（避免 !timersPending）。
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
  });
}
