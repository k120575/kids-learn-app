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

/// 接下去（3-4 動腦）：一列重複規律的圖案（火車車廂），最後一節是問號，
/// 從下方選出「接下去」該接哪一個。
///
/// 發展理據：辨識並延續 AB / AABB 重複規律是學前 pattern 啟蒙的第一步，
/// 3-4 歲已能掌握。刻意不做抽象長序列（那是 4-5 找規律矩陣的事），
/// 只做「看得到的、短的、重複的」規律，讓孩子靠視覺節奏而非邏輯推理就能完成。
class NextInRowGame extends StatefulWidget {
  const NextInRowGame({
    super.key,
    required this.gameId,
    required this.title,
    this.rounds = 6,
  });

  final String gameId;
  final String title;
  final int rounds;

  @override
  State<NextInRowGame> createState() => _NextInRowGameState();
}

class _NextInRowGameState extends State<NextInRowGame> {
  // 顏色/造型對比鮮明，方便看出重複節奏。
  static const List<String> _pool = <String>[
    '🔴',
    '🔵',
    '🟡',
    '🟢',
    '🟣',
    '🟠',
    '🍎',
    '🍌',
    '🍇',
    '⭐',
    '🌸',
    '🐶',
    '🐱',
    '🚗',
  ];

  final Random _rng = Random();
  late List<String> _seq; // 已顯示的序列（不含問號格）
  late String _answer; // 接下去正解
  late List<String> _options;
  late int _correct;
  int _i = 0;
  bool _lock = false;
  bool _success = false;
  int _mistakes = 0;
  final Map<int, int> _wrong = <int, int>{};

  @override
  void initState() {
    super.initState();
    _gen();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice('接下去是什麼？'),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _gen() {
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    // 取兩或三種不同的基底圖案。
    final List<String> base = (List<String>.of(_pool)..shuffle(_rng));
    // 規律單元：簡單 AB、一般 AABB、挑戰 ABC。
    final List<String> unit;
    if (level == 0) {
      unit = <String>[base[0], base[1]]; // A B
    } else if (level == 1) {
      unit = <String>[base[0], base[0], base[1], base[1]]; // A A B B
    } else {
      unit = <String>[base[0], base[1], base[2]]; // A B C
    }
    // 顯示「兩個完整單元 + 下一單元的前幾格」，最後一格(問號)就是規律的下一個。
    final int shown = unit.length * 2 + (level == 1 ? 1 : 1);
    _seq = <String>[for (int k = 0; k < shown; k++) unit[k % unit.length]];
    _answer = unit[shown % unit.length];

    // 選項：正解 + 規律中用到的其他圖案（讓干擾「看起來合理」）。
    final Set<String> opt = <String>{_answer};
    for (final String b in unit) {
      opt.add(b);
    }
    while (opt.length < 3) {
      opt.add(base[opt.length]);
    }
    _options = opt.toList()..shuffle(_rng);
    _correct = _options.indexOf(_answer);
    _wrong.clear();
    _lock = false;
    _success = false;
  }

  Future<void> _onTap(int idx) async {
    if (_lock) return;
    if (idx == _correct) {
      setState(() {
        _lock = true;
        _success = true;
      });
      AudioService.instance.correct();
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (!mounted) return;
      if (_i < widget.rounds - 1) {
        setState(() {
          _i++;
          _gen();
        });
      } else {
        final bool again = await finishGame(
          context,
          widget.gameId,
          mistakes: _mistakes,
        );
        if (!mounted) return;
        if (again) {
          setState(() {
            _i = 0;
            _mistakes = 0;
            _gen();
          });
        } else {
          Navigator.of(context).maybePop();
        }
      }
    } else {
      AudioService.instance.wrong();
      _mistakes++;
      setState(() => _wrong[idx] = (_wrong[idx] ?? 0) + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: widget.title,
      current: _i,
      total: widget.rounds,
      onReplay: () => AudioService.instance.speak('接下去是什麼？'),
      child: Stack(
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // 規律列（火車）：整列等比縮放，不溢出。
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final String e in _seq)
                      _Car(
                        child: Text(
                          e,
                          style: TextStyle(fontSize: context.s(48)),
                        ),
                      ),
                    _Car(
                      dashed: true,
                      child: _success
                          ? Text(
                              _answer,
                              style: TextStyle(fontSize: context.s(48)),
                            )
                          : Text(
                              '❓',
                              style: TextStyle(fontSize: context.s(44)),
                            ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.s(20)),
              // 選項。
              Wrap(
                spacing: context.s(Sizes.bigGap),
                runSpacing: context.s(Sizes.gap),
                alignment: WrapAlignment.center,
                children: List<Widget>.generate(_options.length, (int idx) {
                  final bool win = _success && idx == _correct;
                  return Shaker(
                    trigger: _wrong[idx] ?? 0,
                    child: _Option(
                      emoji: _options[idx],
                      highlight: win,
                      onTap: () => _onTap(idx),
                    ),
                  );
                }),
              ),
            ],
          ),
          if (_success) const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }
}

/// 火車車廂格。
class _Car extends StatelessWidget {
  const _Car({required this.child, this.dashed = false});

  final Widget child;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.s(72),
      height: context.s(72),
      margin: EdgeInsets.all(context.s(4)),
      decoration: BoxDecoration(
        color: dashed ? const Color(0xFFF1F1F1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dashed ? const Color(0xFFBDBDBD) : Colors.grey.shade300,
          width: 3,
        ),
      ),
      child: Center(child: child),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.emoji,
    required this.onTap,
    required this.highlight,
  });

  final String emoji;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: context.s(110),
        height: context.s(110),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFC8E6C9) : Colors.white,
          borderRadius: BorderRadius.circular(Sizes.radius),
          border: Border.all(
            color: highlight ? const Color(0xFF4CAF50) : Colors.grey.shade300,
            width: highlight ? 6 : 3,
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
          child: Text(emoji, style: TextStyle(fontSize: context.s(64))),
        ),
      ),
    );
  }
}
