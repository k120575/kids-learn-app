import 'dart:math';

import 'package:flutter/material.dart';

import '../core/widgets/shape_view.dart';
import '../games/drag_match_game.dart';

const Color _blue = Color(0xFF42A5F5);
const Color _green = Color(0xFF66BB6A);
const Color _yellow = Color(0xFFFFCA28);
const Color _purple = Color(0xFFAB47BC);
const Color _red = Color(0xFFEF5350);
const Color _orange = Color(0xFFFF7043);

/// 形狀配對隨機版面：1 對 1 把形狀放進對應外框（每局隨機）。
/// 形狀池含「圓形 vs 橢圓形」（4 歲開始能區分）。
/// - 一般(3-4歲)：抽 4 種形狀，每種「碎片色＝洞口色」→ 顏色是輔助線索。
/// - [hard](5-6歲)：用滿 5 種形狀，且「碎片色 ≠ 它的洞口色」（顏色被打亂成干擾項）
///   → 不能靠顏色配對，必須真的看「形狀」。比同色版更耐玩、也比全灰好看。
(List<DragPiece>, List<DropSlot>) makeShapeMatchBoard({bool hard = false}) {
  final Random rng = Random();
  final List<(ShapeKind, String)> shapes = <(ShapeKind, String)>[
    (ShapeKind.circle, 'circle'),
    (ShapeKind.oval, 'oval'),
    (ShapeKind.square, 'square'),
    (ShapeKind.triangle, 'triangle'),
    (ShapeKind.star, 'star'),
  ]..shuffle(rng);
  final List<Color> palette = <Color>[_blue, _orange, _green, _yellow, _purple, _red]
    ..shuffle(rng);
  final List<DropSlot> slots = <DropSlot>[];
  final List<DragPiece> pieces = <DragPiece>[];
  final List<(ShapeKind, String)> chosen = shapes.take(hard ? 5 : 4).toList();
  final int n = chosen.length;
  // 加難版：碎片顏色相對洞口「整體位移」一格，保證每個形狀的兩色都不一樣。
  final int shift = hard ? 1 + rng.nextInt(n - 1) : 0;
  for (int i = 0; i < n; i++) {
    final (ShapeKind, String) s = chosen[i];
    final Color slotColor = palette[i % palette.length];
    final Color pieceColor = hard ? palette[(i + shift) % n] : slotColor;
    slots.add(DropSlot(category: s.$2, shape: s.$1, color: slotColor));
    pieces.add(DragPiece(id: s.$2, category: s.$2, shape: s.$1, color: pieceColor));
  }
  return (pieces, slots);
}

/// 拼圖隨機版面：每局隨機選一種「圖案」（由上到下的形狀堆疊）、隨機配色。
/// slot 帶 `at` 以觸發拼圖（垂直堆疊）版面；實際順序由清單由上到下排列。
/// - 一般(3-4歲)：2-3 塊的簡單圖案。
/// - [hard](5-6歲)：4-5 塊的複雜圖案，需排對更多層的順序與形狀。
(List<DragPiece>, List<DropSlot>) makePuzzleBoard({bool hard = false}) {
  final Random rng = Random();
  const List<List<ShapeKind>> figures = <List<ShapeKind>>[
    <ShapeKind>[ShapeKind.triangle, ShapeKind.square], // 房子
    <ShapeKind>[ShapeKind.circle, ShapeKind.square], // 雪人/人
    <ShapeKind>[ShapeKind.star, ShapeKind.triangle, ShapeKind.square], // 星＋樹
    <ShapeKind>[ShapeKind.circle, ShapeKind.triangle, ShapeKind.square],
    <ShapeKind>[ShapeKind.triangle, ShapeKind.triangle, ShapeKind.square], // 樹
    <ShapeKind>[ShapeKind.oval, ShapeKind.square], // 氣球
  ];
  const List<List<ShapeKind>> hardFigures = <List<ShapeKind>>[
    // 火箭：星＋圓＋三角＋方
    <ShapeKind>[ShapeKind.star, ShapeKind.circle, ShapeKind.triangle, ShapeKind.square],
    // 大樹：三層三角＋樹幹方
    <ShapeKind>[ShapeKind.triangle, ShapeKind.triangle, ShapeKind.triangle, ShapeKind.square],
    // 城堡：星＋方＋三角＋方
    <ShapeKind>[ShapeKind.star, ShapeKind.square, ShapeKind.triangle, ShapeKind.square],
    // 機器人：方＋圓＋方＋橢圓
    <ShapeKind>[ShapeKind.square, ShapeKind.circle, ShapeKind.square, ShapeKind.oval],
    // 高塔：星＋三角＋方＋方＋方
    <ShapeKind>[ShapeKind.star, ShapeKind.triangle, ShapeKind.square, ShapeKind.square, ShapeKind.square],
  ];
  final List<List<ShapeKind>> pool = hard ? hardFigures : figures;
  final List<ShapeKind> fig = pool[rng.nextInt(pool.length)];
  final List<Color> palette = <Color>[_red, _yellow, _green, _blue, _orange, _purple]
    ..shuffle(rng);
  final List<DropSlot> slots = <DropSlot>[];
  final List<DragPiece> pieces = <DragPiece>[];
  for (int i = 0; i < fig.length; i++) {
    final String cat = 'p$i';
    final Color color = palette[i % palette.length];
    slots.add(DropSlot(
        category: cat, shape: fig[i], color: color, at: Alignment.center));
    pieces.add(DragPiece(id: cat, category: cat, shape: fig[i], color: color));
  }
  return (pieces, slots);
}
