import 'dart:math';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/game_complete.dart';
import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/widgets/celebration.dart';
import '../core/widgets/fit_box.dart';
import '../core/widgets/game_scaffold.dart';

/// 積木照樣蓋：上方是一個「完成圖」的彩色積木排列，孩子照著把調色盤裡的
/// 積木拖進空格，蓋出一模一樣的圖案。練「空間建構 / 部分-整體 / 視覺記憶」
/// （4-5 歲的核心空間能力，比 1:1 配對更進一階、又還不到心像旋轉）。
///
/// 自我修正：只有「正確顏色 × 正確格子」才卡得進去，放錯自己彈回、不責備、
/// 不計錯（與拼圖/走迷宮一致）。整盤放滿即過關，每局共 [rounds] 個版面。
class BlockCopyGame extends StatefulWidget {
  const BlockCopyGame({
    super.key,
    required this.gameId,
    required this.title,
    this.rounds = 4,
  });

  final String gameId;
  final String title;
  final int rounds;

  @override
  State<BlockCopyGame> createState() => _BlockCopyGameState();
}

class _BlockCopyGameState extends State<BlockCopyGame> {
  static const String _intro = '看看上面的積木，照著蓋出一模一樣的！';

  /// 積木顏色池（明亮、彼此好分辨）。
  static const List<Color> _palette = <Color>[
    Color(0xFFEF5350), // 紅
    Color(0xFF42A5F5), // 藍
    Color(0xFFFFCA28), // 黃
    Color(0xFF66BB6A), // 綠
    Color(0xFFAB47BC), // 紫
    Color(0xFFFF7043), // 橘
  ];

  final Random _rng = Random();
  late int _rows;
  late int _cols;
  late List<Color?> _target; // 每格目標顏色（null＝該格留白）
  late List<bool> _placed; // 每格是否已放好
  late List<Color> _tray; // 本回合用到的顏色（去重、依 _palette 固定順序）
  int _i = 0;
  bool _lock = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _gen();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice(_intro),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _gen() {
    // 適性難度 × 回合內微升：
    //   簡單(0)＝全小盤；一般(1)＝小盤→大盤；挑戰(2)＝大盤→更大盤（含 4×4）。
    // 本遊戲放錯只彈回、不計錯 → finishGame 恆 mistakes=0，等級只升不降：
    // 玩兩局後會常駐挑戰階，所以挑戰階是「常駐上限」而非偶爾的尖峰，
    // 天花板設 4×4 填 5~7 格＋3~4 色，別再往上。
    const List<List<int>> smalls = <List<int>>[
      <int>[2, 2],
      <int>[2, 3],
      <int>[3, 2],
    ];
    const List<List<int>> bigs = <List<int>>[
      <int>[2, 3],
      <int>[3, 2],
      <int>[3, 3],
    ];
    const List<List<int>> mediums = <List<int>>[
      <int>[3, 3],
      <int>[3, 4],
      <int>[4, 3],
    ];
    const List<List<int>> huges = <List<int>>[
      <int>[3, 4],
      <int>[4, 3],
      <int>[4, 4],
    ];
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    final List<List<int>> pool = switch (level) {
      0 => smalls,
      1 => _i < 2 ? smalls : bigs,
      _ => _i < 2 ? mediums : huges,
    };
    final List<int> d = pool[_rng.nextInt(pool.length)];
    _rows = d[0];
    _cols = d[1];
    final int cells = _rows * _cols;
    // 上色格數：小盤 3~4、大盤 4~5、更大盤 5~7，且保證留白（看得出排列）。
    // 下限 2：2×2 盤 cells-2=2，若下限寫 3 會 clamp(3, 2) 丟例外（新手關 1/3 機率閃退）。
    final int k = (cells <= 6
            ? 3 + _rng.nextInt(2)
            : cells <= 9
                ? 4 + _rng.nextInt(2)
                : 5 + _rng.nextInt(3))
        .clamp(2, cells - 2);
    // 本回合用 2~3 種顏色（挑戰階 3~4 種）。
    final List<Color> colors = (List<Color>.of(_palette)..shuffle(_rng))
        .take(level == 2 ? 3 + _rng.nextInt(2) : 2 + _rng.nextInt(2))
        .toList();
    final List<int> idx = List<int>.generate(cells, (int x) => x)
      ..shuffle(_rng);
    _target = List<Color?>.filled(cells, null);
    final Set<Color> used = <Color>{};
    for (int j = 0; j < k; j++) {
      final Color c = colors[_rng.nextInt(colors.length)];
      _target[idx[j]] = c;
      used.add(c);
    }
    _placed = List<bool>.filled(cells, false);
    _tray = _palette.where(used.contains).toList();
    _lock = false;
    _success = false;
  }

  Future<void> _accept(int cell) async {
    AudioService.instance.tap();
    setState(() => _placed[cell] = true);
    final bool done = <int>[
      for (int j = 0; j < _target.length; j++)
        if (_target[j] != null && !_placed[j]) j,
    ].isEmpty;
    if (!done) return;
    _lock = true;
    setState(() => _success = true);
    AudioService.instance.correct();
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    if (_i < widget.rounds - 1) {
      // 引導語只在第一題念過即可（initState），之後換版面不重念、不囉嗦。
      setState(() {
        _i++;
        _gen();
      });
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    // 沒有「答錯」概念（放錯只會彈回）→ 不傳 mistakes，維持正向 3 ⭐。
    final bool again = await finishGame(context, widget.gameId);
    if (!mounted) return;
    if (again) {
      setState(() {
        _i = 0;
        _gen();
      });
      AudioService.instance.speak(_intro);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size sz = MediaQuery.of(context).size;
    final bool wide = sz.width >= sz.height;
    final double maxBox =
        (wide
                ? min(sz.width * 0.42, sz.height * 0.62)
                : min(sz.width * 0.72, sz.height * 0.44))
            .clamp(150.0, 400.0);
    final int longSide = max(_rows, _cols);
    final double cell = (maxBox / longSide - 4).clamp(40.0, 120.0);
    final double refCell = (cell * 0.66).clamp(26.0, 84.0);
    final double tray = (cell * 0.86).clamp(46.0, 104.0);

    final Widget reference = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '完成圖',
          style: TextStyle(
            fontSize: context.s(18),
            fontWeight: FontWeight.bold,
            color: const Color(0xFF7C4DFF),
          ),
        ),
        SizedBox(height: context.s(8)),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7C4DFF), width: 3),
          ),
          child: _grid(refCell, play: false),
        ),
      ],
    );

    final Widget board = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C4DFF), width: 2),
      ),
      child: _grid(cell, play: true),
    );

    final Widget top = wide
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              reference,
              SizedBox(width: context.s(36)),
              board,
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              reference,
              SizedBox(height: context.s(12)),
              board,
            ],
          );

    return GameScaffold(
      title: widget.title,
      current: _i,
      total: widget.rounds,
      onReplay: () => AudioService.instance.speak(_intro),
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Expanded(child: FitBox(child: top)),
              const Divider(height: 1),
              // 下半：調色盤（可重複拖，不會用完）。
              SizedBox(
                height: tray + context.s(24),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _tray
                        .map(
                          (Color c) => Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.s(10),
                            ),
                            child: _swatch(c, tray),
                          ),
                        )
                        .toList(),
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

  Widget _grid(double cell, {required bool play}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(_rows, (int r) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(_cols, (int c) {
            return Padding(
              padding: const EdgeInsets.all(2),
              child: _cellBox(r * _cols + c, cell, play),
            );
          }),
        );
      }),
    );
  }

  Widget _cellBox(int i, double cell, bool play) {
    final Color? t = _target[i];
    // 完成圖：直接顯示目標積木；遊戲盤：放好才顯示。
    final bool showBlock = t != null && (play ? _placed[i] : true);
    if (showBlock) {
      return SizedBox(
        width: cell,
        height: cell,
        child: Center(child: _block(t, cell * 0.94)),
      );
    }
    // 空格外觀（留白格與待填格長得一模一樣 → 孩子必須看完成圖才知道哪裡要放）。
    Widget empty({bool hover = false, Color? hoverColor}) {
      return Container(
        width: cell,
        height: cell,
        decoration: BoxDecoration(
          color: hover
              ? hoverColor!.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(cell * 0.16),
          border: Border.all(
            color: hover ? hoverColor! : Colors.grey.shade400,
            width: hover ? 4 : 1,
          ),
        ),
      );
    }

    if (play && t != null) {
      return DragTarget<Color>(
        onWillAcceptWithDetails: (DragTargetDetails<Color> d) =>
            !_lock && d.data == t,
        onAcceptWithDetails: (DragTargetDetails<Color> d) => _accept(i),
        builder:
            (BuildContext ctx, List<Color?> cand, List<dynamic> rej) =>
                empty(hover: cand.isNotEmpty, hoverColor: t),
      );
    }
    return empty();
  }

  /// 一塊「積木」：圓角方塊 + 淡白內框 + 陰影，看起來像實體玩具積木。
  Widget _block(Color c, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: size * 0.07,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _swatch(Color c, double size) {
    final Widget block = _block(c, size);
    return Draggable<Color>(
      data: c,
      feedback: Material(
        type: MaterialType.transparency,
        child: Transform.scale(scale: 1.15, child: block),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: block),
      // 放錯格子會自己彈回、不計錯（只卡得進正確顏色的正確格）。
      child: block,
    );
  }
}
