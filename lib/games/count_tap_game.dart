import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/game_complete.dart';
import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/celebration.dart';
import '../core/widgets/fit_box.dart';
import '../core/widgets/game_scaffold.dart';
import '../core/widgets/shaker.dart';

class CountRound {
  const CountRound({required this.emoji, required this.count});
  final String emoji;
  final int count;
}

/// 數數點點（3-4 歲）：螢幕上有 N 個東西（不能點），數一數有幾個，
/// 從下方 3 個數字裡選出正確的數量。建立「數量 → 數字」對應概念。
class CountTapGame extends StatefulWidget {
  const CountTapGame({
    super.key,
    required this.gameId,
    required this.title,
    required this.rounds,
    this.pickCount,
  });

  final String gameId;
  final String title;
  final List<CountRound> rounds;

  /// 每次從題庫隨機抽幾題（null = 全部）。
  final int? pickCount;

  @override
  State<CountTapGame> createState() => _CountTapGameState();
}

class _CountTapGameState extends State<CountTapGame> {
  static const String _intro = '數一數，有幾個呢？';

  final Random _rng = Random();
  int _i = 0;
  late List<CountRound> _rounds;

  late List<int> _options; // 本題 3 個數字選項
  int? _selected; // 目前選到的索引（答對才會留著）
  final Set<int> _ruledOut = <int>{}; // 選錯被劃掉的選項
  int _shake = 0;
  bool _success = false;
  bool _lock = false;
  int _mistakes = 0;

  CountRound get _round => _rounds[_i];

  void _prepareRounds() {
    // 適性難度：簡單只出 5 以內、一般 10 以內、挑戰不設限。
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    final int cap = level == 0 ? 5 : (level == 1 ? 10 : 1 << 30);
    List<CountRound> pool = widget.rounds
        .where((CountRound r) => r.count <= cap)
        .toList();
    if (pool.isEmpty) pool = List<CountRound>.of(widget.rounds);
    _rounds = pool..shuffle(_rng);
    final int? n = widget.pickCount;
    if (n != null && n < _rounds.length) {
      _rounds = _rounds.sublist(0, n);
    }
  }

  /// 產生 3 個數字選項：正解 + 2 個鄰近干擾項（都 ≥1、互異）。
  void _genOptions() {
    final int c = _round.count;
    final Set<int> opts = <int>{c};
    while (opts.length < 3) {
      final int delta = 1 + _rng.nextInt(4); // 差 1~4
      final int v = _rng.nextBool() ? c + delta : c - delta;
      if (v >= 1) opts.add(v);
    }
    _options = opts.toList()..shuffle(_rng);
    _selected = null;
    _ruledOut.clear();
    _success = false;
    _lock = false;
  }

  @override
  void initState() {
    super.initState();
    _prepareRounds();
    _genOptions();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice(_intro),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  Future<void> _tap(int idx) async {
    if (_lock || _ruledOut.contains(idx)) return;
    final int v = _options[idx];
    if (v == _round.count) {
      setState(() {
        _selected = idx;
        _success = true;
        _lock = true;
      });
      AudioService.instance.correct();
      // 等鼓勵音效，再唸「一共 N 個！」幫孩子把數量說出來。
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      AudioService.instance.speak('一共 ${_round.count} 個！');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      if (_i < _rounds.length - 1) {
        setState(() {
          _i++;
          _genOptions();
        });
        AudioService.instance.speak(_intro);
      } else {
        await _finish();
      }
    } else {
      // 選錯：把這個數字劃掉、抖一下，讓孩子再數再選（不換題）。
      _mistakes++;
      AudioService.instance.wrong();
      setState(() {
        _ruledOut.add(idx);
        _shake++;
      });
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
        _prepareRounds();
        _i = 0;
        _mistakes = 0;
        _genOptions();
      });
      AudioService.instance.speak(_intro);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// 一列 [n] 個 emoji，置中。
  Widget _emojiRow(BuildContext context, String emoji, int n) {
    return Wrap(
      spacing: context.s(Sizes.bigGap),
      runSpacing: context.s(Sizes.bigGap),
      alignment: WrapAlignment.center,
      children: List<Widget>.generate(
        n,
        (int idx) =>
            Text(emoji, style: TextStyle(fontSize: context.s(72))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CountRound round = _round;
    return GameScaffold(
      title: widget.title,
      current: _i,
      total: _rounds.length,
      onReplay: () => AudioService.instance.speak(_intro),
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              // 上方：要數的東西（不能點，純展示）。上下兩列平均排
              // （8 個→上4下4、7 個→上4下3），看起來整齊不雜亂。
              Expanded(
                child: FitBox(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _emojiRow(context, round.emoji, (round.count / 2).ceil()),
                      if (round.count > 1)
                        SizedBox(height: context.s(Sizes.bigGap)),
                      if (round.count > 1)
                        _emojiRow(
                          context,
                          round.emoji,
                          round.count - (round.count / 2).ceil(),
                        ),
                    ],
                  ),
                ),
              ),
              // 下方：三個數字選項。
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.s(Sizes.gap),
                  context.s(8),
                  context.s(Sizes.gap),
                  context.s(Sizes.gap),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List<Widget>.generate(_options.length, (int idx) {
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.s(Sizes.gap / 2),
                      ),
                      child: Shaker(
                        trigger: _ruledOut.contains(idx) ? _shake : 0,
                        child: _NumberTile(
                          number: _options[idx],
                          ruledOut: _ruledOut.contains(idx),
                          correct: _success && _selected == idx,
                          onTap: () => _tap(idx),
                        ),
                      ),
                    );
                  }),
                  ),
                ),
              ),
            ],
          ),
          if (_success) const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }
}

class _NumberTile extends StatelessWidget {
  const _NumberTile({
    required this.number,
    required this.ruledOut,
    required this.correct,
    required this.onTap,
  });

  final int number;
  final bool ruledOut; // 選錯被劃掉（灰）
  final bool correct; // 答對（綠）
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = correct
        ? const Color(0xFFC8E6C9)
        : (ruledOut ? const Color(0xFFEEEEEE) : Colors.white);
    final Color border = correct
        ? const Color(0xFF4CAF50)
        : (ruledOut ? Colors.grey.shade400 : const Color(0xFFFFC107));
    return GestureDetector(
      onTap: ruledOut ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: context.s(110),
        height: context.s(110),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Sizes.radius),
          border: Border.all(color: border, width: correct ? 6 : 3),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: context.s(56),
              fontWeight: FontWeight.bold,
              color: ruledOut
                  ? Colors.grey.shade500
                  : const Color(0xFF37474F),
            ),
          ),
        ),
      ),
    );
  }
}
