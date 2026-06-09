import 'dart:math';

import 'package:flutter/material.dart';

import '../responsive.dart';
import 'penguin.dart';

/// 答對時的慶祝：星星往外爆開 + 企企彈跳。
/// 放在 Stack 最上層；播一次（約 0.7 秒）。用 IgnorePointer 不擋觸控。
class Celebration extends StatelessWidget {
  const Celebration({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: context.s(260),
          height: context.s(260),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            builder: (BuildContext context, double t, Widget? child) {
              return Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  for (int i = 0; i < 8; i++) _star(context, i, t),
                  Transform.scale(
                    scale: Curves.elasticOut.transform(t.clamp(0.0, 1.0)),
                    child: Opacity(
                      opacity: 1 - ((t - 0.7).clamp(0.0, 0.3) / 0.3),
                      child: Penguin(size: context.s(96), animate: false),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _star(BuildContext context, int i, double t) {
    final double angle = i * pi / 4;
    final double dist = context.s(110) * Curves.easeOut.transform(t);
    return Transform.translate(
      offset: Offset(cos(angle) * dist, sin(angle) * dist),
      child: Opacity(
        opacity: (1 - t).clamp(0.0, 1.0),
        child: Icon(Icons.star_rounded,
            color: const Color(0xFFFFC107), size: context.s(28 + 12 * t)),
      ),
    );
  }
}
