import 'dart:math';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/game_complete.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/game_scaffold.dart';

/// 一個迷宮：字元 S=起點、G=終點、#=牆、.=路。各列長度需一致。
class MazeLevel {
  const MazeLevel(this.rows);
  final List<String> rows;

  int get rowCount => rows.length;
  int get colCount => rows[0].length;
  bool isWall(int r, int c) => rows[r][c] == '#';

  (int, int) find(String ch) {
    for (int r = 0; r < rows.length; r++) {
      final int i = rows[r].indexOf(ch);
      if (i >= 0) return (r, i);
    }
    return (0, 0);
  }
}

/// 走迷宮（3-4 歲）：用方向鍵把小老鼠帶到起司。觸覺/碰牆回饋，抵達即過關。
class MazeGame extends StatefulWidget {
  const MazeGame({
    super.key,
    required this.gameId,
    required this.title,
    this.levels = const <MazeLevel>[],
    this.intro = '用箭頭幫小老鼠走到起司！',
    this.pickCount,
    this.generator,
    this.genCount = 5,
  });

  final String gameId;
  final String title;
  final String intro;
  final List<MazeLevel> levels;

  /// 每局隨機抽幾關（null = 全部）。
  final int? pickCount;

  /// 迷宮產生器（每局即時產生 [genCount] 個，做到無限變化／難度可調）。
  final MazeLevel Function()? generator;
  final int genCount;

  @override
  State<MazeGame> createState() => _MazeGameState();
}

class _MazeGameState extends State<MazeGame> {
  int _i = 0;
  int _r = 0;
  int _c = 0;
  bool _lock = false;

  late List<MazeLevel> _levels;

  MazeLevel get _maze => _levels[_i];

  void _prepare() {
    if (widget.generator != null) {
      _levels = List<MazeLevel>.generate(
          widget.genCount, (_) => widget.generator!());
      return;
    }
    _levels = List<MazeLevel>.of(widget.levels)..shuffle();
    final int? n = widget.pickCount;
    if (n != null && n < _levels.length) {
      _levels = _levels.sublist(0, n);
    }
  }

  @override
  void initState() {
    super.initState();
    _prepare();
    _load();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speak(widget.intro),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _load() {
    final (int, int) s = _maze.find('S');
    _r = s.$1;
    _c = s.$2;
  }

  Future<void> _move(int dr, int dc) async {
    if (_lock) return;
    final int nr = _r + dr;
    final int nc = _c + dc;
    if (nr < 0 || nc < 0 || nr >= _maze.rowCount || nc >= _maze.colCount) {
      return;
    }
    if (_maze.isWall(nr, nc)) {
      AudioService.instance.tap(); // 碰牆：只給觸覺，不責備
      return;
    }
    setState(() {
      _r = nr;
      _c = nc;
    });
    AudioService.instance.tap();

    final (int, int) g = _maze.find('G');
    if (_r == g.$1 && _c == g.$2) {
      _lock = true;
      AudioService.instance.speak('你走到了！');
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      if (_i < _levels.length - 1) {
        setState(() {
          _i++;
          _load();
          _lock = false;
        });
      } else {
        final bool again = await finishGame(context, widget.gameId);
        if (!mounted) return;
        if (again) {
          setState(() {
            _prepare(); // 再玩一次重新抽關
            _i = 0;
            _load();
            _lock = false;
          });
        } else {
          Navigator.of(context).maybePop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: widget.title,
      current: _i,
      total: _levels.length,
      onReplay: () => AudioService.instance.speak(widget.intro),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(Sizes.gap),
              child: _MazeBoard(maze: _maze, r: _r, c: _c),
            ),
          ),
          SizedBox(
            width: context.s(240),
            child: Center(
              child: _DPad(
                onUp: () => _move(-1, 0),
                onDown: () => _move(1, 0),
                onLeft: () => _move(0, -1),
                onRight: () => _move(0, 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MazeBoard extends StatelessWidget {
  const _MazeBoard({required this.maze, required this.r, required this.c});

  final MazeLevel maze;
  final int r;
  final int c;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints cons) {
        final double cell = <double>[
          cons.maxWidth / maze.colCount,
          cons.maxHeight / maze.rowCount,
        ].reduce(min).floorToDouble();
        return Center(
          child: SizedBox(
            width: cell * maze.colCount,
            height: cell * maze.rowCount,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(maze.rowCount, (int rr) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List<Widget>.generate(maze.colCount, (int cc) {
                    final bool wall = maze.isWall(rr, cc);
                    final bool isGoal = maze.rows[rr][cc] == 'G';
                    final bool isMouse = rr == r && cc == c;
                    return Container(
                      width: cell,
                      height: cell,
                      decoration: BoxDecoration(
                        color: wall
                            ? const Color(0xFF8D6E63)
                            : const Color(0xFFFFF8E1),
                        border: Border.all(
                            color: const Color(0x22000000), width: 0.5),
                      ),
                      child: Center(
                        child: Text(
                          isMouse ? '🐭' : (isGoal ? '🧀' : ''),
                          style: TextStyle(fontSize: cell * 0.62),
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _DPad extends StatelessWidget {
  const _DPad({
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
  });

  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  Widget _btn(IconData icon, VoidCallback cb, double iconSize) {
    return Material(
      color: const Color(0xFF66BB6A),
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: cb,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(icon, size: iconSize, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = context.s(44);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _btn(Icons.keyboard_arrow_up_rounded, onUp, iconSize),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _btn(Icons.keyboard_arrow_left_rounded, onLeft, iconSize),
            const SizedBox(width: 72),
            _btn(Icons.keyboard_arrow_right_rounded, onRight, iconSize),
          ],
        ),
        const SizedBox(height: 12),
        _btn(Icons.keyboard_arrow_down_rounded, onDown, iconSize),
      ],
    );
  }
}
