import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 企企的姿勢；對應 `assets/images/mascot/{name}.webp`（tool/gen_mascot.py 產出）。
enum PenguinPose { wave, cheer, think, encourage, sleep }

/// 吉祥物「企企」：淺藍小企鵝（扁平繪本插畫），會輕輕上下搖擺。
///
/// [reactive] 為 true 時會跟著 [Penguin.react] 暫時換姿勢（答對歡呼、答錯加油），
/// 約 1.6 秒後回到 [pose]。
class Penguin extends StatefulWidget {
  const Penguin({
    super.key,
    this.size = 140,
    this.animate = true,
    this.pose = PenguinPose.wave,
    this.reactive = false,
  });

  final double size;
  final bool animate;
  final PenguinPose pose;
  final bool reactive;

  /// 最近一次反應（姿勢 + 序號；序號讓連續同姿勢也會重新計時）。
  static final ValueNotifier<(PenguinPose, int)?> reaction =
      ValueNotifier<(PenguinPose, int)?>(null);
  static int _seq = 0;

  /// 讓畫面上 reactive 的企企暫時換成 [pose]。
  static void react(PenguinPose pose) => reaction.value = (pose, ++_seq);

  static String assetFor(PenguinPose pose) =>
      'assets/images/mascot/${pose.name}.webp';

  @override
  State<Penguin> createState() => _PenguinState();
}

class _PenguinState extends State<Penguin> with SingleTickerProviderStateMixin {
  // 只在需要動畫時才建立控制器；用可空避免 dispose 時才懶初始化而崩潰。
  AnimationController? _c;
  PenguinPose? _reacting;
  Timer? _reset;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3200),
      )..repeat();
    }
    if (widget.reactive) Penguin.reaction.addListener(_onReact);
  }

  void _onReact() {
    final (PenguinPose, int)? r = Penguin.reaction.value;
    if (r == null || !mounted) return;
    _reset?.cancel();
    setState(() => _reacting = r.$1);
    _reset = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _reacting = null);
    });
  }

  @override
  void dispose() {
    if (widget.reactive) Penguin.reaction.removeListener(_onReact);
    _reset?.cancel();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.asset(
      Penguin.assetFor(_reacting ?? widget.pose),
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      gaplessPlayback: true, // 換姿勢時不閃白
    );
    final AnimationController? c = _c;
    if (c == null) return image;
    return AnimatedBuilder(
      animation: c,
      child: image,
      builder: (BuildContext context, Widget? child) {
        final double bob = sin(c.value * 2 * pi) * widget.size * 0.022;
        return Transform.translate(offset: Offset(0, bob), child: child);
      },
    );
  }
}
