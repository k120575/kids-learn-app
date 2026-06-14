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

/// 節奏跟打（3-4 歲）：先聽示範拍幾下，再換小朋友照樣拍同樣的次數。
/// 用觸控時序（不需麥克風），判定以「拍滿次數」為準，對幼兒寬容。
class RhythmGame extends StatefulWidget {
  const RhythmGame({
    super.key,
    required this.gameId,
    required this.title,
    this.rounds = 8,
    this.minBeats = 2,
    this.maxBeats = 4,
  });

  final String gameId;
  final String title;

  /// 關卡數。
  final int rounds;

  /// 每關拍數的隨機範圍（含上下界；研究：4 歲上限約 4 拍）。
  final int minBeats;
  final int maxBeats;

  @override
  State<RhythmGame> createState() => _RhythmGameState();
}

class _RhythmGameState extends State<RhythmGame> {
  int _i = 0;
  int _taps = 0;
  bool _demo = false;
  bool _pulse = false;
  bool _lock = false;
  final Random _rng = Random();
  late List<int> _counts;
  late int _maxBeats; // 適性難度後的拍數上限

  int get _beats => _counts[_i];

  /// 產生每關的拍數：範圍內隨機，且不與上一關相同。
  void _generate() {
    _counts = <int>[];
    int prev = -1;
    for (int i = 0; i < widget.rounds; i++) {
      int b;
      do {
        b = widget.minBeats + _rng.nextInt(_maxBeats - widget.minBeats + 1);
      } while (b == prev && _maxBeats > widget.minBeats);
      _counts.add(b);
      prev = b;
    }
  }

  @override
  void initState() {
    super.initState();
    // 適性難度：簡單上限 3 拍、一般依設定、挑戰 5 拍。
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    _maxBeats = level == 0 ? 3 : (level == 1 ? widget.maxBeats : 5);
    if (_maxBeats < widget.minBeats) _maxBeats = widget.minBeats;
    _generate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playDemo());
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  Future<void> _beat() async {
    final bool ok = await AudioService.instance.playBeat('snare.mp3'); // 小鼓
    if (!ok) await SystemSound.play(SystemSoundType.click);
    if (!mounted) return;
    setState(() => _pulse = true);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (mounted) setState(() => _pulse = false);
  }

  Future<void> _playDemo() async {
    setState(() {
      _demo = true;
      _taps = 0;
      _lock = true;
    });
    // 依「實際語音長度」等到念完（+0.6s 緩衝）才示範，鼓聲不會疊到語音。
    await AudioService.instance.speakForDuration(
      '聽聽看，這樣拍',
      extra: const Duration(milliseconds: 600),
    );
    if (!mounted) return;
    for (int b = 0; b < _beats; b++) {
      if (!mounted) return;
      await _beat();
      await Future<void>.delayed(const Duration(milliseconds: 560));
    }
    if (!mounted) return;
    setState(() {
      _demo = false;
      _lock = false;
    });
    AudioService.instance.speak('換你拍！'); // 不報拍數（那等於告訴答案）
  }

  Future<void> _tapDrum() async {
    if (_lock || _demo) return;
    await HapticFeedback.lightImpact();
    await _beat();
    if (!mounted) return;
    setState(() => _taps++);
    if (_taps >= _beats) {
      _lock = true;
      AudioService.instance.correct(); // 回饋，不 await
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      if (_i < _counts.length - 1) {
        setState(() {
          _i++;
          _taps = 0;
          _lock = false;
        });
        _playDemo();
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
        _generate(); // 再玩一次重新隨機
        _i = 0;
        _taps = 0;
        _lock = false;
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
      total: _counts.length,
      onReplay: _demo ? null : _playDemo,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // （不顯示拍數，避免直接洩漏答案；靠耳朵聽示範）
          Text(
            _demo ? '仔細聽…' : '換你拍！',
            style: TextStyle(
              fontSize: context.s(24),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.s(Sizes.bigGap)),
          GestureDetector(
            onTap: _tapDrum,
            child: AnimatedScale(
              scale: _pulse ? 1.18 : 1.0,
              duration: const Duration(milliseconds: 110),
              child: Container(
                width: context.s(200),
                height: context.s(200),
                decoration: BoxDecoration(
                  color: const Color(0xFFAB47BC).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFAB47BC), width: 6),
                ),
                child: Center(
                  child: Text('🥁', style: TextStyle(fontSize: context.s(110))),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
