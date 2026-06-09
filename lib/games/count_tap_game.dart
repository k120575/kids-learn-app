import 'dart:async';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/game_complete.dart';
import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/game_scaffold.dart';

class CountRound {
  const CountRound({required this.emoji, required this.count});
  final String emoji;
  final int count;
}

/// 數數點點（3-4 歲）：螢幕上有 N 個東西，每點一個就唸出數字，
/// 全部點完唸出總數。邊玩邊建立「一一對應 + 數量」概念。
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
  int _i = 0;
  final Set<int> _tapped = <int>{};
  bool _lock = false;
  late List<CountRound> _rounds;

  CountRound get _round => _rounds[_i];

  void _prepareRounds() {
    // 適性難度：簡單只出 5 以內、一般 10 以內、挑戰不設限。
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    final int cap = level == 0 ? 5 : (level == 1 ? 10 : 1 << 30);
    List<CountRound> pool =
        widget.rounds.where((CountRound r) => r.count <= cap).toList();
    if (pool.isEmpty) pool = List<CountRound>.of(widget.rounds);
    _rounds = pool..shuffle();
    final int? n = widget.pickCount;
    if (n != null && n < _rounds.length) {
      _rounds = _rounds.sublist(0, n);
    }
  }

  @override
  void initState() {
    super.initState();
    _prepareRounds();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice('數一數，每一個都要點到喔'),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  Future<void> _tap(int idx) async {
    if (_lock || _tapped.contains(idx)) return;
    setState(() => _tapped.add(idx));
    AudioService.instance.speak('${_tapped.length}'); // 邊點邊唸，不 await
    if (_tapped.length >= _round.count) {
      _lock = true;
      // 等最後一個數字念完，再講「一共」，避免被切斷。
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      AudioService.instance.speak('一共 ${_round.count} 個！');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      if (_i < _rounds.length - 1) {
        setState(() {
          _i++;
          _tapped.clear();
          _lock = false;
        });
        AudioService.instance.speak('再數一數');
      } else {
        await _finish();
      }
    }
  }

  Future<void> _finish() async {
    final bool again = await finishGame(context, widget.gameId);
    if (!mounted) return;
    if (again) {
      setState(() {
        _prepareRounds();
        _i = 0;
        _tapped.clear();
        _lock = false;
      });
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final CountRound round = _round;
    return GameScaffold(
      title: widget.title,
      current: _i,
      total: _rounds.length,
      onReplay: () => AudioService.instance.speak('數一數，每一個都要點到喔'),
      child: Column(
        children: <Widget>[
          // 已數到幾
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${_tapped.length} / ${round.count}',
              style: TextStyle(fontSize: context.s(30), fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: Sizes.bigGap,
                  runSpacing: Sizes.bigGap,
                  alignment: WrapAlignment.center,
                  children: List<Widget>.generate(round.count, (int idx) {
                    final bool done = _tapped.contains(idx);
                    return GestureDetector(
                      onTap: () => _tap(idx),
                      child: AnimatedScale(
                        scale: done ? 1.12 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Opacity(
                              opacity: done ? 0.5 : 1.0,
                              child: Text(round.emoji,
                                  style: TextStyle(fontSize: context.s(76))),
                            ),
                            if (done)
                              Icon(Icons.check_circle_rounded,
                                  color: const Color(0xFF4CAF50), size: context.s(40)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
