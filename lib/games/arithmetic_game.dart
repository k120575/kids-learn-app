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
  _Q(this.a, this.b, this.add, this.answer, this.options);
  final int a;
  final int b;
  final bool add;
  final int answer;
  final List<int> options;
  String get text => '$a ${add ? '＋' : '－'} $b ＝';
}

/// 加減法（4-5 / 5-6 資優）：顯示算式，從 4 個數字選出答案。隨機加減、[maxValue] 以內。
class ArithmeticGame extends StatefulWidget {
  const ArithmeticGame({
    super.key,
    required this.gameId,
    required this.title,
    this.maxValue = 20,
    this.rounds = 10,
  });

  final String gameId;
  final String title;
  final int maxValue;
  final int rounds;

  @override
  State<ArithmeticGame> createState() => _ArithmeticGameState();
}

class _ArithmeticGameState extends State<ArithmeticGame> {
  final Random _rng = Random();
  late _Q _q;
  int _i = 0;
  bool _lock = false;
  bool _success = false;
  int _mistakes = 0;
  late int _maxValue; // 適性難度後的實際上限

  final Map<int, int> _wrong = <int, int>{};

  /// 本題累計答錯次數；達 3 次就輕輕高亮正解，避免孩子卡住。
  int get _wrongCount => _wrong.values.fold<int>(0, (int a, int b) => a + b);

  @override
  void initState() {
    super.initState();
    // 適性難度：簡單 10、一般 20、挑戰 30（不超過題目設定上限的 1.5 倍）。
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    _maxValue = level == 0
        ? 10
        : (level == 1 ? widget.maxValue : widget.maxValue + 10);
    _q = _gen();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readQuestion());
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  /// 逐字把算式念出來：「七 加 五 等於多少？」（小小孩看不懂數字，要用聽的）。
  /// 用固定間隔依序播放，避免 onPlayerComplete 被前一段的停止事件誤觸發。
  Future<void> _readQuestion() async {
    final AudioService a = AudioService.instance;
    await a.waitUntilVoiceIdle(); // 先讓關卡名稱念完，再開始念算式
    if (!mounted) return; // 等待時若已離開關卡，別再念題（避免退出後仍念到結束）
    setState(() => _lock = true); // 念題中先鎖住，避免題目還沒念完就作答
    a.speak('${_q.a}');
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    a.speak(_q.add ? '加' : '減');
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    a.speak('${_q.b}');
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    a.speak('等於多少？');
    await Future<void>.delayed(
      const Duration(milliseconds: 950),
    ); // 留尾巴，等最後一句念完
    if (mounted) setState(() => _lock = false); // 念完才開放作答
  }

  _Q _gen() {
    final bool add = _rng.nextBool();
    int a;
    int b;
    int ans;
    if (add) {
      a = 1 + _rng.nextInt(_maxValue - 1);
      b = 1 + _rng.nextInt(_maxValue - a);
      ans = a + b;
    } else {
      a = 1 + _rng.nextInt(_maxValue);
      b = 1 + _rng.nextInt(a);
      ans = a - b;
    }
    final Set<int> opts = <int>{ans};
    while (opts.length < 4) {
      final int d = ans + _rng.nextInt(7) - 3;
      if (d >= 0 && d <= _maxValue) opts.add(d);
    }
    return _Q(a, b, add, ans, opts.toList()..shuffle(_rng));
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
            padding: EdgeInsets.all(context.s(Sizes.gap)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // FittedBox：兩位數算式在小螢幕也不會溢出（黃黑警示線）。
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${_q.text} ?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: context.s(56),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: context.s(Sizes.bigGap)),
                // 念題中（_lock 但尚未答對）淡化選項，提示「先聽完」。
                AnimatedOpacity(
                  opacity: (_lock && !_success) ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Wrap(
                    spacing: context.s(Sizes.bigGap),
                    runSpacing: context.s(Sizes.gap),
                    alignment: WrapAlignment.center,
                    children: List<Widget>.generate(_q.options.length, (
                      int idx,
                    ) {
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

class _NumTile extends StatelessWidget {
  const _NumTile({
    required this.value,
    required this.onTap,
    required this.highlight,
    this.hint = false,
  });

  final int value;
  final VoidCallback onTap;
  final bool highlight; // 答對：綠色
  final bool hint; // 答錯多次：琥珀色輕提示正解

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: context.s(120),
        height: context.s(120),
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
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: context.s(52),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
