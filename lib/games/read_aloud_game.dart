import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/game_complete.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/game_scaffold.dart';

/// 跟我念（親子共學）：播放一句短語，孩子和家長一起跟著念，念完按「我念好了」。
/// 不判對錯——目的是「開口表達 + 親子互動」，完成整組即拿星星與貼紙。
class ReadAloudGame extends StatefulWidget {
  const ReadAloudGame({
    super.key,
    required this.gameId,
    required this.title,
    required this.items,
    this.pickCount,
  });

  final String gameId;
  final String title;

  /// (短語, emoji) 清單。
  final List<(String, String)> items;

  /// 每局抽幾句（null = 全部）。
  final int? pickCount;

  @override
  State<ReadAloudGame> createState() => _ReadAloudGameState();
}

class _ReadAloudGameState extends State<ReadAloudGame> {
  static const String _intro = '和爸爸媽媽一起，跟著念念看！';

  late List<(String, String)> _items;
  int _i = 0;

  (String, String) get _item => _items[_i];

  void _prepare() {
    _items = List<(String, String)>.of(widget.items)..shuffle();
    final int? n = widget.pickCount;
    if (n != null && n < _items.length) {
      _items = _items.sublist(0, n);
    }
  }

  @override
  void initState() {
    super.initState();
    _prepare();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _speak() => AudioService.instance.speak(_item.$1);

  Future<void> _next() async {
    if (_i < _items.length - 1) {
      setState(() => _i++);
      _speak();
    } else {
      final bool again = await finishGame(context, widget.gameId);
      if (!mounted) return;
      if (again) {
        setState(() {
          _prepare();
          _i = 0;
        });
        _speak();
      } else {
        Navigator.of(context).maybePop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (String, String) item = _item;
    return GameScaffold(
      title: widget.title,
      current: _i,
      total: _items.length,
      onReplay: _speak,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Sizes.bigGap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('👨‍👩‍👧 親子一起念',
                  style: TextStyle(fontSize: context.s(16), color: const Color(0xFF888888))),
              const SizedBox(height: Sizes.gap),
              Text(item.$2, style: TextStyle(fontSize: context.s(96))),
              const SizedBox(height: Sizes.gap),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(Sizes.radius),
                  border: Border.all(color: const Color(0xFFFFC107), width: 4),
                ),
                child: Text(
                  item.$1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: context.s(40), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: Sizes.bigGap),
              Wrap(
                spacing: Sizes.gap,
                runSpacing: Sizes.gap,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _speak,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(context.s(150), context.s(60)),
                      textStyle: TextStyle(fontSize: context.s(20)),
                    ),
                    icon: Icon(Icons.volume_up_rounded, size: context.s(26)),
                    label: const Text('再聽一次'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(context.s(150), context.s(60)),
                      textStyle: TextStyle(fontSize: context.s(20)),
                    ),
                    icon: Icon(Icons.check_rounded, size: context.s(26)),
                    label: const Text('我念好了'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_intro,
                  style: TextStyle(fontSize: context.s(15), color: const Color(0xFFAAAAAA))),
            ],
          ),
        ),
      ),
    );
  }
}
