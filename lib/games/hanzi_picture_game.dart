import 'dart:math';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/game_complete.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/celebration.dart';
import '../core/widgets/game_scaffold.dart';
import '../core/widgets/shaker.dart';

/// 認國字（看圖選字，4-5）：上方一張圖，下方 3 個字。點字會念出讀音幫忙比對，
/// 可以一直點、重複聽，選好再按「確定」才判對錯。
///
/// 設計理據：4-5 還不太會認字，用「圖↔字」對應＋「點字聽音」降低門檻——
/// 孩子先認得圖（月亮），再聽哪個字念起來像，建立「字形↔字音↔意義」連結。
/// 與 5-6 的認國字（聽詞點字、無圖、不先給音）刻意區隔開來。
class HanziPictureGame extends StatefulWidget {
  const HanziPictureGame({
    super.key,
    required this.gameId,
    required this.title,
    required this.items,
    this.pickCount = 8,
  });

  final String gameId;
  final String title;

  /// (字, 對應圖 emoji) 清單。
  final List<(String, String)> items;

  /// 每局抽幾題。
  final int pickCount;

  @override
  State<HanziPictureGame> createState() => _HanziPictureGameState();
}

class _HanziPictureGameState extends State<HanziPictureGame> {
  static const String _intro = '這是什麼？點下面的字聽聽看，選好再按確定！';

  final Random _rng = Random();
  late List<(String, String)> _items; // 本局題序
  int _i = 0;
  late List<String> _options; // 本題 3 個字選項
  late int _correct; // 正解在 _options 的索引
  int? _selected; // 目前點選（還沒按確定）
  final Set<int> _ruledOut = <int>{}; // 按確定後確認答錯的選項
  int _shake = 0;
  bool _success = false;
  bool _lock = false;
  int _mistakes = 0;

  (String, String) get _item => _items[_i];

  @override
  void initState() {
    super.initState();
    _prepare();
    _genOptions();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AudioService.instance.speakAfterVoice(_intro),
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _prepare() {
    _items = List<(String, String)>.of(widget.items)..shuffle(_rng);
    if (widget.pickCount < _items.length) {
      _items = _items.sublist(0, widget.pickCount);
    }
  }

  void _genOptions() {
    final String correctChar = _item.$1;
    final Set<String> distract = <String>{};
    while (distract.length < 2) {
      final String e = widget.items[_rng.nextInt(widget.items.length)].$1;
      if (e != correctChar) distract.add(e);
    }
    _options = <String>[correctChar, ...distract]..shuffle(_rng);
    _correct = _options.indexOf(correctChar);
    _selected = null;
    _ruledOut.clear();
    _success = false;
    _lock = false;
  }

  void _tapOption(int idx) {
    if (_lock) return;
    if (_ruledOut.contains(idx)) return;
    setState(() => _selected = idx);
    AudioService.instance.speak(_options[idx]); // 念這個字的讀音
  }

  Future<void> _confirm() async {
    if (_lock || _selected == null) return;
    if (_selected == _correct) {
      setState(() {
        _success = true;
        _lock = true;
      });
      AudioService.instance.correct();
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (!mounted) return;
      if (_i < _items.length - 1) {
        setState(() {
          _i++;
          _genOptions();
        });
      } else {
        final bool again = await finishGame(
          context,
          widget.gameId,
          mistakes: _mistakes,
        );
        if (!mounted) return;
        if (again) {
          setState(() {
            _prepare();
            _i = 0;
            _mistakes = 0;
            _genOptions();
          });
        } else {
          Navigator.of(context).maybePop();
        }
      }
    } else {
      // 答錯：把這個選項劃掉、抖一下，讓孩子再聽再選（不換題）。
      _mistakes++;
      AudioService.instance.wrong();
      setState(() {
        _ruledOut.add(_selected!);
        _selected = null;
        _shake++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: widget.title,
      current: _i,
      total: _items.length,
      onReplay: () => AudioService.instance.speak(_intro),
      child: Stack(
        children: <Widget>[
          // 整個內容用 FittedBox 依「實際可用空間」等比縮放：放得下就原尺寸，
          // 矮螢幕放不下就整體縮小——圖、選項、確定鈕一律不會被切掉（真 RWD）。
          Padding(
            padding: EdgeInsets.all(context.s(Sizes.gap)),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // 題目圖：大大的一張圖，問「這是什麼字？」
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.s(28),
                        vertical: context.s(16),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(Sizes.radius),
                        border: Border.all(
                          color: const Color(0xFFFFC107),
                          width: 4,
                        ),
                      ),
                      child: Text(
                        _item.$2,
                        style: TextStyle(fontSize: context.s(96)),
                      ),
                    ),
                    SizedBox(height: context.s(Sizes.gap)),
                    Text(
                      '哪一個字是它呢？',
                      style: TextStyle(
                        fontSize: context.s(20),
                        color: const Color(0xFF888888),
                      ),
                    ),
                    SizedBox(height: context.s(Sizes.gap)),
                    // FittedBox 內寬度無限，Wrap 自然排成一列；保留 Wrap 讓
                    // 版面與既有測試一致。
                    Wrap(
                      spacing: context.s(Sizes.gap),
                      runSpacing: context.s(Sizes.gap),
                      alignment: WrapAlignment.center,
                      children: List<Widget>.generate(_options.length, (
                        int idx,
                      ) {
                        return Shaker(
                          trigger: _ruledOut.contains(idx) ? _shake : 0,
                          child: _CharTile(
                            char: _options[idx],
                            selected: _selected == idx,
                            ruledOut: _ruledOut.contains(idx),
                            correct: _success && idx == _correct,
                            onTap: () => _tapOption(idx),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: context.s(Sizes.bigGap)),
                    ElevatedButton.icon(
                      onPressed: (_selected == null || _lock) ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(context.s(180), context.s(64)),
                        textStyle: TextStyle(
                          fontSize: context.s(24),
                          fontWeight: FontWeight.bold,
                        ),
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFCFD8DC),
                      ),
                      icon: Icon(
                        Icons.check_circle_rounded,
                        size: context.s(28),
                      ),
                      label: const Text('確定'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_success) const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }
}

class _CharTile extends StatelessWidget {
  const _CharTile({
    required this.char,
    required this.selected,
    required this.ruledOut,
    required this.correct,
    required this.onTap,
  });

  final String char;
  final bool selected; // 已點選、尚未確定（琥珀框）
  final bool ruledOut; // 確定後判錯（灰掉劃除）
  final bool correct; // 答對（綠）
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = correct
        ? const Color(0xFFC8E6C9)
        : (ruledOut
              ? const Color(0xFFEEEEEE)
              : (selected ? const Color(0xFFFFF8E1) : Colors.white));
    final Color border = correct
        ? const Color(0xFF4CAF50)
        : (ruledOut
              ? Colors.grey.shade400
              : (selected ? const Color(0xFFFFC107) : Colors.grey.shade300));
    return GestureDetector(
      onTap: ruledOut ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: context.s(120),
        height: context.s(120),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Sizes.radius),
          border: Border.all(
            color: border,
            width: (selected || correct) ? 6 : 3,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            char,
            style: TextStyle(
              fontSize: context.s(64),
              fontWeight: FontWeight.bold,
              color: ruledOut
                  ? Colors.grey.shade500
                  : const Color(0xFF37474F),
            ),
          ),
        ),
      ),
    );
  }
}
