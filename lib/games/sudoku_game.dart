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

/// 數獨小將（5-6）：4×4 圖案數獨。每一行、每一列、每個 2×2 宮格裡，
/// 四個魔法符號都只能出現一次。點空格選格子，再從下方選符號填入。
/// 適性難度：簡單給 10 格、一般 8 格、挑戰 6 格（其餘要自己推理）。
class SudokuGame extends StatefulWidget {
  const SudokuGame({
    super.key,
    required this.gameId,
    required this.title,
    this.rounds = 4,
  });

  final String gameId;
  final String title;
  final int rounds;

  @override
  State<SudokuGame> createState() => _SudokuGameState();
}

class _SudokuGameState extends State<SudokuGame> {
  static const List<String> _symbols = <String>['⭐', '🌙', '🔥', '❄️'];
  static const int _n = 4;

  final Random _rng = Random();
  late List<List<int>> _solution; // 正解 0..3
  late List<List<int>> _board; // -1=空，0..3=已填（題目給的或玩家填對的）
  late List<List<bool>> _given; // 是否為題目給的格（不可改）
  int? _selR;
  int? _selC;
  final Set<int> _wrongCells = <int>{}; // 全部填完檢查後，答錯的格子 index（標紅）
  int _i = 0;
  bool _lock = false;
  bool _success = false;
  int _mistakes = 0;

  @override
  void initState() {
    super.initState();
    _gen();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice('每一行、每一列都不能有一樣的！'),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  int _givensCount() {
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    return level == 0 ? 10 : (level == 1 ? 8 : 6);
  }

  void _gen() {
    _solution = _makeSolution();
    _given = List<List<bool>>.generate(_n, (_) => List<bool>.filled(_n, false));
    _board = List<List<int>>.generate(_n, (_) => List<int>.filled(_n, -1));
    // 隨機挑 N 格當題目給定。
    final List<int> cells = List<int>.generate(_n * _n, (int k) => k)
      ..shuffle(_rng);
    final int give = _givensCount();
    for (int k = 0; k < give; k++) {
      final int r = cells[k] ~/ _n;
      final int c = cells[k] % _n;
      _given[r][c] = true;
      _board[r][c] = _solution[r][c];
    }
    _selR = null;
    _selC = null;
    _wrongCells.clear();
    _lock = false;
    _success = false;
  }

  /// 產生一個合法的 4×4（含 2×2 宮）解：從基底解做保持有效性的隨機變換。
  List<List<int>> _makeSolution() {
    List<List<int>> g = <List<int>>[
      <int>[0, 1, 2, 3],
      <int>[2, 3, 0, 1],
      <int>[1, 0, 3, 2],
      <int>[3, 2, 1, 0],
    ];
    // 重貼標籤（符號排列）
    final List<int> perm = <int>[0, 1, 2, 3]..shuffle(_rng);
    g = <List<int>>[
      for (final List<int> row in g) <int>[for (final int v in row) perm[v]],
    ];
    // 同一帶內換列（0↔1、2↔3）、換帶（{0,1}↔{2,3}）
    if (_rng.nextBool()) _swapRows(g, 0, 1);
    if (_rng.nextBool()) _swapRows(g, 2, 3);
    if (_rng.nextBool()) {
      _swapRows(g, 0, 2);
      _swapRows(g, 1, 3);
    }
    // 同一堆內換行、換堆
    if (_rng.nextBool()) _swapCols(g, 0, 1);
    if (_rng.nextBool()) _swapCols(g, 2, 3);
    if (_rng.nextBool()) {
      _swapCols(g, 0, 2);
      _swapCols(g, 1, 3);
    }
    return g;
  }

  void _swapRows(List<List<int>> g, int a, int b) {
    final List<int> tmp = g[a];
    g[a] = g[b];
    g[b] = tmp;
  }

  void _swapCols(List<List<int>> g, int a, int b) {
    for (final List<int> row in g) {
      final int tmp = row[a];
      row[a] = row[b];
      row[b] = tmp;
    }
  }

  void _selectCell(int r, int c) {
    if (_lock || _given[r][c]) return; // 題目給定的格子不可改
    AudioService.instance.tap();
    setState(() {
      _selR = r;
      _selC = c;
      _wrongCells.remove(r * _n + c); // 重選這格 → 清掉它的紅色標記
    });
  }

  /// 自由填入（對錯都先填），全部填完才一次檢查（不再一選錯就「再試一次」）。
  Future<void> _placeSymbol(int sym) async {
    if (_lock || _selR == null || _selC == null) return;
    final int r = _selR!;
    final int c = _selC!;
    AudioService.instance.tap();
    setState(() {
      _board[r][c] = sym;
      _wrongCells.remove(r * _n + c);
      _selR = null;
      _selC = null;
    });
    if (_isComplete()) await _check();
  }

  /// 全部填完後檢查：全對 → 過關歡呼；有錯 → 說「再試一次」並把錯的格子標紅，讓孩子修。
  Future<void> _check() async {
    final Set<int> wrong = <int>{};
    for (int r = 0; r < _n; r++) {
      for (int c = 0; c < _n; c++) {
        if (_board[r][c] != _solution[r][c]) wrong.add(r * _n + c);
      }
    }
    if (wrong.isEmpty) {
      _lock = true;
      setState(() => _success = true);
      AudioService.instance.correct();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      if (_i < widget.rounds - 1) {
        setState(() {
          _i++;
          _gen();
        });
        AudioService.instance.speak('每一行、每一列都不能有一樣的！');
      } else {
        await _finish();
      }
    } else {
      _mistakes += wrong.length;
      AudioService.instance.wrong(); // 「再試一次」
      setState(() {
        _wrongCells
          ..clear()
          ..addAll(wrong);
      });
    }
  }

  bool _isComplete() {
    for (int r = 0; r < _n; r++) {
      for (int c = 0; c < _n; c++) {
        if (_board[r][c] < 0) return false;
      }
    }
    return true;
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
      AudioService.instance.speak('每一行、每一列都不能有一樣的！');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: widget.title,
      current: _i,
      total: widget.rounds,
      onReplay: () => AudioService.instance.speak('每一行、每一列都不能有一樣的！'),
      child: Stack(
        children: <Widget>[
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.s(Sizes.gap)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '每行、每列、每宮都不能重複',
                    style: TextStyle(
                      fontSize: context.s(18),
                      color: const Color(0xFF888888),
                    ),
                  ),
                  SizedBox(height: context.s(Sizes.gap)),
                  // 窄螢幕時整個盤面等比縮小，不會被裁切。
                  FittedBox(fit: BoxFit.scaleDown, child: _grid()),
                  SizedBox(height: context.s(Sizes.bigGap)),
                  Text(
                    '選一格，再點要填的符號',
                    style: TextStyle(
                      fontSize: context.s(16),
                      color: const Color(0xFF888888),
                    ),
                  ),
                  SizedBox(height: context.s(10)),
                  _palette(),
                ],
              ),
            ),
          ),
          if (_success) const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }

  Widget _grid() {
    return Container(
      padding: EdgeInsets.all(context.s(4)),
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(_n, (int r) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(_n, (int c) {
              final int v = _board[r][c];
              final bool given = _given[r][c];
              final bool sel = _selR == r && _selC == c;
              final bool wrong = _wrongCells.contains(r * _n + c);
              // 2×2 宮格分隔：較粗的外距。
              return Container(
                margin: EdgeInsets.only(
                  right: context.s(c == 1 ? 5 : 2),
                  bottom: context.s(r == 1 ? 5 : 2),
                  left: context.s(2),
                  top: context.s(2),
                ),
                child: GestureDetector(
                  onTap: () => _selectCell(r, c),
                  child: Container(
                    width: context.s(62),
                    height: context.s(62),
                    decoration: BoxDecoration(
                      color: wrong
                          ? const Color(0xFFFFCDD2)
                          : given
                          ? const Color(0xFFEDE7F6)
                          : (sel ? const Color(0xFFFFF3CD) : Colors.white),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: wrong
                            ? const Color(0xFFE53935)
                            : sel
                            ? const Color(0xFFFFC107)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        v < 0 ? '' : _symbols[v],
                        style: TextStyle(fontSize: context.s(34)),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _palette() {
    return Wrap(
      spacing: context.s(Sizes.gap),
      alignment: WrapAlignment.center,
      children: List<Widget>.generate(_symbols.length, (int s) {
        return GestureDetector(
          onTap: () => _placeSymbol(s),
          child: Container(
            width: context.s(64),
            height: context.s(64),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF7C4DFF), width: 3),
            ),
            child: Center(
              child: Text(
                _symbols[s],
                style: TextStyle(fontSize: context.s(36)),
              ),
            ),
          ),
        );
      }),
    );
  }
}
