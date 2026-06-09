import 'dart:math';

import 'package:flutter/material.dart';

import '../core/widgets/shape_view.dart';
import '../games/count_tap_game.dart';
import '../games/drag_match_game.dart';

/// 數數點點 50 題庫（圖案 × 數量 3-15）。每局隨機抽題。
const List<String> _countEmojis = <String>[
  '🍎', '⭐', '🐟', '🍌', '🐥', '🐶', '🎈', '🌸', '🐱', '🐰',
  '🚗', '🍓', '🦋', '🐸', '🐢', '🍇', '🐝', '🌻', '🍪', '🐞',
];

final List<CountRound> countBank = <CountRound>[
  for (int i = 0; i < 50; i++)
    CountRound(emoji: _countEmojis[i % _countEmojis.length], count: 3 + (i % 13)),
];

const Color _red = Color(0xFFEF5350);
const Color _blue = Color(0xFF42A5F5);
const Color _yellow = Color(0xFFFFCA28);
const Color _green = Color(0xFF66BB6A);

/// 顏色分類隨機版面：4 色籃子，每色 1-4 顆圓點（每局隨機）。
(List<DragPiece>, List<DropSlot>) makeColorSortBoard() {
  final Random rng = Random();
  const List<(Color, String, String)> colors = <(Color, String, String)>[
    (_red, 'red', '紅色'),
    (_blue, 'blue', '藍色'),
    (_yellow, 'yellow', '黃色'),
    (_green, 'green', '綠色'),
  ];
  final List<DropSlot> slots = <DropSlot>[];
  final List<DragPiece> pieces = <DragPiece>[];
  int id = 0;
  for (final (Color, String, String) c in colors) {
    slots.add(DropSlot(
        category: c.$2, color: c.$1, emoji: '🧺', label: c.$3, capacity: 12));
    final int n = 1 + rng.nextInt(4);
    for (int k = 0; k < n; k++) {
      pieces.add(DragPiece(
          id: '${c.$2}${id++}',
          category: c.$2,
          shape: ShapeKind.circle,
          color: c.$1));
    }
  }
  return (pieces, slots);
}

/// 進階分類隨機版面：顏色＋形狀重組成多格分類（每局隨機）。
/// - 一般(3-4歲)：2 色 × 2 形 = 4 格、每格 1-3 個。
/// - [hard](5-6歲)：3 色 × 2 形 = 6 格、每格 1-4 個，需同時辨顏色與形狀分更多類。
(List<DragPiece>, List<DropSlot>) makeAdvancedSortBoard({bool hard = false}) {
  final Random rng = Random();
  final List<(Color, String)> cols = <(Color, String)>[
    (_red, 'r'),
    (_blue, 'b'),
    (_yellow, 'y'),
    (_green, 'g'),
  ]..shuffle(rng);
  final List<(ShapeKind, String)> shps = <(ShapeKind, String)>[
    (ShapeKind.circle, 'c'),
    (ShapeKind.square, 's'),
    (ShapeKind.triangle, 't'),
  ]..shuffle(rng);
  final int colCount = hard ? 3 : 2;
  final int cap = hard ? 4 : 3;
  final List<DropSlot> slots = <DropSlot>[];
  final List<DragPiece> pieces = <DragPiece>[];
  int id = 0;
  for (final (Color, String) c in cols.take(colCount)) {
    for (final (ShapeKind, String) s in shps.take(2)) {
      final String cat = '${c.$2}_${s.$2}';
      slots.add(DropSlot(category: cat, shape: s.$1, color: c.$1, capacity: cap));
      final int n = 1 + rng.nextInt(cap);
      for (int k = 0; k < n; k++) {
        pieces.add(
            DragPiece(id: '$cat${id++}', category: cat, shape: s.$1, color: c.$1));
      }
    }
  }
  return (pieces, slots);
}
