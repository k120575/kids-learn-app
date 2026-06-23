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

class _Card {
  _Card(this.display, this.sound);

  /// 卡面顯示的注音符號（如「ㄅ」）。
  final String display;

  /// 配對成功時念出的讀音（標準音節，如「ㄅㄛ」）。
  final String sound;

  bool matched = false;
}

/// 注音對對碰（4-5 語文）：所有卡片正面朝上，點兩張「一樣的注音」把它們配成一對；
/// 配對成功會念出該注音的讀音（ㄅ→「ㄅㄛ」）。
///
/// 設計理據：4-5 還沒學拼音，不適合考「開頭音」。這關只做「找一樣的符號」——
/// 純視覺辨識 + 聽到讀音建立「符號↔聲音」連結，認知負荷低、又能熟悉注音長相。
/// 操作用「點兩張」而非拖線：幼兒手指拖線易斷、難定位，點選最穩。
class ZhuyinMatchGame extends StatefulWidget {
  const ZhuyinMatchGame({
    super.key,
    required this.gameId,
    required this.title,
    required this.pool,
  });

  final String gameId;
  final String title;

  /// 注音池：(顯示字, 讀音)。每局隨機抽 pairs 個出來配對。
  final List<(String, String)> pool;

  @override
  State<ZhuyinMatchGame> createState() => _ZhuyinMatchGameState();
}

class _ZhuyinMatchGameState extends State<ZhuyinMatchGame> {
  static const String _intro = '找出一樣的注音，把兩個一樣的點在一起！';

  final Random _rng = Random();
  late List<_Card> _cards;
  late int _pairs;
  int? _sel; // 已選起的第一張（等第二張比對）
  int _wrongCard = -1; // 剛點錯的第二張（用來抖動 + 短暫紅框）
  int _shake = 0; // Shaker 觸發計數
  bool _lock = false;
  int _mistakes = 0;

  @override
  void initState() {
    super.initState();
    // 適性難度：簡單 4 對、一般 6 對、挑戰 8 對。
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    _pairs = level == 0 ? 4 : (level == 1 ? 6 : 8);
    _deal();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice(_intro),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _deal() {
    final List<(String, String)> pick = (List<(String, String)>.of(
      widget.pool,
    )..shuffle(_rng)).take(_pairs).toList();
    _cards = <_Card>[
      for (final (String, String) z in pick) ...<_Card>[
        _Card(z.$1, z.$2),
        _Card(z.$1, z.$2),
      ],
    ]..shuffle(_rng);
    _sel = null;
    _wrongCard = -1;
    _lock = false;
    _mistakes = 0;
  }

  Future<void> _tap(int i) async {
    if (_lock) return;
    final _Card c = _cards[i];
    if (c.matched) return;
    // 再點一次已選起的那張 → 取消選取。
    if (_sel == i) {
      setState(() => _sel = null);
      return;
    }
    if (_sel == null) {
      setState(() => _sel = i);
      AudioService.instance.tap();
      return;
    }
    final _Card a = _cards[_sel!];
    if (a.display == c.display) {
      // 配對成功：兩張變綠、念讀音。
      setState(() {
        a.matched = true;
        c.matched = true;
        _sel = null;
      });
      AudioService.instance.speak(c.sound); // 念這個注音的讀音
      if (_cards.every((_Card x) => x.matched)) {
        _lock = true;
        await Future<void>.delayed(const Duration(milliseconds: 650));
        if (!mounted) return;
        AudioService.instance.correct();
        await _finish();
      }
    } else {
      // 配對失敗：抖一下、短暫提示，再取消選取（不責備）。
      _mistakes++;
      _lock = true;
      AudioService.instance.wrong();
      setState(() {
        _wrongCard = i;
        _shake++;
      });
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        _sel = null;
        _wrongCard = -1;
        _lock = false;
      });
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
      setState(_deal);
      AudioService.instance.speak(_intro);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: widget.title,
      onReplay: () => AudioService.instance.speak(_intro),
      child: Stack(
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // 排成整齊矩形：固定 4 欄（8→4×2、12→4×3、16→4×4），卡片大小隨寬度縮放。
              const int cols = 4;
              final double gap = context.s(12);
              final double pad = context.s(Sizes.gap);
              final double avail = constraints.maxWidth - pad * 2;
              final double cell = (((avail - gap * (cols - 1)) / cols))
                  .clamp(40.0, context.s(96));
              final int rows = (_cards.length / cols).ceil();
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List<Widget>.generate(rows, (int r) {
                      final int start = r * cols;
                      final int end = (start + cols).clamp(0, _cards.length);
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: r == rows - 1 ? 0 : gap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            for (int i = start; i < end; i++) ...<Widget>[
                              _buildCard(context, i, cell),
                              if (i != end - 1) SizedBox(width: gap),
                            ],
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
          if (_cards.every((_Card x) => x.matched))
            const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, int i, double cell) {
    final _Card c = _cards[i];
    final bool selected = _sel == i;
    final bool wrong = _wrongCard == i;
    final Color bg = c.matched
        ? const Color(0xFFC8E6C9)
        : (wrong
              ? const Color(0xFFFFCDD2)
              : (selected ? const Color(0xFFFFF3CD) : Colors.white));
    final Color border = c.matched
        ? const Color(0xFF4CAF50)
        : (wrong
              ? const Color(0xFFE57373)
              : (selected
                    ? const Color(0xFFFFC107)
                    : Colors.grey.shade300));
    return Shaker(
      trigger: wrong ? _shake : 0,
      child: GestureDetector(
        onTap: () => _tap(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: cell,
          height: cell,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: border,
              width: (selected || c.matched || wrong) ? 5 : 3,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              c.display,
              style: TextStyle(
                fontSize: cell * 0.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5C6BC0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
