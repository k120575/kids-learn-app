import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/game_complete.dart';
import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/widgets/celebration.dart';
import '../core/widgets/game_scaffold.dart';
import '../core/widgets/shaker.dart';

/// 找不同：左右兩格相同的圖案陣列，有 [numDiff] 處不一樣，要全部點出來。
class SpotDifferenceGame extends StatefulWidget {
  const SpotDifferenceGame({
    super.key,
    required this.gameId,
    required this.title,
    this.cols = 3,
    this.rows = 3,
    this.numDiff = 2,
    this.rounds = 8,
  });

  final String gameId;
  final String title;
  final int cols;
  final int rows;
  final int numDiff;
  final int rounds;

  @override
  State<SpotDifferenceGame> createState() => _SpotDifferenceGameState();
}

class _SpotDifferenceGameState extends State<SpotDifferenceGame> {
  static const List<String> _pool = <String>[
    '🐶',
    '🐱',
    '🐰',
    '🐸',
    '🐵',
    '🐧',
    '🦊',
    '🐯',
    '🦁',
    '🐮',
    '🍎',
    '🍌',
    '🍓',
    '🍇',
    '⭐',
    '🌈',
    '🚗',
    '🚀',
    '⚽',
    '🎈',
    '🌸',
    '🍦',
    '🎁',
    '🦋',
  ];

  final Random _rng = Random();
  late List<String> _left;
  late List<String> _right;
  late Set<int> _diffs;
  final Set<int> _found = <int>{};
  int _i = 0;
  bool _lock = false;
  bool _success = false;
  int _wrongTrigger = 0;
  int _mistakes = 0;
  late int _numDiff; // 適性難度後的差異處數

  int get _count => widget.cols * widget.rows;

  @override
  void initState() {
    super.initState();
    // 適性難度：簡單 2 處、一般依設定、挑戰 4 處。
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    _numDiff = level == 0 ? 2 : (level == 1 ? widget.numDiff : 4);
    _gen();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice('哪裡不一樣？點出來！'),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _gen() {
    _left = <String>[
      for (int i = 0; i < _count; i++) _pool[_rng.nextInt(_pool.length)],
    ];
    _right = List<String>.of(_left);
    _diffs = <int>{};
    while (_diffs.length < _numDiff) {
      _diffs.add(_rng.nextInt(_count));
    }
    for (final int pos in _diffs) {
      String other;
      do {
        other = _pool[_rng.nextInt(_pool.length)];
      } while (other == _left[pos]);
      _right[pos] = other;
    }
    _found.clear();
    _lock = false;
    _success = false;
  }

  Future<void> _onTap(int i) async {
    if (_lock) return;
    if (_diffs.contains(i)) {
      if (_found.contains(i)) return;
      setState(() => _found.add(i));
      AudioService.instance.tap(); // 找到一處只給輕點聲
      if (_found.length == _diffs.length) {
        setState(() {
          _lock = true;
          _success = true;
        });
        AudioService.instance.correct(); // 全部找到才放答對 chime
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
      }
    } else {
      AudioService.instance.wrong();
      _mistakes++;
      setState(() => _wrongTrigger++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: widget.title,
      current: _i,
      total: widget.rounds,
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(context.s(8)),
                child: Text(
                  '找到 ${_found.length} / ${_diffs.length}',
                  style: TextStyle(
                    fontSize: context.s(22),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Shaker(
                    trigger: _wrongTrigger,
                    // FittedBox：整個盤面等比縮放填滿可用空間，任何螢幕都不溢出。
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: IntrinsicHeight(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _panel(_left),
                            SizedBox(width: context.s(10)),
                            Container(
                              width: context.s(3),
                              color: Colors.grey.shade300,
                            ),
                            SizedBox(width: context.s(10)),
                            _panel(_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_success) const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }

  Widget _panel(List<String> data) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(widget.rows, (int r) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(widget.cols, (int c) {
            final int idx = r * widget.cols + c;
            final bool found = _found.contains(idx);
            return GestureDetector(
              onTap: () => _onTap(idx),
              child: Container(
                width: context.s(84),
                height: context.s(84),
                margin: EdgeInsets.all(context.s(3)),
                decoration: BoxDecoration(
                  color: found ? const Color(0xFFC8E6C9) : null,
                  borderRadius: BorderRadius.circular(14),
                  border: found
                      ? Border.all(color: const Color(0xFF4CAF50), width: 4)
                      : null,
                ),
                child: Center(
                  child: Text(
                    data[idx],
                    style: TextStyle(fontSize: context.s(50)),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}
