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

/// 找一樣（3-4 動腦）：上方出現一個目標圖，從下排選出「一模一樣」的那個。
///
/// 發展理據：3-4 歲的動腦重點是「感知辨識」——把目標和選項一一比對、找出相同，
/// 認知負荷遠低於 4-5 的找不同（兩兩盤面比對）或記憶翻牌（記隱藏位置）。
/// 這是「看著比」不是「記著比」，最適合學前早期。
class FindSameGame extends StatefulWidget {
  const FindSameGame({
    super.key,
    required this.gameId,
    required this.title,
    this.rounds = 6,
  });

  final String gameId;
  final String title;
  final int rounds;

  @override
  State<FindSameGame> createState() => _FindSameGameState();
}

class _FindSameGameState extends State<FindSameGame> {
  // 視覺差異夠大的圖庫，避免幼兒分不清相近圖案。
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
    '🚗',
    '🚀',
    '⚽',
    '🎈',
    '🌈',
    '⭐',
    '🌸',
    '🍦',
    '🎁',
    '🦋',
    '🐟',
    '🌟',
    '🍉',
    '🐝',
  ];

  final Random _rng = Random();
  late String _target;
  late List<String> _options;
  late int _correct;
  int _i = 0;
  bool _lock = false;
  bool _success = false;
  int _mistakes = 0;
  final Map<int, int> _wrong = <int, int>{};

  /// 選項數：簡單 3、一般 4、挑戰 5（干擾越多越難辨）。
  int get _optCount {
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    return level == 0 ? 3 : (level == 1 ? 4 : 5);
  }

  @override
  void initState() {
    super.initState();
    _gen();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice('找出一樣的！'),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _gen() {
    final int n = _optCount;
    _target = _pool[_rng.nextInt(_pool.length)];
    // 干擾項：與目標都不同、彼此也不同。
    final Set<String> distract = <String>{};
    while (distract.length < n - 1) {
      final String e = _pool[_rng.nextInt(_pool.length)];
      if (e != _target) distract.add(e);
    }
    _options = <String>[_target, ...distract]..shuffle(_rng);
    _correct = _options.indexOf(_target);
    _wrong.clear();
    _lock = false;
    _success = false;
  }

  Future<void> _onTap(int idx) async {
    if (_lock) return;
    if (idx == _correct) {
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
      onReplay: () => AudioService.instance.speak('找出一樣的！'),
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              // 目標圖：放在圓角卡片裡，明確「就是要找這個」。
              Padding(
                padding: EdgeInsets.only(
                  top: context.s(8),
                  bottom: context.s(4),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.s(22),
                    vertical: context.s(10),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(Sizes.radius),
                    border: Border.all(
                      color: const Color(0xFFFFC107),
                      width: 4,
                    ),
                  ),
                  child: Text(
                    _target,
                    style: TextStyle(fontSize: context.s(86)),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: context.s(Sizes.bigGap),
                      runSpacing: context.s(Sizes.bigGap),
                      alignment: WrapAlignment.center,
                      children: List<Widget>.generate(_options.length, (
                        int idx,
                      ) {
                        final bool win = _success && idx == _correct;
                        return Shaker(
                          trigger: _wrong[idx] ?? 0,
                          child: _Tile(
                            emoji: _options[idx],
                            highlight: win,
                            onTap: () => _onTap(idx),
                          ),
                        );
                      }),
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
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.emoji,
    required this.onTap,
    required this.highlight,
  });

  final String emoji;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: context.s(130),
        height: context.s(130),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFC8E6C9) : Colors.white,
          borderRadius: BorderRadius.circular(Sizes.radius),
          border: Border.all(
            color: highlight ? const Color(0xFF4CAF50) : Colors.grey.shade300,
            width: highlight ? 6 : 3,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(emoji, style: TextStyle(fontSize: context.s(74))),
        ),
      ),
    );
  }
}
