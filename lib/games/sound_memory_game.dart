import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/audio_service.dart';
import '../core/game_complete.dart';
import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/game_scaffold.dart';

class _Pad {
  const _Pad(this.sfx, this.emoji, this.color);
  final String sfx;
  final String emoji;
  final Color color;
}

/// 音波記憶（5-6）：魔法樂團依序奏出一串音色，記住順序後照樣點一次（Simon）。
/// 用真實樂器音色（鈴/小號/小提琴/鼓）區分四個魔法符。
/// 適性難度：簡單序列 2→4、一般 3→5、挑戰 4→6。點錯會重播該回合示範，不會結束。
class SoundMemoryGame extends StatefulWidget {
  const SoundMemoryGame({
    super.key,
    required this.gameId,
    required this.title,
    this.rounds = 6,
  });

  final String gameId;
  final String title;
  final int rounds;

  @override
  State<SoundMemoryGame> createState() => _SoundMemoryGameState();
}

class _SoundMemoryGameState extends State<SoundMemoryGame> {
  static const List<_Pad> _pads = <_Pad>[
    _Pad('bell.mp3', '🔔', Color(0xFFEF5350)),
    _Pad('trumpet.mp3', '🎺', Color(0xFF42A5F5)),
    _Pad('violin.mp3', '🎻', Color(0xFF66BB6A)),
    _Pad('snare.mp3', '🥁', Color(0xFFFFB300)),
  ];

  final Random _rng = Random();
  late List<int> _seq;
  int _i = 0; // 回合
  int _step = 0; // 玩家已正確重現到第幾個
  int _active = -1; // 目前發亮的 pad
  bool _demo = false; // 示範播放中
  bool _lock = true; // 鎖住作答
  int _mistakes = 0;

  late int _baseLen;
  late int _maxLen;

  @override
  void initState() {
    super.initState();
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    _baseLen = level == 0 ? 2 : (level == 1 ? 3 : 4);
    _maxLen = level == 0 ? 4 : (level == 1 ? 5 : 6);
    _newSequence();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playDemo());
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _newSequence() {
    final int len = min(_baseLen + _i, _maxLen);
    _seq = List<int>.generate(len, (_) => _rng.nextInt(_pads.length));
    _step = 0;
  }

  Future<void> _flash(int idx) async {
    if (!mounted) return;
    setState(() => _active = idx);
    await AudioService.instance.playSfxAndWait(_pads[idx].sfx);
    if (!mounted) return;
    setState(() => _active = -1);
    await Future<void>.delayed(const Duration(milliseconds: 160));
  }

  Future<void> _playDemo() async {
    setState(() {
      _demo = true;
      _lock = true;
      _step = 0;
    });
    await AudioService.instance.waitUntilVoiceIdle(); // 先讓關卡名稱念完
    if (!mounted) return; // 等待時若已離開關卡，別再念（避免退出後仍念到結束）
    await AudioService.instance.speakForDuration(
      '仔細聽，記住順序！',
      extra: const Duration(milliseconds: 500),
    );
    if (!mounted) return;
    for (final int idx in _seq) {
      if (!mounted) return;
      await _flash(idx);
    }
    if (!mounted) return;
    setState(() {
      _demo = false;
      _lock = false;
    });
    AudioService.instance.speak('換你了！');
  }

  Future<void> _tap(int idx) async {
    if (_lock || _demo) return;
    if (idx == _seq[_step]) {
      // 正確
      HapticFeedback.lightImpact();
      setState(() => _active = idx);
      await AudioService.instance.playSfx(_pads[idx].sfx);
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() {
        _active = -1;
        _step++;
      });
      if (_step >= _seq.length) {
        // 本回合完成
        _lock = true;
        AudioService.instance.correct();
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        if (_i < widget.rounds - 1) {
          setState(() {
            _i++;
            _newSequence();
          });
          _playDemo();
        } else {
          await _finish();
        }
      }
    } else {
      // 點錯：溫和提示、計一次錯，重播本回合示範。
      _lock = true;
      _mistakes++;
      AudioService.instance.wrong();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _playDemo();
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
        _i = 0;
        _mistakes = 0;
        _newSequence();
      });
      _playDemo();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: widget.title,
      current: _i,
      total: widget.rounds,
      onReplay: _demo ? null : _playDemo,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            _demo ? '仔細聽…' : '換你照著點！',
            style: TextStyle(
              fontSize: context.s(24),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.s(Sizes.bigGap)),
          Wrap(
            spacing: context.s(Sizes.bigGap),
            runSpacing: context.s(Sizes.bigGap),
            alignment: WrapAlignment.center,
            children: List<Widget>.generate(_pads.length, (int idx) {
              final _Pad pad = _pads[idx];
              final bool on = _active == idx;
              return GestureDetector(
                onTap: () => _tap(idx),
                child: AnimatedScale(
                  scale: on ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: context.s(130),
                    height: context.s(130),
                    decoration: BoxDecoration(
                      color: on ? pad.color : pad.color.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(Sizes.radius),
                      border: Border.all(color: pad.color, width: 5),
                      boxShadow: on
                          ? <BoxShadow>[
                              BoxShadow(
                                color: pad.color.withValues(alpha: 0.7),
                                blurRadius: 22,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        pad.emoji,
                        style: TextStyle(fontSize: context.s(64)),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: context.s(Sizes.bigGap)),
          // 進度：本回合已點對幾個 / 共幾個
          Text(
            '$_step / ${_seq.length}',
            style: TextStyle(
              fontSize: context.s(20),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8E24AA),
            ),
          ),
        ],
      ),
    );
  }
}
