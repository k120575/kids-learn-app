import 'dart:math';

import '../games/maze_game.dart';

/// 程序產生迷宮（遞迴回溯 / DFS）：完美迷宮，含死巷、S→G 唯一解。
/// [size] = 房間數；輸出格子邊長 = size*2+1（size 4 → 9×9）。
MazeLevel genHardMaze(int size) {
  final Random rng = Random();
  final int dim = size * 2 + 1;
  final List<List<bool>> wall =
      List<List<bool>>.generate(dim, (_) => List<bool>.filled(dim, true));

  void carve(int r, int c) {
    wall[r][c] = false;
    final List<List<int>> dirs = <List<int>>[
      <int>[-2, 0], <int>[2, 0], <int>[0, -2], <int>[0, 2],
    ]..shuffle(rng);
    for (final List<int> d in dirs) {
      final int nr = r + d[0];
      final int nc = c + d[1];
      if (nr > 0 && nr < dim - 1 && nc > 0 && nc < dim - 1 && wall[nr][nc]) {
        wall[r + d[0] ~/ 2][c + d[1] ~/ 2] = false; // 打通中間的牆
        carve(nr, nc);
      }
    }
  }

  carve(1, 1);

  final List<String> rows = <String>[];
  for (int r = 0; r < dim; r++) {
    final StringBuffer sb = StringBuffer();
    for (int c = 0; c < dim; c++) {
      if (r == 1 && c == 1) {
        sb.write('S');
      } else if (r == dim - 2 && c == dim - 2) {
        sb.write('G');
      } else {
        sb.write(wall[r][c] ? '#' : '.');
      }
    }
    rows.add(sb.toString());
  }
  return MazeLevel(rows);
}
