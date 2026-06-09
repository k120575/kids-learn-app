import 'dart:async';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/game_complete.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/game_scaffold.dart';
import '../core/widgets/shape_view.dart';

/// 可拖曳的小物件（形狀或 emoji）。
class DragPiece {
  const DragPiece({
    required this.id,
    required this.category,
    this.shape,
    this.color = const Color(0xFF42A5F5),
    this.emoji,
  });

  final String id; // 唯一
  final String category; // 配對用的類別鍵
  final ShapeKind? shape;
  final Color color;
  final String? emoji;
}

/// 放置目標（籃子/洞/拼圖位）。
class DropSlot {
  const DropSlot({
    required this.category,
    this.shape,
    this.color = const Color(0xFF42A5F5),
    this.emoji,
    this.label = '',
    this.capacity = 1,
    this.at,
  });

  final String category;
  final ShapeKind? shape;
  final Color color;
  final String? emoji;
  final String label;

  /// 可容納幾個（分類籃子用大值；形狀洞/拼圖位用 1）。
  final int capacity;

  /// 拼圖版面用的位置（0~1 對齊座標）。null 則用水平排列。
  final Alignment? at;
}

/// 通用拖曳配對引擎。category 相同才放得進去。
/// - 顏色分類：slot.capacity 很大、用色籃子。
/// - 形狀配對：slot.capacity = 1、用形狀外框。
/// - 拼圖：slot 加上 [DropSlot.at] 位置，組成一個圖案。
class DragMatchGame extends StatefulWidget {
  const DragMatchGame({
    super.key,
    required this.gameId,
    required this.title,
    required this.intro,
    this.pieces = const <DragPiece>[],
    this.slots = const <DropSlot>[],
    this.generator,
    this.rounds = 1,
  });

  /// 一局要完成幾個版面才算過關拿貼紙（搭配 generator 每回合隨機新版面）。
  final int rounds;

  final String gameId;
  final String title;
  final String intro;

  /// 固定版面（未提供 generator 時使用）。
  final List<DragPiece> pieces;
  final List<DropSlot> slots;

  /// 版面產生器：每次開始/再玩都呼叫，回傳 (pieces, slots)，做到隨機版面。
  final (List<DragPiece>, List<DropSlot>) Function()? generator;

  @override
  State<DragMatchGame> createState() => _DragMatchGameState();
}

class _DragMatchGameState extends State<DragMatchGame> {
  late List<DragPiece> _pieces;
  late List<DropSlot> _slots;
  late List<DragPiece> _remaining;
  late List<int> _slotFill;
  bool _lock = false;
  int _round = 0;
  int _mistakes = 0; // 本局累計「放錯／放不進」次數

  bool get _isFigure => _slots.any((DropSlot s) => s.at != null);

  /// 拼圖版面的格子小一點。
  double get _slotSize => context.s(_isFigure ? 92 : 130);

  @override
  void initState() {
    super.initState();
    _reset();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice(widget.intro),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _reset() {
    if (widget.generator != null) {
      final (List<DragPiece>, List<DropSlot>) b = widget.generator!();
      _pieces = b.$1;
      _slots = b.$2;
    } else {
      _pieces = widget.pieces;
      _slots = widget.slots;
    }
    _remaining = List<DragPiece>.of(_pieces)..shuffle();
    _slotFill = List<int>.filled(_slots.length, 0);
    _lock = false;
  }

  Future<void> _accept(int slotIndex, DragPiece piece) async {
    setState(() {
      _slotFill[slotIndex]++;
      _remaining.removeWhere((DragPiece p) => p.id == piece.id);
    });
    AudioService.instance.tap(); // 放一塊只給輕點聲
    if (_remaining.isEmpty) {
      _lock = true;
      AudioService.instance.correct(); // 整盤完成才放答對 chime
      _round++;
      if (_round < widget.rounds) {
        // 還有回合 → 換下一個隨機版面
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        setState(_reset);
        AudioService.instance.speak(widget.intro);
      } else {
        await _finish();
      }
    }
  }

  Future<void> _finish() async {
    final bool again =
        await finishGame(context, widget.gameId, mistakes: _mistakes);
    if (!mounted) return;
    if (again) {
      setState(() {
        _round = 0;
        _mistakes = 0;
        _reset();
      });
      AudioService.instance.speak(widget.intro);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: widget.title,
      current: _round,
      total: widget.rounds > 1 ? widget.rounds : 0,
      onReplay: () => AudioService.instance.speak(widget.intro),
      child: Column(
        children: <Widget>[
          // 上半：放置目標
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(Sizes.gap),
              child: _isFigure ? _buildFigure() : _buildSlotRow(),
            ),
          ),
          const Divider(height: 1),
          // 下半：可拖曳的小物件
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(Sizes.gap),
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _remaining
                        .map((DragPiece p) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: _buildDraggable(p),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotRow() {
    // 依可用空間動態算格子邊長：格數多時（例如進階分類 6 格）固定 context.s(130)
    // 會換列超出不可捲的區域、撞黃黑溢出條。挑能塞下又最大的排法，上限不超過設計尺寸。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final int n = _slots.length;
        double best = 0;
        for (int cols = 1; cols <= n; cols++) {
          final int rows = (n / cols).ceil();
          final double w = (c.maxWidth - Sizes.bigGap * (cols - 1)) / cols;
          final double h = (c.maxHeight - Sizes.gap * (rows - 1)) / rows;
          final double side = w < h ? w : h;
          if (side > best) best = side;
        }
        final double slot = best.clamp(0.0, _slotSize);
        return Center(
          child: Wrap(
            spacing: Sizes.bigGap,
            runSpacing: Sizes.gap,
            alignment: WrapAlignment.center,
            children:
                List<Widget>.generate(n, (int i) => _buildSlot(i, slot)),
          ),
        );
      },
    );
  }

  /// 拼圖：把目標格子「由上到下垂直堆疊」（屋頂在上、屋身在下＝房子），
  /// 保證不重疊。
  Widget _buildFigure() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < _slots.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 6),
              _buildSlot(i, _slotSize),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(int i, double size) {
    final DropSlot slot = _slots[i];
    final bool full = _slotFill[i] >= slot.capacity;
    return DragTarget<DragPiece>(
      onWillAcceptWithDetails: (DragTargetDetails<DragPiece> d) =>
          !_lock && !full && d.data.category == slot.category,
      onAcceptWithDetails: (DragTargetDetails<DragPiece> d) =>
          _accept(i, d.data),
      builder: (BuildContext context, List<DragPiece?> cand, List<dynamic> rej) {
        final bool hover = cand.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: hover
                ? slot.color.withValues(alpha: 0.35)
                : slot.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(Sizes.radius),
            border: Border.all(
              color: slot.color,
              width: hover ? 6 : 3,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              // 用 FittedBox 把內容縮進格子，避免溢出（黃黑警示線）。
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _slotContent(slot, i),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _slotContent(DropSlot slot, int i) {
    // 容量 1 且已填：顯示填入的形狀。
    if (slot.capacity == 1 && _slotFill[i] >= 1) {
      if (slot.shape != null) {
        return ShapeView(kind: slot.shape!, color: slot.color, size: context.s(96));
      }
      if (slot.emoji != null) {
        return Text(slot.emoji!, style: TextStyle(fontSize: context.s(64)));
      }
    }
    // 未填：顯示提示（形狀外框 / emoji / 文字標籤 + 計數）
    final List<Widget> bits = <Widget>[];
    if (slot.shape != null) {
      bits.add(ShapeView(kind: slot.shape!, color: slot.color, size: context.s(96), filled: false));
    } else if (slot.emoji != null) {
      bits.add(Text(slot.emoji!, style: TextStyle(fontSize: context.s(56))));
    }
    if (slot.label.isNotEmpty) {
      bits.add(Text(slot.label,
          style: TextStyle(fontSize: context.s(16), fontWeight: FontWeight.bold)));
    }
    if (slot.capacity > 1 && _slotFill[i] > 0) {
      bits.add(Text('×${_slotFill[i]}',
          style: TextStyle(fontSize: context.s(18), fontWeight: FontWeight.bold)));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: bits);
  }

  Widget _buildDraggable(DragPiece p) {
    final Widget content = _pieceContent(p, context.s(96));
    return Draggable<DragPiece>(
      data: p,
      feedback: Transform.scale(scale: 1.15, child: content),
      childWhenDragging: Opacity(opacity: 0.3, child: content),
      // 放錯目標時會自己彈回，不出「再試一次」、不計為錯誤
      // （只放得進正確的籃子/洞，放完必定正確）。
      child: content,
    );
  }

  Widget _pieceContent(DragPiece p, double size) {
    if (p.shape != null) {
      return ShapeView(kind: p.shape!, color: p.color, size: size);
    }
    if (p.emoji != null) {
      return Text(p.emoji!, style: TextStyle(fontSize: size * 0.75));
    }
    return SizedBox(width: size, height: size);
  }
}
