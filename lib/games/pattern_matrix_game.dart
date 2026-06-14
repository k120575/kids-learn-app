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

/// 找規律：一串重複規律的圖案，藏住一格，從選項選出該補上的（邏輯推理）。
class PatternMatrixGame extends StatefulWidget {
  const PatternMatrixGame({
    super.key,
    required this.gameId,
    required this.title,
    this.length = 6,
    this.rounds = 8,
  });

  final String gameId;
  final String title;
  final int length;
  final int rounds;

  @override
  State<PatternMatrixGame> createState() => _PatternMatrixGameState();
}

class _PatternMatrixGameState extends State<PatternMatrixGame> {
  static const List<String> _pool = <String>[
    '🔴',
    '🔵',
    '🟡',
    '🟢',
    '🟣',
    '🟠',
    '⭐',
    '❤️',
    '🔺',
    '⬛',
  ];

  final Random _rng = Random();
  late List<String> _seq;
  late int _hidden;
  late String _ans;
  late List<String> _opts;
  int _i = 0;
  bool _lock = false;
  bool _success = false;
  int _mistakes = 0;
  late int _unitMax; // 2 或 3：規律單位最多幾個一組
  late int _len; // 序列長度

  final Map<int, int> _wrong = <int, int>{};

  /// 本題累計答錯次數；達 3 次就輕輕高亮正解，避免孩子卡住。
  int get _wrongCount => _wrong.values.fold<int>(0, (int a, int b) => a + b);

  @override
  void initState() {
    super.initState();
    // 適性難度：簡單（2 個一組、長 5）、一般（依設定）、挑戰（最多 3 個一組、長 8）。
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    _unitMax = level == 0 ? 2 : 3;
    _len = level == 0 ? 5 : (level == 1 ? widget.length : 8);
    _gen();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice('找出規律，補上空格！'),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _gen() {
    final int unit = 2 + _rng.nextInt(_unitMax - 1); // 2 或 3 個一組
    final List<String> tokens = (List<String>.of(
      _pool,
    )..shuffle(_rng)).take(unit).toList();
    _seq = <String>[for (int i = 0; i < _len; i++) tokens[i % unit]];
    _hidden = _rng.nextInt(_len);
    _ans = _seq[_hidden];
    final Set<String> opts = <String>{_ans, ...tokens};
    while (opts.length < 4) {
      opts.add(_pool[_rng.nextInt(_pool.length)]);
    }
    _opts = opts.toList()..shuffle(_rng);
    _lock = false;
    _success = false;
  }

  Future<void> _onTap(String v, int idx) async {
    if (_lock) return;
    if (v == _ans) {
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
          _wrong.clear();
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
            _wrong.clear();
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
      onReplay: () => AudioService.instance.speak('找出規律，補上空格！'),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(context.s(Sizes.gap)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // 規律序列
                Wrap(
                  spacing: context.s(8),
                  runSpacing: context.s(8),
                  alignment: WrapAlignment.center,
                  children: List<Widget>.generate(_seq.length, (int i) {
                    final bool hidden = i == _hidden;
                    return Container(
                      width: context.s(66),
                      height: context.s(66),
                      decoration: BoxDecoration(
                        color: hidden ? const Color(0xFFFFF3CD) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: hidden
                              ? const Color(0xFFFFC107)
                              : Colors.grey.shade300,
                          width: hidden ? 4 : 2,
                        ),
                      ),
                      child: Center(
                        child: hidden
                            ? Icon(
                                Icons.help_rounded,
                                size: context.s(36),
                                color: const Color(0xFFFFB300),
                              )
                            : Text(
                                _seq[i],
                                style: TextStyle(fontSize: context.s(38)),
                              ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: context.s(Sizes.bigGap)),
                Text(
                  '選一個補上空格',
                  style: TextStyle(
                    fontSize: context.s(18),
                    color: const Color(0xFF888888),
                  ),
                ),
                SizedBox(height: context.s(10)),
                // 選項
                Wrap(
                  spacing: context.s(Sizes.gap),
                  runSpacing: context.s(Sizes.gap),
                  alignment: WrapAlignment.center,
                  children: List<Widget>.generate(_opts.length, (int idx) {
                    final String v = _opts[idx];
                    final bool win = _success && v == _ans;
                    final bool hint = !win && v == _ans && _wrongCount >= 3;
                    return Shaker(
                      trigger: _wrong[idx] ?? 0,
                      child: GestureDetector(
                        onTap: () => _onTap(v, idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: context.s(96),
                          height: context.s(96),
                          decoration: BoxDecoration(
                            color: win
                                ? const Color(0xFFC8E6C9)
                                : (hint
                                      ? const Color(0xFFFFF8E1)
                                      : Colors.white),
                            borderRadius: BorderRadius.circular(Sizes.radius),
                            border: Border.all(
                              color: win
                                  ? const Color(0xFF4CAF50)
                                  : (hint
                                        ? const Color(0xFFFFC107)
                                        : Colors.grey.shade300),
                              width: win ? 6 : (hint ? 5 : 3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              v,
                              style: TextStyle(fontSize: context.s(48)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          if (_success) const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }
}
