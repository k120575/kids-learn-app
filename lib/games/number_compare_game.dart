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

/// 比大小：顯示幾個數字，點出「最大的」。
class NumberCompareGame extends StatefulWidget {
  const NumberCompareGame({
    super.key,
    required this.gameId,
    required this.title,
    this.maxValue = 20,
    this.count = 3,
    this.rounds = 10,
  });

  final String gameId;
  final String title;
  final int maxValue;
  final int count;
  final int rounds;

  @override
  State<NumberCompareGame> createState() => _NumberCompareGameState();
}

class _NumberCompareGameState extends State<NumberCompareGame> {
  final Random _rng = Random();
  late List<int> _nums;
  late int _ans;
  late bool _pickMax; // 本題要選最大還是最小（隨機）
  int _i = 0;
  bool _lock = false;
  bool _success = false;
  int _mistakes = 0;
  late int _count; // 適性難度後比較幾個數
  late int _maxValue;

  final Map<int, int> _wrong = <int, int>{};

  /// 本題累計答錯次數；達 3 次就輕輕高亮正解，避免孩子卡住。
  int get _wrongCount => _wrong.values.fold<int>(0, (int a, int b) => a + b);

  @override
  void initState() {
    super.initState();
    // 適性難度：簡單比 2 個（10 以內）、一般 3 個（20 以內）、挑戰 4 個（30 以內）。
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    _count = level == 0 ? 2 : (level == 1 ? widget.count : widget.count + 1);
    _maxValue = level == 0 ? 10 : (level == 1 ? widget.maxValue : widget.maxValue + 10);
    _gen();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice(_prompt),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  /// 本題提示語（選最大 / 選最小），隨機切換。
  String get _prompt => _pickMax ? '點最大的！' : '點最小的！';

  void _gen() {
    final Set<int> s = <int>{};
    while (s.length < _count) {
      s.add(1 + _rng.nextInt(_maxValue));
    }
    _nums = s.toList()..shuffle(_rng);
    _pickMax = _rng.nextBool();
    _ans = _pickMax ? _nums.reduce(max) : _nums.reduce(min);
    _lock = false;
    _success = false;
  }

  Future<void> _onTap(int v, int idx) async {
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
        AudioService.instance.speak(_prompt); // 每題重唸（最大/最小會變）
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
          AudioService.instance.speak(_prompt);
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
      onReplay: () => AudioService.instance.speak(_prompt),
      child: Stack(
        children: <Widget>[
          Center(
            child: Padding(
              padding: const EdgeInsets.all(Sizes.gap),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(_pickMax ? '點最大的數字' : '點最小的數字',
                      style: TextStyle(
                          fontSize: context.s(22), fontWeight: FontWeight.bold)),
                  const SizedBox(height: Sizes.bigGap),
                  Wrap(
                    spacing: Sizes.bigGap,
                    runSpacing: Sizes.gap,
                    alignment: WrapAlignment.center,
                    children: List<Widget>.generate(_nums.length, (int idx) {
                      final int v = _nums[idx];
                      final bool win = _success && v == _ans;
                      final bool hint = !win && v == _ans && _wrongCount >= 3;
                      return Shaker(
                        trigger: _wrong[idx] ?? 0,
                        child: GestureDetector(
                          onTap: () => _onTap(v, idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: context.s(130),
                            height: context.s(130),
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
                              child: Text('$v',
                                  style: TextStyle(
                                      fontSize: context.s(56), fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          if (_success) const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }
}
