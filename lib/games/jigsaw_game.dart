import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/game_complete.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/celebration.dart';
import '../core/widgets/fit_box.dart';
import '../core/widgets/game_scaffold.dart';

/// 真正的拼圖（jigsaw）：一張「圖」（彩色漸層底 + 大圖案）被切成 rows×cols 塊並打散，
/// 對照旁邊放大的完成圖，把每一塊拖回正確的格子。放對才卡進去。
/// 每局隨機決定行列數（可非正方形），總片數落在 [minPieces, maxPieces]。
class JigsawGame extends StatefulWidget {
  const JigsawGame({
    super.key,
    required this.gameId,
    required this.title,
    this.rounds = 4,
    this.minPieces = 4,
    this.maxPieces = 9,
  });

  final String gameId;
  final String title;
  final int rounds;

  /// 每局總片數的範圍（行×列）。實際行列隨機，可非正方形。
  final int minPieces;
  final int maxPieces;

  @override
  State<JigsawGame> createState() => _JigsawGameState();
}

class _Pic {
  const _Pic(this.emoji, this.colors);
  final String emoji;
  final List<Color> colors; // 對角三色漸層 → 每塊碎片顏色都不同、好辨識
}

class _JigsawGameState extends State<JigsawGame> {
  static const List<String> _emojis = <String>[
    '🦄',
    '🐉',
    '🏰',
    '🌈',
    '🦋',
    '🐙',
    '🐠',
    '🌻',
    '🚀',
    '🦖',
    '🦁',
    '🐢',
    '🌸',
    '🍉',
    '🦉',
    '⭐',
  ];
  static const List<List<Color>> _grads = <List<Color>>[
    <Color>[Color(0xFFFFE082), Color(0xFFFF8A65), Color(0xFFE57373)],
    <Color>[Color(0xFF80DEEA), Color(0xFF7E57C2), Color(0xFFF06292)],
    <Color>[Color(0xFFAED581), Color(0xFF4DB6AC), Color(0xFF42A5F5)],
    <Color>[Color(0xFFFFF176), Color(0xFFFFB74D), Color(0xFFEF5350)],
    <Color>[Color(0xFFCE93D8), Color(0xFF64B5F6), Color(0xFF4DD0E1)],
    <Color>[Color(0xFFF48FB1), Color(0xFFFFB74D), Color(0xFFFFD54F)],
  ];

  final Random _rng = Random();
  late _Pic _pic;
  late int _rows;
  late int _cols;
  late List<int> _tray; // 還在托盤裡的碎片 index（已打散）
  late List<bool> _placed; // 每個格子是否已正確放入
  int _i = 0;
  int _mistakes = 0;
  bool _lock = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _gen();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice('看看完成圖，把每一塊拼回正確的位置！'),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  /// 列出片數落在範圍內、長寬比不過於極端（≤2.5）的所有 (rows, cols)。
  List<List<int>> _dims() {
    final List<List<int>> out = <List<int>>[];
    for (int r = 2; r <= 6; r++) {
      for (int c = 2; c <= 6; c++) {
        final int p = r * c;
        if (p < widget.minPieces || p > widget.maxPieces) continue;
        final double ratio = max(r, c) / min(r, c);
        if (ratio <= 2.5) out.add(<int>[r, c]);
      }
    }
    if (out.isEmpty) out.add(<int>[2, 2]);
    return out;
  }

  void _gen() {
    final List<int> d = _dims()[_rng.nextInt(_dims().length)];
    _rows = d[0];
    _cols = d[1];
    _pic = _Pic(
      _emojis[_rng.nextInt(_emojis.length)],
      _grads[_rng.nextInt(_grads.length)],
    );
    final int cells = _rows * _cols;
    _placed = List<bool>.filled(cells, false);
    _tray = List<int>.generate(cells, (int k) => k)..shuffle(_rng);
    _lock = false;
    _success = false;
  }

  Future<void> _accept(int cell) async {
    AudioService.instance.tap();
    setState(() {
      _placed[cell] = true;
      _tray.remove(cell);
    });
    if (_placed.every((bool b) => b)) {
      _lock = true;
      setState(() => _success = true);
      AudioService.instance.correct();
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      if (_i < widget.rounds - 1) {
        setState(() {
          _i++;
          _gen();
        });
        AudioService.instance.speak('看看完成圖，把每一塊拼回正確的位置！');
      } else {
        await _finish();
      }
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
        _gen();
      });
      AudioService.instance.speak('看看完成圖，把每一塊拼回正確的位置！');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// 整張完成圖（漸層底 + 置中大圖案），尺寸可非正方形。
  Widget _fullPicture(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _pic.colors,
        ),
      ),
      child: Center(
        child: Text(_pic.emoji, style: TextStyle(fontSize: min(w, h) * 0.66)),
      ),
    );
  }

  /// 第 index 塊碎片：顯示完成圖第 (r,c) 個區塊（每格皆為正方形 cell×cell）。
  Widget _fragment(int index, double cell) {
    final int r = index ~/ _cols;
    final int c = index % _cols;
    final double fullW = cell * _cols;
    final double fullH = cell * _rows;
    final double ax = _cols == 1 ? 0 : (2 * c / (_cols - 1) - 1);
    final double ay = _rows == 1 ? 0 : (2 * r / (_rows - 1) - 1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: cell,
        height: cell,
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: fullW,
          maxHeight: fullH,
          alignment: Alignment(ax, ay),
          child: _fullPicture(fullW, fullH),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 依螢幕方向與行列數估尺寸。寬螢幕（平板）把完成圖放到棋盤左側、放大；
    // 窄螢幕（手機直式）放在棋盤上方。
    final Size sz = MediaQuery.of(context).size;
    final bool wide = sz.width >= sz.height;
    final double maxBox =
        (wide
                ? min(sz.width * 0.5, sz.height * 0.54)
                : min(sz.width * 0.84, sz.height * 0.46))
            .clamp(180.0, 460.0);
    final int longSide = max(_rows, _cols);
    final double cell = (maxBox - (longSide - 1) * 4) / longSide;
    final double refLong = (maxBox * (wide ? 0.62 : 0.36)).clamp(96.0, 240.0);
    // 完成圖維持與棋盤相同長寬比。
    final double refW = _cols >= _rows ? refLong : refLong * _cols / _rows;
    final double refH = _rows >= _cols ? refLong : refLong * _rows / _cols;
    final double tray = (cell * 0.9).clamp(54.0, 110.0);

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
        SizedBox(height: context.s(10)),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7C4DFF), width: 3),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: _fullPicture(refW, refH),
          ),
        ),
      ],
    );

    final Widget top = wide
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              reference,
              SizedBox(width: context.s(40)),
              _board(cell),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              reference,
              SizedBox(height: context.s(Sizes.gap)),
              _board(cell),
            ],
          );

    return GameScaffold(
      title: widget.title,
      current: _i,
      total: widget.rounds,
      onReplay: () => AudioService.instance.speak('看看完成圖，把每一塊拼回正確的位置！'),
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              // 上半：完成圖（寬螢幕在左、窄螢幕在上）＋ 拼圖板。
              // 用 FitBox 等比縮到放得下這塊區域，矮螢幕也不會把拼圖板下緣切掉。
              Expanded(child: FitBox(child: top)),
              const Divider(height: 1),
              // 下半：打散的碎片托盤
              SizedBox(
                height: tray + context.s(Sizes.gap) * 2,
                child: Padding(
                  padding: EdgeInsets.all(context.s(Sizes.gap)),
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _tray
                            .map(
                              (int idx) => Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.s(6),
                                ),
                                child: _draggablePiece(idx, tray),
                              ),
                            )
                            .toList(),
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

  Widget _board(double cell) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7C4DFF), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(_rows, (int r) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(_cols, (int c) {
              final int idx = r * _cols + c;
              return Container(
                margin: const EdgeInsets.all(2),
                child: _cell(idx, cell),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _cell(int idx, double cell) {
    if (_placed[idx]) return _fragment(idx, cell);
    return DragTarget<int>(
      onWillAcceptWithDetails: (DragTargetDetails<int> d) =>
          !_lock && d.data == idx,
      onAcceptWithDetails: (DragTargetDetails<int> d) => _accept(idx),
      builder: (BuildContext c, List<int?> cand, List<dynamic> rej) {
        final bool hover = cand.isNotEmpty;
        return Container(
          width: cell,
          height: cell,
          decoration: BoxDecoration(
            color: hover
                ? const Color(0xFF7C4DFF).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: hover ? const Color(0xFF7C4DFF) : Colors.grey.shade400,
              width: hover ? 4 : 1,
            ),
          ),
        );
      },
    );
  }

  Widget _draggablePiece(int idx, double size) {
    final Widget piece = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _fragment(idx, size),
    );
    return Draggable<int>(
      data: idx,
      // feedback 在 Overlay 中渲染（無 Material 祖先）→ Text 會出現黃色底線；
      // 用透明 Material 包住即可消除。
      feedback: Material(
        type: MaterialType.transparency,
        child: Transform.scale(scale: 1.12, child: piece),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: piece),
      // 放錯位置時碎片會自己彈回托盤，不出「再試一次」、不計為錯誤
      // （碎片只卡得進正確格，拼完必定正確，沒有「完成卻有錯」的情況）。
      child: piece,
    );
  }
}
