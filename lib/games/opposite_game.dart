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

/// 反義詞配對：顯示一個圖，從選項中選出「相反」的那個。
class OppositeGame extends StatefulWidget {
  const OppositeGame({
    super.key,
    required this.gameId,
    required this.title,
    required this.pairs,
    this.rounds = 10,
  });

  final String gameId;
  final String title;
  final List<(String, String)> pairs; // 相反詞配對（emoji）
  final int rounds;

  @override
  State<OppositeGame> createState() => _OppositeGameState();
}

class _OppositeGameState extends State<OppositeGame> {
  final Random _rng = Random();
  late final List<String> _all =
      widget.pairs.expand((p) => <String>[p.$1, p.$2]).toList();
  late String _prompt;
  late String _answer;
  late List<String> _opts;
  int _i = 0;
  bool _lock = false;
  bool _success = false;
  int _mistakes = 0;
  final Map<int, int> _wrong = <int, int>{};

  /// 本題累計答錯次數；達 3 次就輕輕高亮正解，避免孩子卡住。
  int get _wrongCount => _wrong.values.fold<int>(0, (int a, int b) => a + b);

  @override
  void initState() {
    super.initState();
    _gen();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice('找出相反的！'),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _gen() {
    final (String, String) pair = widget.pairs[_rng.nextInt(widget.pairs.length)];
    if (_rng.nextBool()) {
      _prompt = pair.$1;
      _answer = pair.$2;
    } else {
      _prompt = pair.$2;
      _answer = pair.$1;
    }
    final Set<String> opts = <String>{_answer};
    while (opts.length < 4) {
      final String e = _all[_rng.nextInt(_all.length)];
      if (e != _prompt) opts.add(e);
    }
    _opts = opts.toList()..shuffle(_rng);
    _lock = false;
    _success = false;
  }

  Future<void> _onTap(String v, int idx) async {
    if (_lock) return;
    if (v == _answer) {
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
        final bool again =
            await finishGame(context, widget.gameId, mistakes: _mistakes);
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
      onReplay: () => AudioService.instance.speak('找出相反的！'),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(Sizes.gap),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(Sizes.radius),
                    border: Border.all(color: const Color(0xFFFFC107), width: 4),
                  ),
                  child: Text(_prompt, style: TextStyle(fontSize: context.s(80))),
                ),
                const SizedBox(height: 10),
                Text('找相反的',
                    style: TextStyle(fontSize: context.s(18), color: const Color(0xFF888888))),
                const SizedBox(height: Sizes.gap),
                Wrap(
                  spacing: Sizes.bigGap,
                  runSpacing: Sizes.gap,
                  alignment: WrapAlignment.center,
                  children: List<Widget>.generate(_opts.length, (int idx) {
                    final String v = _opts[idx];
                    final bool win = _success && v == _answer;
                    final bool hint = !win && v == _answer && _wrongCount >= 3;
                    return Shaker(
                      trigger: _wrong[idx] ?? 0,
                      child: GestureDetector(
                        onTap: () => _onTap(v, idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: context.s(120),
                          height: context.s(120),
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
                            child: Text(v, style: TextStyle(fontSize: context.s(64))),
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
