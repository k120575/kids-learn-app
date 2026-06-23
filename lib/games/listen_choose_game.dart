import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/game_complete.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/celebration.dart';
import '../core/widgets/game_scaffold.dart';
import '../core/widgets/shaker.dart';

/// 一個固定的「答案卡」：大圖示 + 文字標籤（例如 🐦 高、🐘 低）。
/// 圖示預設用 [emoji]；需要更精準的概念圖（如長音/短音的色條）時給 [child] 取代。
class SoundChoice {
  const SoundChoice(this.emoji, this.label, {this.child});
  final String emoji;
  final String label;

  /// 自訂圖示 widget（取代 emoji）。例如音的長短用「一條長 / 兩條短」的色條。
  final Widget? child;
}

/// 一題：播一段 sfx 音檔，正解 = [answer]（對應 choices 的索引）。
/// [name] 有值時，播音前會先「念出並顯示」這個名字（哪個音不對：先報歌名，
/// 孩子才有「正確版本」的參照可比對走音）。
class SoundQuestion {
  const SoundQuestion(this.sfx, this.answer, {this.name});
  final String sfx;
  final int answer;
  final String? name;
}

/// 音樂領域聽辨遊戲的共用引擎：
/// 「聽一段聲音 → 從幾張固定的答案卡中，點出這段聲音屬於哪一種」。
///
/// 與 PickGame 的差別：答案卡是**整關固定的屬性**（高/低、快/慢、大聲/小聲…），
/// 不是每題不同的圖；而且幼兒不會自己知道「高的聲音要點小鳥」，所以多了一句
/// **開場引導語**（進關第一題前念一次）。音訊時序、適性、慶祝、重播沿用既有做法。
///
/// 答案卡固定不洗牌：高高的鳥永遠在上、低低的象永遠在下——這個「位置＝屬性」的
/// 一致對應本身就是要教的東西（孩子靠聽聲音決定點上或下，位置不變才學得起來）。
class ListenChooseGame extends StatefulWidget {
  const ListenChooseGame({
    super.key,
    required this.gameId,
    required this.title,
    required this.intro,
    required this.choices,
    required this.questions,
    this.pickCount = 8,
    this.vertical = false,
    this.repeats = 1,
  });

  final String gameId;
  final String title;

  /// 進關第一題前念一次的引導語（例如「高高的聲音點小鳥，低低的聲音點大象」）。
  final String intro;

  /// 固定的答案卡（2~3 張）。
  final List<SoundChoice> choices;

  /// 題庫：每題播一段 sfx，正解對應某張答案卡。
  final List<SoundQuestion> questions;

  /// 每局抽幾題。
  final int pickCount;

  /// 答案卡是否縱向排列（高/低、上/下用縱向，強化「位置＝音高」）。
  final bool vertical;

  /// 每題把聲音連播幾次（間隔約 0.7 秒）。高高低低、大聲小聲是「一顆短音」，
  /// 幼兒一次可能聽不清，連播 3 次更容易聽辨；其他關（快慢/長短/方向）維持 1。
  final int repeats;

  @override
  State<ListenChooseGame> createState() => _ListenChooseGameState();
}

class _ListenChooseGameState extends State<ListenChooseGame> {
  final Random _rng = Random();
  late List<SoundQuestion> _qs;
  int _i = 0;
  bool _lock = false;
  bool _success = false;
  bool _speaking = false; // 播題目聲音中 → 先聽完再作答
  bool _introDone = false; // 開場引導語是否已念過
  int _mistakes = 0;
  final Map<int, int> _wrong = <int, int>{}; // 本題各選項答錯次數（給抖動 + 提示）

  int get _wrongCount => _wrong.values.fold<int>(0, (int a, int b) => a + b);

  SoundQuestion get _q => _qs[_i];

  void _prepare() {
    _mistakes = 0;
    _qs = List<SoundQuestion>.of(widget.questions)..shuffle(_rng);
    if (widget.pickCount < _qs.length) {
      _qs = _qs.sublist(0, widget.pickCount);
    }
  }

  @override
  void initState() {
    super.initState();
    _prepare();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runRound());
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  /// 念引導語（僅第一題）→（有歌名就先報歌名）→ 播這題的聲音。期間鎖住作答。
  Future<void> _runRound() async {
    if (!mounted) return;
    setState(() => _speaking = true);
    await AudioService.instance.waitUntilVoiceIdle(); // 先讓關卡名稱/上一句念完
    if (!mounted) return; // 等待時若已離開關卡，別再出聲
    if (!_introDone) {
      _introDone = true;
      await AudioService.instance.speakForDuration(
        widget.intro,
        extra: const Duration(milliseconds: 350),
      );
      if (!mounted) return;
    }
    await _announceAndPlay();
  }

  /// 先念歌名（若有）再播該題音檔；依 [widget.repeats] 連播數次（間隔約 0.7 秒）。
  /// 哪個音不對用：報歌名給孩子當參照。
  Future<void> _announceAndPlay() async {
    final String? name = _q.name;
    if (name != null) {
      await AudioService.instance.speakForDuration(
        name,
        extra: const Duration(milliseconds: 250),
      );
      if (!mounted) return;
    }
    for (int r = 0; r < widget.repeats; r++) {
      if (r > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
      }
      await AudioService.instance.playSfxAndWait(_q.sfx);
      if (!mounted) return;
    }
    setState(() => _speaking = false);
  }

  /// 重播：重念歌名（若有）並重播這題的聲音（不重念引導語）。
  Future<void> _replay() async {
    if (_speaking || _lock) return;
    setState(() => _speaking = true);
    await _announceAndPlay();
  }

  Future<void> _onTap(int idx) async {
    if (_lock || _speaking) return;
    if (idx == _q.answer) {
      setState(() {
        _lock = true;
        _success = true;
      });
      AudioService.instance.correct();
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (!mounted) return;
      if (_i < _qs.length - 1) {
        setState(() {
          _i++;
          _lock = false;
          _success = false;
          _wrong.clear();
        });
        _runRound();
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
    final bool again = await finishGame(
      context,
      widget.gameId,
      mistakes: _mistakes,
    );
    if (!mounted) return;
    if (again) {
      setState(() {
        _prepare();
        _i = 0;
        _lock = false;
        _success = false;
        _introDone = true; // 再玩一次不重念引導
        _wrong.clear();
      });
      _runRound();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = List<Widget>.generate(widget.choices.length, (
      int idx,
    ) {
      final bool win = _success && idx == _q.answer;
      return Shaker(
        key: ValueKey<String>('choice_$idx'),
        trigger: _wrong[idx] ?? 0,
        child: _ChoiceCard(
          choice: widget.choices[idx],
          highlight: win,
          hint: !win && idx == _q.answer && _wrongCount >= 3,
          dense: widget.vertical, // 縱向兩張卡疊著：縮小一點讓兩張都看得到、不必捲動
          onTap: () => _onTap(idx),
        ),
      );
    });

    return GameScaffold(
      title: widget.title,
      current: _i,
      total: _qs.length,
      onReplay: _replay,
      child: Stack(
        children: <Widget>[
          Center(
            child: SingleChildScrollView(
              child: AnimatedOpacity(
                opacity: _speaking ? 0.4 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // 歌名牌（哪個音不對才有）：寫出這首歌叫什麼，配合語音報名。
                    if (_q.name != null) ...<Widget>[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.s(20),
                          vertical: context.s(10),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(Sizes.radius),
                        ),
                        child: Text(
                          '🎵 ${_q.name}',
                          style: TextStyle(
                            fontSize: context.s(28),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFB8860B),
                          ),
                        ),
                      ),
                      SizedBox(height: context.s(16)),
                    ],
                    // 喇叭提示：先聽，聽完再選
                    Icon(
                      _speaking
                          ? Icons.volume_up_rounded
                          : Icons.touch_app_rounded,
                      size: context.s(40),
                      color: const Color(0xFF8E24AA),
                    ),
                    SizedBox(height: context.s(8)),
                    Text(
                      _speaking ? '仔細聽…' : '是哪一種呢？',
                      style: TextStyle(
                        fontSize: context.s(22),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: context.s(widget.vertical ? 10 : 20)),
                    if (widget.vertical)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _spaced(cards, vertical: true),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _spaced(cards, vertical: false),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_success) const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }

  /// 在卡片之間插入間距。
  List<Widget> _spaced(List<Widget> cards, {required bool vertical}) {
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < cards.length; i++) {
      out.add(cards[i]);
      if (i != cards.length - 1) {
        out.add(
          SizedBox(
            width: vertical ? 0 : context.s(Sizes.bigGap),
            height: vertical ? context.s(Sizes.bigGap) : 0,
          ),
        );
      }
    }
    return out;
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.choice,
    required this.onTap,
    required this.highlight,
    this.hint = false,
    this.dense = false,
  });

  final SoundChoice choice;
  final VoidCallback onTap;
  final bool highlight; // 答對：綠色
  final bool hint; // 答錯多次：琥珀色輕提示正解
  final bool dense; // 縱向排列時用較小尺寸，讓兩張卡都進得了畫面

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: context.s(dense ? 200 : 180),
        padding: EdgeInsets.symmetric(
          vertical: context.s(dense ? 8 : 16),
          horizontal: context.s(12),
        ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            choice.child ??
                Text(
                  choice.emoji,
                  style: TextStyle(fontSize: context.s(dense ? 50 : 72)),
                ),
            SizedBox(height: context.s(dense ? 2 : 6)),
            Text(
              choice.label,
              style: TextStyle(
                fontSize: context.s(22),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5C6BC0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 音的長短專用圖示：用「色條的長度／數量」直接表達時值——
/// 長音＝一條長橫桿（聲音拉得久）；短音＝兩條短橫桿（兩個快快的短聲）。
/// 比「一個音符 vs 兩個音符」更能讓孩子把『長度』和『持續時間』連起來。
class DurationGlyph extends StatelessWidget {
  const DurationGlyph({super.key, required this.long});

  /// true＝一條長桿（長音）；false＝兩條短桿（短音）。
  final bool long;

  @override
  Widget build(BuildContext context) {
    const Color c = Color(0xFF42A5F5);
    Widget bar(double widthUnits) => Container(
      width: context.s(widthUnits),
      height: context.s(26),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(context.s(13)),
      ),
    );
    return SizedBox(
      height: context.s(72), // 與 emoji 卡等高，兩種卡片大小一致
      child: Center(
        child: long
            ? bar(150)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  bar(44),
                  SizedBox(width: context.s(22)),
                  bar(44),
                ],
              ),
      ),
    );
  }
}
