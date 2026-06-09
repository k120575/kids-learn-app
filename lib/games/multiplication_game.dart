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

class _Q {
  _Q(this.a, this.b, this.answer, this.options);
  final int a; // 幾組
  final int b; // 每組幾個
  final int answer;
  final List<int> options;
}

/// 乘法魔法（5-6）：把乘法當成「幾組、每組幾個」。畫出 a 排 × b 個的星星陣列，
/// 念「a 乘 b 等於多少？」，從 4 個答案中選出乘積。
/// 適性難度：簡單用 2/5/10 的倍數、一般到 ×5、挑戰到 ×9。
class MultiplicationGame extends StatefulWidget {
  const MultiplicationGame({
    super.key,
    required this.gameId,
    required this.title,
    this.rounds = 10,
  });

  final String gameId;
  final String title;
  final int rounds;

  @override
  State<MultiplicationGame> createState() => _MultiplicationGameState();
}

class _MultiplicationGameState extends State<MultiplicationGame> {
  final Random _rng = Random();
  late _Q _q;
  int _i = 0;
  bool _lock = false;
  bool _success = false;
  int _mistakes = 0;
  late int _level;

  final Map<int, int> _wrong = <int, int>{};

  int get _wrongCount => _wrong.values.fold<int>(0, (int a, int b) => a + b);

  @override
  void initState() {
    super.initState();
    _level = ProgressStore.instance.levelFor(widget.gameId);
    _q = _gen();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readQuestion());
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  /// 逐字念算式：「三 乘以 五 等於多少？」（沿用加減法的分段念法）。
  Future<void> _readQuestion() async {
    final AudioService a = AudioService.instance;
    await a.waitUntilVoiceIdle(); // 先讓關卡名稱念完，再開始念算式
    if (mounted) setState(() => _lock = true);
    a.speak('${_q.a}');
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    a.speak('乘以');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    a.speak('${_q.b}');
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    a.speak('等於多少？');
    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (mounted) setState(() => _lock = false);
  }

  _Q _gen() {
    int a;
    int b;
    if (_level == 0) {
      // 簡單：每組是 2、5 或 10 個（最好數的倍數），1~5 組。
      b = <int>[2, 5, 10][_rng.nextInt(3)];
      a = 1 + _rng.nextInt(5);
    } else if (_level == 1) {
      a = 1 + _rng.nextInt(5);
      b = 2 + _rng.nextInt(4); // 2~5
    } else {
      a = 2 + _rng.nextInt(8); // 2~9
      b = 2 + _rng.nextInt(8);
    }
    final int ans = a * b;
    final Set<int> opts = <int>{ans};
    while (opts.length < 4) {
      // 干擾項：鄰近的乘積（±1 組 / ±1 個 / ±b），避免太離譜。
      final List<int> cands = <int>[
        (a + 1) * b, (a - 1) * b, a * (b + 1), a * (b - 1), ans + b, ans - b,
      ];
      final int d = cands[_rng.nextInt(cands.length)];
      if (d > 0 && d != ans) opts.add(d);
      if (opts.length < 4 && _rng.nextBool()) {
        final int r = ans + _rng.nextInt(7) - 3;
        if (r > 0) opts.add(r);
      }
    }
    return _Q(a, b, ans, opts.toList()..shuffle(_rng));
  }

  Future<void> _onTap(int value, int idx) async {
    if (_lock) return;
    if (value == _q.answer) {
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
          _q = _gen();
          _lock = false;
          _success = false;
          _wrong.clear();
        });
        _readQuestion();
      } else {
        final bool again =
            await finishGame(context, widget.gameId, mistakes: _mistakes);
        if (!mounted) return;
        if (again) {
          setState(() {
            _i = 0;
            _mistakes = 0;
            _q = _gen();
            _lock = false;
            _success = false;
            _wrong.clear();
          });
          _readQuestion();
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
      onReplay: _readQuestion,
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(Sizes.gap),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // 視覺化「a 組、每組 b 個」星星陣列（格子太多時改用文字，避免溢出）
                if (_q.a * _q.b <= 30)
                  _ArrayView(rows: _q.a, cols: _q.b)
                else
                  Text('${_q.a} 組，每組 ${_q.b} 個',
                      style: TextStyle(
                          fontSize: context.s(22), color: const Color(0xFF8E24AA))),
                const SizedBox(height: Sizes.gap),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${_q.a} × ${_q.b} ＝ ?',
                    style: TextStyle(
                        fontSize: context.s(48), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: Sizes.bigGap),
                AnimatedOpacity(
                  opacity: (_lock && !_success) ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Wrap(
                    spacing: Sizes.bigGap,
                    runSpacing: Sizes.gap,
                    alignment: WrapAlignment.center,
                    children:
                        List<Widget>.generate(_q.options.length, (int idx) {
                      final int v = _q.options[idx];
                      final bool win = _success && v == _q.answer;
                      return Shaker(
                        trigger: _wrong[idx] ?? 0,
                        child: _NumTile(
                          value: v,
                          highlight: win,
                          hint: !win && v == _q.answer && _wrongCount >= 3,
                          onTap: () => _onTap(v, idx),
                        ),
                      );
                    }),
                  ),
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

/// 把乘法畫成「rows 排，每排 cols 顆」星星，幫助理解乘法＝重複相加。
class _ArrayView extends StatelessWidget {
  const _ArrayView({required this.rows, required this.cols});
  final int rows;
  final int cols;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(rows, (int r) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(cols, (int c) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text('⭐', style: TextStyle(fontSize: context.s(26))),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}

class _NumTile extends StatelessWidget {
  const _NumTile({
    required this.value,
    required this.onTap,
    required this.highlight,
    this.hint = false,
  });

  final int value;
  final VoidCallback onTap;
  final bool highlight;
  final bool hint;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: context.s(110),
        height: context.s(110),
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
        ),
        child: Center(
          child: Text('$value',
              style:
                  TextStyle(fontSize: context.s(48), fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
