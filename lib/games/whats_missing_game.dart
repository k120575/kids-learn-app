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

/// 什麼不見了（3-4 動腦）：先看清楚一排圖案 → 蓋起來 → 再打開時少了一個，
/// 從選項中點出「消失的那個」。經典 Kim's game。
///
/// 發展理據：練短期工作記憶（學前早期容量約 2-3 項，所以最少只放 3 個）。
/// 跟記憶翻牌不同——不需記「隱藏位置的配對」，只需記住「剛剛有什麼」，
/// 是更基礎的記憶動作，適合 3-4 歲入門。
class WhatsMissingGame extends StatefulWidget {
  const WhatsMissingGame({
    super.key,
    required this.gameId,
    required this.title,
    this.rounds = 5,
  });

  final String gameId;
  final String title;
  final int rounds;

  @override
  State<WhatsMissingGame> createState() => _WhatsMissingGameState();
}

enum _Phase { memorize, hide, ask }

class _WhatsMissingGameState extends State<WhatsMissingGame> {
  // emoji → 名稱：記憶階段會逐一「念出」每個物件，替孩子做語音標記
  // （3-4 歲不會自己默念，幫他命名能大幅提升記得住的機率）。
  static const Map<String, String> _names = <String, String>{
    '🐶': '小狗', '🐱': '小貓', '🐰': '兔子', '🐸': '青蛙', '🐵': '猴子',
    '🐧': '企鵝', '🦊': '狐狸', '🐯': '老虎', '🦁': '獅子', '🐮': '牛',
    '🍎': '蘋果', '🍌': '香蕉', '🍓': '草莓', '🍇': '葡萄', '🚗': '汽車',
    '🚀': '火箭', '⚽': '足球', '🎈': '氣球', '🌈': '彩虹', '⭐': '星星',
    '🌸': '花', '🍦': '冰淇淋', '🎁': '禮物', '🦋': '蝴蝶', '🐟': '魚',
    '🍉': '西瓜', '🐝': '蜜蜂',
  };
  static final List<String> _pool = _names.keys.toList();

  final Random _rng = Random();
  int _nameIdx = -1; // 記憶階段目前正在念（高亮）哪一格
  bool _showing = false; // 記憶序列播放中（防止重播鈕重複觸發造成兩個迴圈打架）
  late List<String> _items; // 場上這排圖案
  late int _missingIdx; // 消失的那格
  late List<String> _options; // 下方選項
  late int _correct;
  _Phase _phase = _Phase.memorize;
  int _i = 0;
  bool _lock = true; // 記憶 / 蓋牌階段不開放作答
  bool _success = false;
  int _mistakes = 0;
  final Map<int, int> _wrong = <int, int>{};

  /// 場上圖案數。3-4 歲工作記憶 span 約 2-3 項，所以：
  /// 退階 2（吃力的孩子）、預設/一般 3（典型 span）、挑戰才到 4（此齡上限，不放 5）。
  int get _itemCount {
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    return level == 0 ? 2 : (level == 1 ? 3 : 4);
  }

  String get _missing => _items[_missingIdx];

  @override
  void initState() {
    super.initState();
    _gen();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runRound());
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _gen() {
    final int n = _itemCount;
    final List<String> shuffled = List<String>.of(_pool)..shuffle(_rng);
    _items = shuffled.take(n).toList();
    _missingIdx = _rng.nextInt(n);
    // 選項：消失的那個 + 沒出現在場上的干擾項。簡單 3 個、其餘 4 個。
    final int optCount = ProgressStore.instance.levelFor(widget.gameId) == 0
        ? 3
        : 4;
    final Set<String> opt = <String>{_missing};
    final List<String> rest = shuffled.sublist(n);
    while (opt.length < optCount && rest.isNotEmpty) {
      opt.add(rest.removeAt(0));
    }
    _options = opt.toList()..shuffle(_rng);
    _correct = _options.indexOf(_missing);
    _wrong.clear();
    _success = false;
  }

  /// 重播本題的記憶序列（不重新出題）。不限次數；序列播放中按了會被忽略。
  void _replay() {
    if (_showing) return;
    _runRound();
  }

  /// 一回合的節奏：記憶（逐一念出每個物件）→ 蓋牌 → 出題作答。
  /// 重播「再看一次」時也走這裡（不呼叫 [_gen]，所以是同一題）。
  Future<void> _runRound() async {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.memorize;
      _lock = true;
      _showing = true;
      _nameIdx = -1;
    });
    // 先等關卡名稱念完，再用「會等實際音檔播完」的方式念開場句，最後才開始逐一命名。
    // 不能用固定延遲猜長度——開場句較長時會被第一個物件的 speak() 切掉尾字。
    await AudioService.instance.waitUntilVoiceIdle();
    await AudioService.instance.speakForDuration('看清楚，記住它們！',
        extra: const Duration(milliseconds: 300));
    if (!mounted) return;
    // 逐一高亮並念出每個物件——替孩子做語音標記，同時自然拉長觀看時間。
    for (int i = 0; i < _items.length; i++) {
      if (!mounted) return;
      setState(() => _nameIdx = i);
      AudioService.instance.speak(_names[_items[i]] ?? '');
      await Future<void>.delayed(const Duration(milliseconds: 1400));
    }
    if (!mounted) return;
    setState(() => _nameIdx = -1);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _phase = _Phase.hide);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _phase = _Phase.ask;
      _lock = false;
      _showing = false;
    });
    AudioService.instance.speak('什麼不見了？');
  }

  Future<void> _onTap(int idx) async {
    if (_lock) return;
    if (idx == _correct) {
      setState(() {
        _lock = true;
        _success = true;
      });
      AudioService.instance.correct();
      await Future<void>.delayed(const Duration(milliseconds: 950));
      if (!mounted) return;
      if (_i < widget.rounds - 1) {
        setState(() {
          _i++;
          _gen();
        });
        _runRound();
      } else {
        final bool again =
            await finishGame(context, widget.gameId, mistakes: _mistakes);
        if (!mounted) return;
        if (again) {
          setState(() {
            _i = 0;
            _mistakes = 0;
            _gen();
          });
          _runRound();
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
      // 喇叭鈕＝「再看一次」：重播整段記憶序列（不限次數）。記憶與出題階段都能按。
      onReplay: _replay,
      child: Stack(
        children: <Widget>[
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
              // 場上這排圖案。
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      List<Widget>.generate(_items.length, (int idx) {
                    return _Slot(
                      missing: _phase == _Phase.ask && idx == _missingIdx,
                      naming: _phase == _Phase.memorize && idx == _nameIdx,
                      // 記憶階段全部亮出；蓋牌階段全部蓋住；
                      // 出題階段除了「消失的那格」其餘亮出。
                      child: switch (_phase) {
                        _Phase.memorize => Text(_items[idx],
                            style: TextStyle(fontSize: context.s(52))),
                        _Phase.hide => Text('🟦',
                            style: TextStyle(fontSize: context.s(52))),
                        _Phase.ask => idx == _missingIdx
                            ? Text('❓', style: TextStyle(fontSize: context.s(46)))
                            : Text(_items[idx],
                                style: TextStyle(fontSize: context.s(52))),
                      },
                    );
                  }),
                ),
              ),
              SizedBox(height: context.s(24)),
              // 出題階段才顯示選項。
              if (_phase == _Phase.ask)
                Wrap(
                  spacing: Sizes.bigGap,
                  runSpacing: Sizes.gap,
                  alignment: WrapAlignment.center,
                  children: List<Widget>.generate(_options.length, (int idx) {
                    final bool win = _success && idx == _correct;
                    return Shaker(
                      trigger: _wrong[idx] ?? 0,
                      child: _Option(
                        emoji: _options[idx],
                        highlight: win,
                        onTap: () => _onTap(idx),
                      ),
                    );
                  }),
                )
              else
                Text(
                  _phase == _Phase.memorize ? '看清楚喔…' : '',
                  style: TextStyle(
                      fontSize: context.s(22),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF888888)),
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

class _Slot extends StatelessWidget {
  const _Slot({required this.child, this.missing = false, this.naming = false});

  final Widget child;
  final bool missing;
  final bool naming; // 記憶階段正在念到這格 → 放大高亮，吸引孩子注意

  @override
  Widget build(BuildContext context) {
    final Color border = naming
        ? const Color(0xFF42A5F5)
        : (missing ? const Color(0xFFFFC107) : Colors.grey.shade300);
    final Color bg = naming
        ? const Color(0xFFE3F2FD)
        : (missing ? const Color(0xFFFFF3CD) : Colors.white);
    return AnimatedScale(
      scale: naming ? 1.18 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: context.s(78),
        height: context.s(78),
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: border,
            width: (naming || missing) ? 4 : 3,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
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
        width: context.s(120),
        height: context.s(120),
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
          child: Text(emoji, style: TextStyle(fontSize: context.s(70))),
        ),
      ),
    );
  }
}
