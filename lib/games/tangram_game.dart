import 'dart:math';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/game_complete.dart';
import '../core/responsive.dart';
import '../core/widgets/celebration.dart';
import '../core/widgets/fit_box.dart';
import '../core/widgets/game_scaffold.dart';
import '../core/widgets/shape_view.dart';

/// 拼出圖形（簡化七巧板）：上方是一個由數個幾何形狀組成的「完成圖」
/// （房子、火箭、機器人…），孩子把托盤裡的形狀拖進圖案上對應的外框，
/// 拼出一模一樣的圖形。練「形狀組合分解 / 幾何直覺」——核心的早期幾何里程碑，
/// 且刻意「免旋轉、放對自動吸附」（旋轉留給 5-6 的轉轉看）。
///
/// 全部形狀「統一同一個顏色」→ 孩子只能靠「形狀」判斷該放哪，
/// 不會用顏色偷吃步（認顏色配對）。同形狀的塊彼此可互換：
/// 一個三角形塞得進任何空的三角形洞，放錯形狀才會彈回、不責備、不計錯。
class TangramGame extends StatefulWidget {
  const TangramGame({
    super.key,
    required this.gameId,
    required this.title,
    this.rounds = 6,
  });

  final String gameId;
  final String title;
  final int rounds;

  @override
  State<TangramGame> createState() => _TangramGameState();
}

/// 圖案的一塊：形狀，以及在單位方框（0~1）內的中心與邊長。
class _Part {
  const _Part(this.shape, this.cx, this.cy, this.side);
  final ShapeKind shape;
  final double cx;
  final double cy;
  final double side;
}

class _Figure {
  const _Figure(this.parts);
  final List<_Part> parts;
}

class _TangramGameState extends State<TangramGame> {
  static const String _intro = '用小形狀，拼出上面的圖案！';

  /// 全部形狀統一色，逼孩子看「形狀」而非顏色。
  static const Color _piece = Color(0xFF42A5F5);

  /// 圖案庫。形狀不再用顏色區分（統一色），所以可以自由重複同一種形狀，
  /// 拼出更豐富、更複雜的圖案（2~4 塊）。
  ///
  /// 幾何鐵則（避免遊戲盤外框「疊在一起」看起來一團亂）：
  ///  1. 任兩塊的「邊界框」只准共邊相接或相切，【絕不可重疊】。三角形的邊界框是方的、
  ///     但只填下半，所以底邊要正好＝下方那塊的頂邊；並排的塊左右邊要正好貼齊。
  ///  2. 每一塊都要「露在輪廓上」——統一色的完成圖是實心剪影，完全內嵌的塊（門/窗/舷窗）
  ///     會直接隱形、對不上盤面的洞，所以不放內嵌塊。
  /// 本質需要重疊才成形的圖案（星頂城堡、雙帆船、疊嶂、聖誕樹）一律不收。座標落在 0~1 內。
  ///
  /// 難度鐵則：一張圖【盡量混用多種形狀】。整張都同一種形狀（四顆圓、四個方塊）時，
  /// 每塊都能互換 → 隨便丟都對、沒難度；混形狀才逼孩子「辨認每個洞的形狀再挑對的塊」。
  /// 所以偏好 3~5 塊、含 2 種以上形狀的圖案。
  static const List<_Figure> _figures = <_Figure>[
    // 豪華火箭：星頂 + 機鼻(三角) + 機身(方) + 左右尾翼(三角) + 噴焰(圓)，6 塊 4 種形狀
    _Figure(<_Part>[
      _Part(ShapeKind.star, 0.5, 0.08, 0.16),
      _Part(ShapeKind.triangle, 0.5, 0.29, 0.26),
      _Part(ShapeKind.square, 0.5, 0.58, 0.32),
      _Part(ShapeKind.triangle, 0.23, 0.63, 0.22),
      _Part(ShapeKind.triangle, 0.77, 0.63, 0.22),
      _Part(ShapeKind.circle, 0.5, 0.83, 0.18),
    ]),
    // 火車：兩節車身(方) + 四個輪子(圓)，6 塊
    _Figure(<_Part>[
      _Part(ShapeKind.square, 0.28, 0.48, 0.3),
      _Part(ShapeKind.square, 0.68, 0.48, 0.3),
      _Part(ShapeKind.circle, 0.2, 0.71, 0.16),
      _Part(ShapeKind.circle, 0.36, 0.71, 0.16),
      _Part(ShapeKind.circle, 0.6, 0.71, 0.16),
      _Part(ShapeKind.circle, 0.76, 0.71, 0.16),
    ]),
    // 小人：圓頭 + 身(方) + 雙手(三角) + 雙腳(方)，6 塊 3 種形狀
    _Figure(<_Part>[
      _Part(ShapeKind.circle, 0.5, 0.13, 0.22),
      _Part(ShapeKind.square, 0.5, 0.43, 0.38),
      _Part(ShapeKind.triangle, 0.22, 0.4, 0.18),
      _Part(ShapeKind.triangle, 0.78, 0.4, 0.18),
      _Part(ShapeKind.square, 0.42, 0.7, 0.16),
      _Part(ShapeKind.square, 0.58, 0.7, 0.16),
    ]),
    // 圖騰塔：星 + 三角 + 方 + 圓，四種形狀由上而下疊（考驗形狀辨認＋順序）
    _Figure(<_Part>[
      _Part(ShapeKind.star, 0.5, 0.13, 0.22),
      _Part(ShapeKind.triangle, 0.5, 0.37, 0.26),
      _Part(ShapeKind.square, 0.5, 0.62, 0.24),
      _Part(ShapeKind.circle, 0.5, 0.85, 0.22),
    ]),
    // 汽車：車身(方) + 車頂(方) + 雙輪(圓)，4 塊
    _Figure(<_Part>[
      _Part(ShapeKind.square, 0.5, 0.5, 0.44),
      _Part(ShapeKind.square, 0.5, 0.15, 0.26),
      _Part(ShapeKind.circle, 0.34, 0.83, 0.22),
      _Part(ShapeKind.circle, 0.66, 0.83, 0.22),
    ]),
    // 機器人：頭(方) + 身(方) + 雙腳(三角)，4 塊
    _Figure(<_Part>[
      _Part(ShapeKind.square, 0.5, 0.18, 0.28),
      _Part(ShapeKind.square, 0.5, 0.54, 0.44),
      _Part(ShapeKind.triangle, 0.4, 0.85, 0.18),
      _Part(ShapeKind.triangle, 0.6, 0.85, 0.18),
    ]),
    // 戴帽雪人：三顆圓 + 三角帽（要從一堆圓裡認出那顆三角）
    _Figure(<_Part>[
      _Part(ShapeKind.circle, 0.5, 0.8, 0.3),
      _Part(ShapeKind.circle, 0.5, 0.53, 0.24),
      _Part(ShapeKind.circle, 0.5, 0.32, 0.18),
      _Part(ShapeKind.triangle, 0.5, 0.12, 0.22),
    ]),
    // 蠟燭：火焰(三角) + 燭身(方) + 底盤(圓)，3 種形狀
    _Figure(<_Part>[
      _Part(ShapeKind.triangle, 0.5, 0.16, 0.18),
      _Part(ShapeKind.square, 0.5, 0.43, 0.36),
      _Part(ShapeKind.circle, 0.5, 0.78, 0.34),
    ]),
    // 花：花朵(圓) + 花莖(方) + 葉子(三角)，3 種形狀
    _Figure(<_Part>[
      _Part(ShapeKind.circle, 0.5, 0.32, 0.44),
      _Part(ShapeKind.square, 0.5, 0.61, 0.14),
      _Part(ShapeKind.triangle, 0.67, 0.64, 0.2),
    ]),
    // 房子：牆(方) + 屋頂(三角)（保留一個簡單的當變化）
    _Figure(<_Part>[
      _Part(ShapeKind.square, 0.5, 0.72, 0.44),
      _Part(ShapeKind.triangle, 0.5, 0.25, 0.5),
    ]),
    // 魔法棒：星星 + 短棒(方)
    _Figure(<_Part>[
      _Part(ShapeKind.star, 0.5, 0.26, 0.4),
      _Part(ShapeKind.square, 0.5, 0.53, 0.14),
    ]),
    // ---- 2026-08 加量（付費招牌關 11→22 圖；座標已用腳本驗過零重疊/相接/在界內）----
    // 帆船：旗(星) + 帆(三角) + 船身(方)，3 種形狀
    _Figure(<_Part>[
      _Part(ShapeKind.star, 0.5, 0.06, 0.12),
      _Part(ShapeKind.triangle, 0.5, 0.32, 0.4),
      _Part(ShapeKind.square, 0.5, 0.64, 0.24),
    ]),
    // 大樹：兩層樹冠(三角) + 樹幹(方)
    _Figure(<_Part>[
      _Part(ShapeKind.triangle, 0.5, 0.2, 0.3),
      _Part(ShapeKind.triangle, 0.5, 0.53, 0.36),
      _Part(ShapeKind.square, 0.5, 0.81, 0.2),
    ]),
    // 城堡：底座(方) + 塔樓(方) + 塔頂(三角) + 兩側城垛(三角)，5 塊
    _Figure(<_Part>[
      _Part(ShapeKind.square, 0.5, 0.72, 0.4),
      _Part(ShapeKind.square, 0.5, 0.4, 0.24),
      _Part(ShapeKind.triangle, 0.5, 0.14, 0.28),
      _Part(ShapeKind.triangle, 0.2, 0.42, 0.2),
      _Part(ShapeKind.triangle, 0.8, 0.42, 0.2),
    ]),
    // 皇冠：三個尖(三角) + 相連底座(方×3，左右正好貼齊)，6 塊
    _Figure(<_Part>[
      _Part(ShapeKind.triangle, 0.2, 0.32, 0.24),
      _Part(ShapeKind.triangle, 0.5, 0.32, 0.24),
      _Part(ShapeKind.triangle, 0.8, 0.32, 0.24),
      _Part(ShapeKind.square, 0.2, 0.59, 0.3),
      _Part(ShapeKind.square, 0.5, 0.59, 0.3),
      _Part(ShapeKind.square, 0.8, 0.59, 0.3),
    ]),
    // 熱氣球：球(圓) + 吊籃(方) + 籃邊沙包(三角×2)，3 種形狀
    _Figure(<_Part>[
      _Part(ShapeKind.circle, 0.5, 0.3, 0.44),
      _Part(ShapeKind.square, 0.5, 0.62, 0.2),
      _Part(ShapeKind.triangle, 0.31, 0.62, 0.18),
      _Part(ShapeKind.triangle, 0.69, 0.62, 0.18),
    ]),
    // 燈塔：頂燈(圓) + 塔頂(三角) + 塔身(方×2)，3 種形狀由上而下
    _Figure(<_Part>[
      _Part(ShapeKind.circle, 0.5, 0.1, 0.18),
      _Part(ShapeKind.triangle, 0.5, 0.31, 0.24),
      _Part(ShapeKind.square, 0.5, 0.57, 0.28),
      _Part(ShapeKind.square, 0.5, 0.85, 0.28),
    ]),
    // 毛毛蟲：帽(三角) + 頭(圓) + 身體(橢圓×3，唯一用到橢圓的圖之一)
    _Figure(<_Part>[
      _Part(ShapeKind.triangle, 0.14, 0.38, 0.2),
      _Part(ShapeKind.circle, 0.14, 0.6, 0.24),
      _Part(ShapeKind.oval, 0.38, 0.6, 0.24),
      _Part(ShapeKind.oval, 0.62, 0.6, 0.24),
      _Part(ShapeKind.oval, 0.86, 0.6, 0.24),
    ]),
    // 冰淇淋杯：星頂 + 兩球(圓) + 杯(方)，3 種形狀
    _Figure(<_Part>[
      _Part(ShapeKind.star, 0.5, 0.23, 0.2),
      _Part(ShapeKind.circle, 0.38, 0.45, 0.24),
      _Part(ShapeKind.circle, 0.62, 0.45, 0.24),
      _Part(ShapeKind.square, 0.5, 0.72, 0.3),
    ]),
    // 房子和樹：屋頂(三角) + 牆(方) + 樹冠(三角) + 樹幹(方)——小場景
    _Figure(<_Part>[
      _Part(ShapeKind.triangle, 0.35, 0.25, 0.34),
      _Part(ShapeKind.square, 0.35, 0.59, 0.34),
      _Part(ShapeKind.triangle, 0.78, 0.4, 0.24),
      _Part(ShapeKind.square, 0.78, 0.6, 0.16),
    ]),
    // 骨頭：兩端(圓) + 中桿(橢圓)——圓 vs 橢圓的形狀辨認
    _Figure(<_Part>[
      _Part(ShapeKind.circle, 0.15, 0.5, 0.26),
      _Part(ShapeKind.oval, 0.5, 0.5, 0.44),
      _Part(ShapeKind.circle, 0.85, 0.5, 0.26),
    ]),
    // 烏龜：頭(小圓) + 殼(大圓，兩圓正好相切) + 雙腳(方)
    _Figure(<_Part>[
      _Part(ShapeKind.circle, 0.2, 0.45, 0.2),
      _Part(ShapeKind.circle, 0.5, 0.45, 0.4),
      _Part(ShapeKind.square, 0.38, 0.73, 0.16),
      _Part(ShapeKind.square, 0.62, 0.73, 0.16),
    ]),
  ];

  final Random _rng = Random();
  late _Figure _fig;
  late List<bool> _placed;
  // 托盤只放「本圖用到的每種形狀各一顆」，可無限重複拖 → 孩子不能靠數剩幾顆偷吃步，
  // 必須看盤面的洞是什麼形狀才拼得對。
  late List<ShapeKind> _palette;
  int _i = 0;
  int _prevFig = -1;
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
    int f = _rng.nextInt(_figures.length);
    if (f == _prevFig) f = (f + 1) % _figures.length; // 不連續出同一個
    _prevFig = f;
    _fig = _figures[f];
    _placed = List<bool>.filled(_fig.parts.length, false);
    // 本圖用到的形狀去重、每種一顆（順序打散，避免位置被記住）。
    _palette =
        (ShapeKind.values
              .where((ShapeKind k) => _fig.parts.any((_Part p) => p.shape == k))
              .toList())
          ..shuffle(_rng);
    _lock = false;
    _success = false;
  }

  Future<void> _accept(int slot) async {
    AudioService.instance.tap();
    setState(() => _placed[slot] = true);
    if (!_placed.every((bool b) => b)) return;
    _lock = true;
    setState(() => _success = true);
    AudioService.instance.correct();
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    if (_i < widget.rounds - 1) {
      // 引導語只在第一題念過即可（initState），之後換圖案不重念、不囉嗦。
      setState(() {
        _i++;
        _gen();
      });
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    // 放錯只會彈回、無「答錯」→ 不傳 mistakes，維持正向 3 ⭐。
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
    final double box =
        (wide
                ? min(sz.width * 0.40, sz.height * 0.62)
                : min(sz.width * 0.72, sz.height * 0.46))
            .clamp(170.0, 380.0);
    final double refBox = (box * (wide ? 0.62 : 0.5)).clamp(110.0, 230.0);
    final double tray = (box * 0.24).clamp(52.0, 110.0);

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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7C4DFF), width: 3),
          ),
          child: _canvas(refBox, play: false),
        ),
      ],
    );

    final Widget board = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C4DFF), width: 2),
      ),
      child: _canvas(box, play: true),
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
              SizedBox(
                height: tray + context.s(24),
                // 每種形狀一顆、可無限重複拖；用 FittedBox 等比縮，保證整排都看得到、不溢出。
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (int k = 0; k < _palette.length; k++)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.s(10),
                            ),
                            child: _draggable(_palette[k], tray),
                          ),
                      ],
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

  /// 圖案畫布：把各塊依單位座標擺到 [box]×[box] 的方框內。
  Widget _canvas(double box, {required bool play}) {
    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < _fig.parts.length; i++)
            _positioned(i, box, play),
        ],
      ),
    );
  }

  Widget _positioned(int i, double box, bool play) {
    final _Part p = _fig.parts[i];
    final double side = p.side * box;
    return Positioned(
      left: (p.cx - p.side / 2) * box,
      top: (p.cy - p.side / 2) * box,
      width: side,
      height: side,
      child: _slot(i, side, play),
    );
  }

  Widget _slot(int i, double side, bool play) {
    final _Part p = _fig.parts[i];
    // 完成圖：整塊實心；遊戲盤：放好才實心，否則畫外框當「洞」。
    final bool filled = play ? _placed[i] : true;
    if (filled) {
      return ShapeView(kind: p.shape, color: _piece, size: side);
    }
    if (!play) {
      return ShapeView(kind: p.shape, color: _piece, size: side);
    }
    return DragTarget<ShapeKind>(
      // 同形狀互換：只要形狀對、這個洞還空著就吃。
      onWillAcceptWithDetails: (DragTargetDetails<ShapeKind> d) =>
          !_lock && !_placed[i] && d.data == p.shape,
      onAcceptWithDetails: (DragTargetDetails<ShapeKind> d) => _accept(i),
      builder: (BuildContext ctx, List<ShapeKind?> cand, List<dynamic> rej) {
        return ShapeView(
          kind: p.shape,
          // 命中時外框加亮，給正向提示。
          color: cand.isNotEmpty ? _piece : _piece.withValues(alpha: 0.7),
          size: side,
          filled: false,
        );
      },
    );
  }

  Widget _draggable(ShapeKind kind, double size) {
    final Widget piece = ShapeView(kind: kind, color: _piece, size: size);
    return Draggable<ShapeKind>(
      data: kind,
      feedback: Material(
        type: MaterialType.transparency,
        child: Transform.scale(scale: 1.12, child: piece),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: piece),
      // 放錯形狀的洞會自己彈回、不計錯（只吃得進同形狀的空洞）。
      child: piece,
    );
  }
}
