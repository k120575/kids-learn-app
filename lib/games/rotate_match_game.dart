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

/// 轉轉看（5-6 空間）：上方一個圖形，下方四個。其中一個「轉一轉就會變成一樣」，
/// 其餘是鏡像（翻面，怎麼轉都不會一樣）。點出能旋轉吻合的那個。
///
/// 發展理據：心像旋轉（mental rotation）約在 5-6 歲萌芽，是空間能力的核心。
/// 刻意用「鏡像」當干擾——逼孩子真的在腦中把圖形轉起來比對，而不是靠顏色或數量。
/// 這跟對稱鏡像（補另一半）、拼圖（位置擺放）是不同的空間動作。
class RotateMatchGame extends StatefulWidget {
  const RotateMatchGame({
    super.key,
    required this.gameId,
    required this.title,
    this.rounds = 6,
  });

  final String gameId;
  final String title;
  final int rounds;

  // 候選圖形（手性多邊形 polyomino，cell 座標）。執行期會驗證手性，
  // 確保鏡像永遠不等於任何旋轉，避免出現「兩個都對」。
  static const List<List<Point<int>>> _tetromino = <List<Point<int>>>[
    // L
    <Point<int>>[Point<int>(0, 0), Point<int>(0, 1), Point<int>(0, 2), Point<int>(1, 2)],
    // S
    <Point<int>>[Point<int>(1, 0), Point<int>(2, 0), Point<int>(0, 1), Point<int>(1, 1)],
  ];
  static const List<List<Point<int>>> _pentomino = <List<Point<int>>>[
    // F
    <Point<int>>[Point<int>(1, 0), Point<int>(2, 0), Point<int>(0, 1), Point<int>(1, 1), Point<int>(1, 2)],
    // N
    <Point<int>>[Point<int>(1, 0), Point<int>(1, 1), Point<int>(0, 2), Point<int>(1, 2), Point<int>(0, 3)],
    // Y
    <Point<int>>[Point<int>(1, 0), Point<int>(0, 1), Point<int>(1, 1), Point<int>(1, 2), Point<int>(1, 3)],
    // Z
    <Point<int>>[Point<int>(0, 0), Point<int>(1, 0), Point<int>(1, 1), Point<int>(1, 2), Point<int>(2, 2)],
  ];

  static const List<Color> _colors = <Color>[
    Color(0xFF42A5F5), Color(0xFFEF5350), Color(0xFF66BB6A),
    Color(0xFFAB47BC), Color(0xFFFFA726), Color(0xFF26A69A),
  ];

  @override
  State<RotateMatchGame> createState() => _RotateMatchGameState();
}

class _RotateMatchGameState extends State<RotateMatchGame> {
  final Random _rng = Random();
  late List<Point<int>> _target;
  late List<List<Point<int>>> _options;
  late int _correct;
  late Color _color;
  int _i = 0;
  bool _lock = false;
  bool _success = false;
  int _mistakes = 0;
  final Map<int, int> _wrong = <int, int>{};

  // ---- 幾何工具：旋轉 90°、水平鏡像、正規化到 (0,0) 起點 ----
  static List<Point<int>> _normalize(List<Point<int>> s) {
    final int minX = s.map((Point<int> p) => p.x).reduce(min);
    final int minY = s.map((Point<int> p) => p.y).reduce(min);
    final List<Point<int>> out =
        s.map((Point<int> p) => Point<int>(p.x - minX, p.y - minY)).toList();
    out.sort((Point<int> a, Point<int> b) =>
        a.x != b.x ? a.x - b.x : a.y - b.y);
    return out;
  }

  static List<Point<int>> _rot(List<Point<int>> s) =>
      _normalize(s.map((Point<int> p) => Point<int>(p.y, -p.x)).toList());

  static List<Point<int>> _mirror(List<Point<int>> s) =>
      _normalize(s.map((Point<int> p) => Point<int>(-p.x, p.y)).toList());

  static String _key(List<Point<int>> s) =>
      _normalize(s).map((Point<int> p) => '${p.x},${p.y}').join(';');

  /// 一個圖形的所有相異旋轉。
  static List<List<Point<int>>> _rotations(List<Point<int>> base) {
    final List<List<Point<int>>> out = <List<Point<int>>>[];
    final Set<String> seen = <String>{};
    List<Point<int>> cur = _normalize(base);
    for (int k = 0; k < 4; k++) {
      final String key = _key(cur);
      if (seen.add(key)) out.add(cur);
      cur = _rot(cur);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _gen();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice('轉一轉，哪一個一樣？'),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _gen() {
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    // 5-6 的心像旋轉準確率仍低、個別差異大：預設(含一般)只用 4 格 tetromino。
    // pentomino(5 格)＋鏡像是 MR 最難變體，只放「挑戰」階——孩子連續全對才會爬到。
    final List<List<Point<int>>> pool = level < 2
        ? RotateMatchGame._tetromino
        : <List<Point<int>>>[
            ...RotateMatchGame._tetromino,
            ...RotateMatchGame._pentomino,
          ];

    // 找一個「手性」圖形：鏡像的旋轉集合與本體旋轉集合不相交，
    // 且鏡像至少有 3 個相異旋轉（才湊得出 3 個干擾項）。
    late List<List<Point<int>>> rots;
    late List<List<Point<int>>> mrots;
    for (int attempt = 0; attempt < 30; attempt++) {
      final List<Point<int>> base = pool[_rng.nextInt(pool.length)];
      rots = _rotations(base);
      mrots = _rotations(_mirror(base));
      final Set<String> rotKeys =
          rots.map((List<Point<int>> s) => _key(s)).toSet();
      final bool chiral =
          mrots.every((List<Point<int>> s) => !rotKeys.contains(_key(s)));
      if (chiral && mrots.length >= 3) break;
    }

    _target = rots[_rng.nextInt(rots.length)];
    final List<Point<int>> correct = rots[_rng.nextInt(rots.length)];
    final List<List<Point<int>>> distract =
        (List<List<Point<int>>>.of(mrots)..shuffle(_rng)).take(3).toList();
    _options = <List<Point<int>>>[correct, ...distract]..shuffle(_rng);
    _correct = _options.indexWhere((List<Point<int>> s) => identical(s, correct));
    _color = RotateMatchGame._colors[_rng.nextInt(RotateMatchGame._colors.length)];
    _wrong.clear();
    _lock = false;
    _success = false;
  }

  Future<void> _onTap(int idx) async {
    if (_lock) return;
    if (idx == _correct) {
      setState(() {
        _lock = true;
        _success = true;
      });
      AudioService.instance.correct();
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (!mounted) return;
      if (_i < widget.rounds - 1) {
        setState(() {
          _i++;
          _gen();
        });
      } else {
        final bool again =
            await finishGame(context, widget.gameId, mistakes: _mistakes);
        if (!mounted) return;
        if (again) {
          setState(() {
            _i = 0;
            _mistakes = 0;
            _gen();
          });
        } else {
          Navigator.of(context).maybePop();
        }
      }
    } else {
      AudioService.instance.wrong();
      _mistakes++;
      setState(() => _wrong[idx] = (_wrong[idx] ?? 0) + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: widget.title,
      current: _i,
      total: widget.rounds,
      onReplay: () => AudioService.instance.speak('轉一轉，哪一個一樣？'),
      child: Stack(
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // 目標圖形。
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(Sizes.radius),
                  border: Border.all(color: const Color(0xFFFFC107), width: 4),
                ),
                child: _ShapeView(
                    cells: _target, color: _color, box: context.s(108)),
              ),
              SizedBox(height: context.s(18)),
              // 四個選項。
              Wrap(
                spacing: Sizes.bigGap,
                runSpacing: Sizes.gap,
                alignment: WrapAlignment.center,
                children: List<Widget>.generate(_options.length, (int idx) {
                  final bool win = _success && idx == _correct;
                  return Shaker(
                    trigger: _wrong[idx] ?? 0,
                    child: GestureDetector(
                      onTap: () => _onTap(idx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: win ? const Color(0xFFC8E6C9) : Colors.white,
                          borderRadius: BorderRadius.circular(Sizes.radius),
                          border: Border.all(
                            color: win
                                ? const Color(0xFF4CAF50)
                                : Colors.grey.shade300,
                            width: win ? 6 : 3,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _ShapeView(
                            cells: _options[idx],
                            color: _color,
                            box: context.s(96)),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          if (_success) const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }
}

/// 把一組 cell 座標畫成方塊圖形，整體塞進 [box]×[box] 的方框內。
class _ShapeView extends StatelessWidget {
  const _ShapeView(
      {required this.cells, required this.color, required this.box});

  final List<Point<int>> cells;
  final Color color;
  final double box;

  @override
  Widget build(BuildContext context) {
    final int w = cells.map((Point<int> p) => p.x).reduce(max) + 1;
    final int h = cells.map((Point<int> p) => p.y).reduce(max) + 1;
    final int dim = max(w, h);
    final double cell = box / dim;
    final Set<String> filled =
        cells.map((Point<int> p) => '${p.x},${p.y}').toSet();
    // 置中：把圖形在 dim×dim 方格內水平/垂直置中。
    final int offX = (dim - w) ~/ 2;
    final int offY = (dim - h) ~/ 2;
    return SizedBox(
      width: box,
      height: box,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(dim, (int gy) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(dim, (int gx) {
              final bool on = filled.contains('${gx - offX},${gy - offY}');
              return Container(
                width: cell,
                height: cell,
                decoration: BoxDecoration(
                  color: on ? color : Colors.transparent,
                  border: on
                      ? Border.all(color: Colors.white, width: 1.5)
                      : null,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}
