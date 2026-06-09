import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/game_complete.dart';
import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/celebration.dart';
import '../core/widgets/game_scaffold.dart';
import '../core/widgets/shaker.dart';

/// 一個「聽提示→從選項中點出正解」的回合。
class PickRound {
  const PickRound({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.soundAsset,
  });

  /// 會被 TTS 念出來的提示（例如「找出貓咪」）。
  final String prompt;

  /// 選項（emoji 大圖）。
  final List<String> options;

  final int correctIndex;

  /// 真實音效檔名（assets/sfx/<檔名>）。有設就播音效取代念提示；
  /// 缺檔時自動退回念 [prompt]。用於聲音尋寶（動物聲）、樂器配對（樂器聲）。
  final String? soundAsset;
}

/// 「找出X」題庫：(詞, emoji) 清單 → 每題念「找出 + 詞」、選項 = 正解 + 3 干擾。
List<PickRound> buildListenRounds(List<(String, String)> vocab,
    [String prefix = '找出']) {
  final Random rng = Random();
  final List<PickRound> bank = <PickRound>[];
  for (int i = 0; i < vocab.length; i++) {
    final Set<int> others = <int>{};
    while (others.length < 3 && others.length < vocab.length - 1) {
      final int j = rng.nextInt(vocab.length);
      if (j != i) others.add(j);
    }
    final List<String> opts = <String>[
      vocab[i].$2,
      for (final int j in others) vocab[j].$2,
    ]..shuffle(rng);
    bank.add(PickRound(
      prompt: '$prefix${vocab[i].$1}',
      options: opts,
      correctIndex: opts.indexOf(vocab[i].$2),
    ));
  }
  return bank;
}

/// 分類找不同題庫：每題取 3 個同類 + 1 個不同類，正解 = 那個不同類的。
List<PickRound> buildOddOneOut(List<List<String>> cats, {int count = 30}) {
  final Random rng = Random();
  final List<PickRound> bank = <PickRound>[];
  for (int k = 0; k < count; k++) {
    final int ci = rng.nextInt(cats.length);
    int cj;
    do {
      cj = rng.nextInt(cats.length);
    } while (cj == ci);
    final List<String> picks =
        (List<String>.of(cats[ci])..shuffle(rng)).take(3).toList();
    final String odd = cats[cj][rng.nextInt(cats[cj].length)];
    final List<String> opts = <String>[...picks, odd]..shuffle(rng);
    bank.add(PickRound(
      prompt: '哪一個不一樣？',
      options: opts,
      correctIndex: opts.indexOf(odd),
    ));
  }
  return bank;
}

/// 從「(音檔, emoji)」清單建立題庫：每題播該音檔，選項 = 正解 emoji + [distractors] 個隨機干擾。
/// 用於聲音尋寶、樂器配對等以真實音效出題的遊戲。
/// [distractors] 預設 3（共 4 選項）；5-6 歲加難版可給 4（共 5 選項、更難辨）。
List<PickRound> buildSoundRounds(List<(String, String)> items, String prompt,
    {int distractors = 3}) {
  final Random rng = Random();
  final List<PickRound> bank = <PickRound>[];
  for (int i = 0; i < items.length; i++) {
    final Set<int> others = <int>{};
    while (others.length < distractors && others.length < items.length - 1) {
      final int j = rng.nextInt(items.length);
      if (j != i) others.add(j);
    }
    final List<String> opts = <String>[
      items[i].$2,
      for (final int j in others) items[j].$2,
    ]..shuffle(rng);
    bank.add(PickRound(
      prompt: prompt,
      soundAsset: items[i].$1,
      options: opts,
      correctIndex: opts.indexOf(items[i].$2),
    ));
  }
  return bank;
}

/// 通用引擎：聽音指圖 / 聲音尋寶 / 樂器配對等「點選正確圖」類遊戲共用。
/// 新增同類遊戲只要提供一組 [rounds] 資料即可，不需新程式。
class PickGame extends StatefulWidget {
  const PickGame({
    super.key,
    required this.gameId,
    required this.title,
    required this.rounds,
    this.shuffle = true,
    this.pickCount,
    this.hard = false,
  });

  final String gameId;
  final String title;

  /// 整個題庫。
  final List<PickRound> rounds;

  /// 是否隨機打亂題序（測試時關閉以保持確定性）。
  final bool shuffle;

  /// 每次遊戲從題庫隨機抽幾題（null = 全部）。題庫大時用它控制單局長度。
  final int? pickCount;

  /// 加難模式（5-6 歲）：選項上限調高（一般 3/4 → 加難 4/5），多一個干擾項更難辨。
  final bool hard;

  @override
  State<PickGame> createState() => _PickGameState();
}

class _PickGameState extends State<PickGame> {
  int _i = 0;
  bool _lock = false;
  bool _success = false;
  bool _speaking = false; // 題目語音/音效播放中 → 暫不開放作答（先聽完再選）
  int _mistakes = 0; // 本局累計答錯次數（用於分級星星）
  final Map<int, int> _wrong = <int, int>{};

  /// 本題累計答錯次數；達 3 次就輕輕高亮正解，避免孩子卡住。
  int get _wrongCount => _wrong.values.fold<int>(0, (int a, int b) => a + b);

  late List<PickRound> _rounds;

  PickRound get _round => _rounds[_i];

  /// 把一題的選項數縮減到 [cap]（保留正解），用於「簡單」難度減少干擾項。
  PickRound _capOptions(PickRound r, int cap) {
    if (r.options.length <= cap) return r;
    final String correct = r.options[r.correctIndex];
    final List<String> others = <String>[
      for (int i = 0; i < r.options.length; i++)
        if (i != r.correctIndex) r.options[i]
    ]..shuffle();
    final List<String> keep = others.take(cap - 1).toList()..add(correct);
    keep.shuffle();
    return PickRound(
      prompt: r.prompt,
      options: keep,
      correctIndex: keep.indexOf(correct),
      soundAsset: r.soundAsset,
    );
  }

  void _prepareRounds() {
    _mistakes = 0;
    // 適性難度：簡單少一個干擾，一般／挑戰維持滿。加難模式整體再 +1 選項。
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    final int base = level == 0 ? 3 : 4;
    final int cap = widget.hard ? base + 1 : base;
    _rounds = List<PickRound>.of(widget.rounds);
    if (widget.shuffle) _rounds.shuffle(); // 隨機順序
    final int? n = widget.pickCount;
    if (n != null && n < _rounds.length) {
      _rounds = _rounds.sublist(0, n); // 隨機抽 N 題
    }
    _rounds =
        _rounds.map((PickRound r) => _capOptions(r, cap)).toList();
  }

  @override
  void initState() {
    super.initState();
    _prepareRounds();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakGated());
  }

  @override
  void dispose() {
    AudioService.instance.stop(); // 離開時停止語音
    super.dispose();
  }

  /// 念題（或播音效）並「等播完」。先聽完才作答，是聽辨類遊戲的核心。
  Future<void> _speak() async {
    final PickRound r = _round;
    if (r.soundAsset != null) {
      final bool ok = await AudioService.instance.playSfxAndWait(r.soundAsset!);
      if (ok) return; // 有真實音效就用音效（已等播完）
    }
    await AudioService.instance
        .speakForDuration(r.prompt, extra: const Duration(milliseconds: 250));
  }

  /// 念題期間鎖住互動（_speaking），念完才開放作答。
  Future<void> _speakGated() async {
    if (!mounted) return;
    setState(() => _speaking = true);
    await _speak();
    if (!mounted) return;
    setState(() => _speaking = false);
  }

  Future<void> _onTap(int idx) async {
    if (_lock || _speaking) return; // 念題中不開放作答
    if (idx == _round.correctIndex) {
      setState(() {
        _lock = true;
        _success = true;
      });
      AudioService.instance.correct(); // 回饋，不 await（不可阻塞流程）
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (!mounted) return;
      if (_i < _rounds.length - 1) {
        setState(() {
          _i++;
          _lock = false;
          _success = false;
          _wrong.clear();
        });
        _speakGated();
      } else {
        await _finish();
      }
    } else {
      AudioService.instance.wrong();
      _mistakes++;
      setState(() => _wrong[idx] = (_wrong[idx] ?? 0) + 1);
    }
  }

  Future<void> _finish() async {
    final bool again = await finishGame(context, widget.gameId,
        mistakes: _mistakes);
    if (!mounted) return;
    if (again) {
      setState(() {
        _prepareRounds(); // 再玩一次重新抽題
        _i = 0;
        _lock = false;
        _success = false;
        _wrong.clear();
      });
      _speakGated();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final PickRound round = _round;
    return GameScaffold(
      title: widget.title,
      current: _i,
      total: _rounds.length,
      onReplay: _speakGated,
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(Sizes.gap),
            child: Center(
              child: SingleChildScrollView(
                // 念題中淡化選項，提示孩子「先聽，聽完再選」。
                child: AnimatedOpacity(
                  opacity: _speaking ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Wrap(
                  spacing: Sizes.bigGap,
                  runSpacing: Sizes.bigGap,
                  alignment: WrapAlignment.center,
                  children:
                      List<Widget>.generate(round.options.length, (int idx) {
                    final bool win = _success && idx == round.correctIndex;
                    return Shaker(
                      trigger: _wrong[idx] ?? 0,
                      child: _OptionTile(
                        emoji: round.options[idx],
                        highlight: win,
                        hint: !win &&
                            idx == round.correctIndex &&
                            _wrongCount >= 3,
                        onTap: () => _onTap(idx),
                      ),
                    );
                  }),
                  ),
                ),
              ),
            ),
          ),
          if (_success) const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.emoji,
    required this.onTap,
    required this.highlight,
    this.hint = false,
  });

  final String emoji;
  final VoidCallback onTap;
  final bool highlight; // 答對：綠色
  final bool hint; // 答錯多次：琥珀色輕提示正解

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: context.s(150),
        height: context.s(150),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFC8E6C9)
              : (hint ? const Color(0xFFFFF8E1) : Colors.white),
          borderRadius: BorderRadius.circular(Sizes.radius),
          border: Border.all(
            color: highlight
                ? const Color(0xFF4CAF50)
                : (hint ? const Color(0xFFFFC107) : Colors.grey.shade300),
            width: highlight ? 6 : (hint ? 5 : 3),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(emoji, style: TextStyle(fontSize: context.s(84))),
        ),
      ),
    );
  }
}
