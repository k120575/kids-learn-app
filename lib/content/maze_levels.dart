import '../games/maze_game.dart';

/// 迷宮關卡（3-4 歲）：單一路徑、2-3 個轉角、無死巷。
/// 字元：S=起點(小老鼠)、G=終點(起司)、#=牆、.=路。每列長度需一致。
const List<MazeLevel> mazeLevels = <MazeLevel>[
  MazeLevel(<String>[
    'S...',
    '###.',
    '###G',
  ]),
  MazeLevel(<String>[
    'S..#',
    '##.#',
    '##..',
    '###G',
  ]),
  MazeLevel(<String>[
    'S....',
    '####.',
    '.....',
    '.####',
    'G####',
  ]),
  MazeLevel(<String>[
    'S....',
    '.###.',
    '.#G#.',
    '.#.#.',
    '...#.',
  ]),
  MazeLevel(<String>[
    'S....',
    '####.',
    'G....',
  ]),
  MazeLevel(<String>[
    'S...',
    '###.',
    '###.',
    'G...',
  ]),
  MazeLevel(<String>[
    'S###',
    '...#',
    '##.#',
    '##.G',
  ]),
  MazeLevel(<String>[
    'S....',
    '####.',
    '.....',
    '.####',
    '.G###',
  ]),
];
