import 'package:flutter/material.dart';

import '../responsive.dart';
import '../theme.dart';

/// 大型可點卡片：上方大 emoji，下方標題。按下有縮放回饋。
class BigCard extends StatefulWidget {
  const BigCard({
    super.key,
    required this.emoji,
    required this.onTap,
    this.label,
    this.color = const Color(0xFF90CAF9),
    this.size = 160,
    this.badge,
    this.dimmed = false,
    this.solid = false,
  });

  final String emoji;
  final String? label;
  final Color color;
  final double size;
  final VoidCallback onTap;

  /// 右上角小徽章（例如星星數）。
  final Widget? badge;

  /// 是否變灰（未開放）。
  final bool dimmed;

  /// 白底卡片（深色沉浸式背景上仍清楚）。
  final bool solid;

  @override
  State<BigCard> createState() => _BigCardState();
}

class _BigCardState extends State<BigCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: widget.dimmed ? 0.45 : 1.0,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.solid
                  ? Colors.white.withValues(alpha: 0.94)
                  : widget.color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(Sizes.radius),
              border: Border.all(color: widget.color, width: 4),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                // FittedBox(scaleDown)：內容（大 emoji + 標題）一律縮到卡片內，
                // 不論卡片多小或標題多長都不會溢出。字級隨卡片大小（size 比例）縮放。
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(widget.size * 0.08),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            widget.emoji,
                            style: TextStyle(fontSize: widget.size * 0.42),
                          ),
                          if (widget.label != null) ...<Widget>[
                            SizedBox(height: widget.size * 0.05),
                            Text(
                              widget.label!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: widget.size * 0.13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.badge != null)
                  Positioned(
                    top: context.s(8),
                    right: context.s(10),
                    child: widget.badge!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 星星列：顯示 0~max 的星數（已得實心、未得空心）。
class StarsRow extends StatelessWidget {
  const StarsRow({
    super.key,
    required this.count,
    this.max = 3,
    this.size = 22,
  });

  final int count;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(max, (int i) {
        final bool filled = i < count;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          color: filled ? const Color(0xFFFFC107) : Colors.grey,
          size: context.s(size), // size 視為設計基準 px，內部依裝置縮放
        );
      }),
    );
  }
}
