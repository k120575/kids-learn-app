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

/// 對稱鏡像（5-6）：左半邊有一個魔法圖案，沿著中間的鏡子把右半邊「對稱地」補出來。
/// 點右側格子可填上／取消。右半邊和左半邊的鏡像完全一致就過關。
/// 適性難度：簡單 4×2、一般 5×3、挑戰 6×3，填色格數隨難度增加。
class SymmetryGame extends StatefulWidget {
  const SymmetryGame({
    super.key,
    required this.gameId,
    required this.title,
    this.rounds = 5,
  });

  final String gameId;
  final String title;
  final int rounds;

  @override
  State<SymmetryGame> createState() => _SymmetryGameState();
}

class _SymmetryGameState extends State<SymmetryGame> {
  final Random _rng = Random();
  int _i = 0;
  bool _lock = false;
  bool _success = false;
  int _mistakes = 0;

  late int _rows;
  late int _half; // 每半邊的欄數
  late List<List<bool>> _left; // 左半 [r][c]，c=0 為最左
  late List<List<bool>> _right; // 右半玩家填的狀態 [r][j]，j=0 緊鄰鏡子
  int _roundMistakes = 0; // 本盤錯誤次數（用於提示）

  @override
  void initState() {
    super.initState();
    final int level = ProgressStore.instance.levelFor(widget.gameId);
    _rows = level == 0 ? 4 : (level == 1 ? 5 : 6);
    _half = level == 0 ? 2 : 3;
    _gen();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice('看著鏡子，把另一半補成一樣！'),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  /// 右半某格 (r,j) 的「正解」= 左半鏡像格 (r, _half-1-j)。
  bool _target(int r, int j) => _left[r][_half - 1 - j];

  void _gen() {
    _left = List<List<bool>>.generate(
        _rows, (_) => List<bool>.filled(_half, false));
    _right = List<List<bool>>.generate(
        _rows, (_) => List<bool>.filled(_half, false));
    final int cells = _rows * _half;
    // 填色格數：約 40%~60%，至少 3 格、至多比總格數少 1。
    int want = (cells * (0.4 + _rng.nextDouble() * 0.2)).round();
    want = want.clamp(3, cells - 1);
    int placed = 0;
    int guard = 0;
    while (placed < want && guard < 500) {
      guard++;
      final int r = _rng.nextInt(_rows);
      final int c = _rng.nextInt(_half);
      if (!_left[r][c]) {
        _left[r][c] = true;
        placed++;
      }
    }
    _roundMistakes = 0;
    _lock = false;
    _success = false;
  }

  bool get _solved {
    for (int r = 0; r < _rows; r++) {
      for (int j = 0; j < _half; j++) {
        if (_right[r][j] != _target(r, j)) return false;
      }
    }
    return true;
  }

  Future<void> _tapRight(int r, int j) async {
    if (_lock) return;
    final bool now = !_right[r][j];
    setState(() => _right[r][j] = now);
    AudioService.instance.tap(); // 每次填／取消都只給輕點聲，不論對錯
    // 取消（清空格子）不需判定，讓孩子自由調整。
    if (!now) return;
    // 還沒填滿「應有的格數」前不提示對錯——等孩子覺得完成了再一次判定。
    int filled = 0;
    int target = 0;
    for (int rr = 0; rr < _rows; rr++) {
      for (int jj = 0; jj < _half; jj++) {
        if (_right[rr][jj]) filled++;
        if (_target(rr, jj)) target++;
      }
    }
    if (filled < target) return;
    // 已填到該有的格數 → 這時才看整體鏡像對不對。
    if (_solved) {
      _lock = true;
      setState(() => _success = true);
      AudioService.instance.correct();
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (!mounted) return;
      if (_i < widget.rounds - 1) {
        setState(() {
          _i++;
          _gen();
        });
        AudioService.instance.speak('看著鏡子，把另一半補成一樣！');
      } else {
        await _finish();
      }
    } else {
      // 全部填完但有錯 → 這時才說「再試一次」，並計一次錯（供提示與評分）。
      AudioService.instance.wrong();
      _mistakes++;
      _roundMistakes++;
      setState(() {}); // 觸發提示重算
    }
  }

  Future<void> _finish() async {
    final bool again =
        await finishGame(context, widget.gameId, mistakes: _mistakes);
    if (!mounted) return;
    if (again) {
      setState(() {
        _i = 0;
        _mistakes = 0;
        _gen();
      });
      AudioService.instance.speak('看著鏡子，把另一半補成一樣！');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 卡關（本盤錯 ≥3）時，提示一個「還沒填的正解格」。
    (int, int)? hintCell;
    if (_roundMistakes >= 3) {
      outer:
      for (int r = 0; r < _rows; r++) {
        for (int j = 0; j < _half; j++) {
          if (_target(r, j) && !_right[r][j]) {
            hintCell = (r, j);
            break outer;
          }
        }
      }
    }

    return GameScaffold(
      title: widget.title,
      current: _i,
      total: widget.rounds,
      onReplay: () =>
          AudioService.instance.speak('看著鏡子，把另一半補成一樣！'),
      child: Stack(
        children: <Widget>[
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Sizes.gap),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('把右邊補成左邊的鏡像',
                      style: TextStyle(
                          fontSize: context.s(20),
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: Sizes.gap),
                  // 窄螢幕時整個鏡像盤面等比縮小，不會被裁切。
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List<Widget>.generate(_rows, (int r) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          // 左半（題目，固定）
                          for (int c = 0; c < _half; c++)
                            _Cell(
                              filled: _left[r][c],
                              given: true,
                            ),
                          // 鏡子
                          Container(
                            width: context.s(6),
                            height: context.s(52),
                            margin:
                                const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Color(0xFFB388FF),
                                  Color(0xFF7C4DFF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          // 右半（玩家填）
                          for (int j = 0; j < _half; j++)
                            _Cell(
                              filled: _right[r][j],
                              given: false,
                              hint: hintCell != null &&
                                  hintCell.$1 == r &&
                                  hintCell.$2 == j,
                              onTap: () => _tapRight(r, j),
                            ),
                        ],
                      );
                    }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_success) const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.filled,
    required this.given,
    this.hint = false,
    this.onTap,
  });

  final bool filled;
  final bool given; // true=左側題目格（不可點），false=右側可點
  final bool hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color fill = given
        ? const Color(0xFF7C4DFF) // 題目：紫
        : const Color(0xFF4CAF50); // 玩家：綠
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: context.s(52),
        height: context.s(52),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: filled ? fill : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hint
                ? const Color(0xFFFFC107)
                : (filled ? fill : Colors.grey.shade400),
            width: hint ? 4 : 2,
          ),
        ),
        child: filled
            ? Center(
                child: Text('✦',
                    style: TextStyle(
                        fontSize: context.s(26), color: Colors.white)))
            : null,
      ),
    );
  }
}
