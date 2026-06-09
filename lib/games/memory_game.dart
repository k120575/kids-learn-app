import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/game_complete.dart';
import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/game_scaffold.dart';

class _Card {
  _Card(this.emoji);
  final String emoji;
  bool up = false;
  bool matched = false;
}

/// 記憶翻牌：翻牌找出成對的圖案，記住位置。pairs 控制難度（卡數 = pairs×2）。
class MemoryGame extends StatefulWidget {
  const MemoryGame({
    super.key,
    required this.gameId,
    required this.title,
    this.pairs = 6,
  });

  final String gameId;
  final String title;
  final int pairs;

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  static const List<String> _pool = <String>[
    '🐶', '🐱', '🐰', '🐸', '🐵', '🐧', '🦊', '🐯', '🦁', '🐮',
    '🐷', '🐔', '🦉', '🐢', '🦋', '🐝', '🍎', '🍌', '🍓', '🍇',
    '⭐', '🌈', '🚗', '🚀', '⚽', '🎈', '🎁', '🍦',
  ];

  final Random _rng = Random();
  late List<_Card> _cards;
  int? _first;
  bool _lock = false;
  int _mistakes = 0;
  late int _pairs; // 適性難度後的配對數

  @override
  void initState() {
    super.initState();
    // 適性難度：簡單 4 對、一般依設定（6）、挑戰 8 對。
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    _pairs = level == 0 ? 4 : (level == 1 ? widget.pairs : 8);
    _deal();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice('翻翻看，找出一樣的！'),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _deal() {
    final List<String> pick = (List<String>.of(_pool)..shuffle(_rng))
        .take(_pairs)
        .toList();
    _cards = <_Card>[
      for (final String e in pick) ...<_Card>[_Card(e), _Card(e)],
    ]..shuffle(_rng);
    _first = null;
    _lock = false;
    _mistakes = 0;
  }

  Future<void> _tap(int i) async {
    if (_lock) return;
    final _Card c = _cards[i];
    if (c.up || c.matched) return;
    setState(() => c.up = true);
    if (_first == null) {
      _first = i;
      return;
    }
    final _Card a = _cards[_first!];
    if (a.emoji == c.emoji && _first != i) {
      // 配對成功
      setState(() {
        a.matched = true;
        c.matched = true;
        _first = null;
      });
      AudioService.instance.tap(); // 配對成功只給輕點聲
      if (_cards.every((_Card x) => x.matched)) {
        _lock = true;
        AudioService.instance.correct(); // 全部完成才放答對 chime
        await _finish();
      }
    } else {
      // 沒配對到：不責備、不出「再試一次」，靜靜翻回去就好（翻錯是記憶遊戲的常態）。
      // 仍計入 mistakes 供星數/適性難度評分，但不發出聲音提示。
      _lock = true;
      _mistakes++;
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() {
        a.up = false;
        c.up = false;
        _first = null;
        _lock = false;
      });
    }
  }

  Future<void> _finish() async {
    final bool again =
        await finishGame(context, widget.gameId, mistakes: _mistakes);
    if (!mounted) return;
    if (again) {
      setState(_deal);
      AudioService.instance.speak('翻翻看，找出一樣的！');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: widget.title,
      onReplay: () => AudioService.instance.speak('翻翻看，找出一樣的！'),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Sizes.gap),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: List<Widget>.generate(_cards.length, (int i) {
              final _Card c = _cards[i];
              final bool shown = c.up || c.matched;
              return GestureDetector(
                onTap: () => _tap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: context.s(96),
                  height: context.s(96),
                  decoration: BoxDecoration(
                    color: c.matched
                        ? const Color(0xFFC8E6C9)
                        : (shown ? Colors.white : const Color(0xFF26A69A)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: c.matched
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF1E8E80),
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      shown ? c.emoji : '❓',
                      style: TextStyle(
                        fontSize: context.s(52),
                        color: shown ? null : Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
