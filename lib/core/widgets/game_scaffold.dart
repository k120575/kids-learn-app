import 'package:flutter/material.dart';

import '../audio_service.dart';
import '../responsive.dart';
import 'cloud_title.dart';
import 'penguin.dart';

/// 所有遊戲共用的外框：頂部有返回鍵、企企、標題、重播指示鍵、暫停鍵、進度點。
class GameScaffold extends StatefulWidget {
  const GameScaffold({
    super.key,
    required this.title,
    required this.child,
    this.onReplay,
    this.current = 0,
    this.total = 0,
    this.background,
    this.backgroundWidget,
    this.foregroundColor = const Color(0xFF40454F),
  });

  final String title;
  final Widget child;

  /// 重播語音指示。
  final VoidCallback? onReplay;

  final int current;
  final int total;
  final Color? background;

  /// 沉浸式背景圖層（例如動畫遊樂園 / 宇宙），鋪滿整個畫面、置於內容之後。
  final Widget? backgroundWidget;

  /// 標題文字顏色（深色背景時改白色）。
  final Color foregroundColor;

  @override
  State<GameScaffold> createState() => _GameScaffoldState();
}

class _GameScaffoldState extends State<GameScaffold> {
  bool _paused = false;

  @override
  void dispose() {
    // 離開遊戲（含提示語還沒念完就按返回）時，停掉正在念的語音/音效。
    AudioService.instance.stop();
    super.dispose();
  }

  void _pause() {
    AudioService.instance.stop(); // 暫停時停掉正在念的語音/音效
    setState(() => _paused = true);
  }

  void _resume() {
    setState(() => _paused = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.background,
      body: Stack(
        children: <Widget>[
          if (widget.backgroundWidget != null)
            Positioned.fill(child: widget.backgroundWidget!),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: <Widget>[
                      _RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 8),
                      Penguin(size: context.s(48)), // 企企陪玩
                      const SizedBox(width: 8),
                      // 品牌標題（與首頁同字型、同塗鴉風，描邊讓深淺背景都清楚）。
                      // 用 Flexible + FittedBox：長標題自動縮到放得下，不溢出也不被截斷。
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: BrandTitle(
                            text: widget.title,
                            fontSize: context.s(24),
                          ),
                        ),
                      ),
                      if (widget.total > 0)
                        _ProgressDots(
                            current: widget.current, total: widget.total),
                      if (widget.onReplay != null) ...<Widget>[
                        const SizedBox(width: 12),
                        _RoundIconButton(
                          icon: Icons.volume_up_rounded,
                          onTap: widget.onReplay!,
                        ),
                      ],
                      const SizedBox(width: 8),
                      _RoundIconButton(
                        icon: Icons.pause_rounded,
                        onTap: _pause,
                      ),
                    ],
                  ),
                ),
                // 暫停時擋住遊戲區互動（遮罩在最上層，這裡再加一層保險）。
                Expanded(
                  child: IgnorePointer(ignoring: _paused, child: widget.child),
                ),
              ],
            ),
          ),
          if (_paused) _PauseOverlay(onResume: _resume),
        ],
      ),
    );
  }
}

/// 暫停遮罩：柔和半透明底 + 企企 + 「繼續玩」「回首頁」。
class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {}, // 吃掉點擊，避免穿透到底下
        child: Container(
          color: const Color(0xCC1A237E), // 深藍半透明，與宇宙/遊樂園色調一致
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Penguin(size: context.s(88)),
                  const SizedBox(height: 12),
                  Text('休息一下',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: context.s(26), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: onResume,
                    icon: Icon(Icons.play_arrow_rounded, size: context.s(28)),
                    label: Text('繼續玩',
                        style: TextStyle(
                            fontSize: context.s(20), fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 32),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      onResume();
                      Navigator.of(context).maybePop();
                    },
                    child: Text('回首頁',
                        style: TextStyle(
                            fontSize: context.s(16), color: const Color(0xFF888888))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: context.s(28), color: const Color(0xFF5C6BC0)),
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    // 關卡多（>6）時用文字膠囊，避免一排點點在窄螢幕擠爆頂列。
    if (total > 6) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '$current / $total',
          style: TextStyle(
              fontSize: context.s(16),
              fontWeight: FontWeight.bold,
              color: const Color(0xFFB8860B)),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(total, (int i) {
        final bool done = i < current;
        return Container(
          width: context.s(16),
          height: context.s(16),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: done ? const Color(0xFFFFC107) : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
