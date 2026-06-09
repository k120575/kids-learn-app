import 'dart:math';

import 'package:flutter/material.dart';

/// 當 [trigger] 改變時，讓 child 左右搖晃一下（用於答錯的溫和提示）。
class Shaker extends StatefulWidget {
  const Shaker({super.key, required this.child, required this.trigger});

  final Widget child;
  final int trigger;

  @override
  State<Shaker> createState() => _ShakerState();
}

class _ShakerState extends State<Shaker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(covariant Shaker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double dx = sin(_c.value * pi * 4) * 12 * (1 - _c.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
