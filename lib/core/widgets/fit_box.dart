import 'package:flutter/material.dart';

import '../responsive.dart';
import '../theme.dart';

/// 把一整塊「內在尺寸」的遊戲內容**等比縮到放得下可用空間、永不放大**，
/// 讓矮螢幕（手機橫向，例如 Pixel 9 Pro XL 橫放高度只有 ~390dp）也能
/// **免捲動就看完**——孩子不會也不該去捲動找按鈕。
///
/// 平板／一般高度的螢幕內容本來就放得下，FittedBox(scaleDown) 不會放大，
/// 維持原樣、不受影響。
///
/// 取代各遊戲過去的 `Center > SingleChildScrollView`（會把超高內容藏到畫面外，
/// 看起來就像「破版」）。內容須為有限尺寸（用 `context.s` 的固定尺寸即可）。
class FitBox extends StatelessWidget {
  const FitBox({super.key, required this.child, this.padded = true});

  final Widget child;

  /// 是否在四周留一圈安全邊（預設留 [Sizes.gap]）。
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padded ? EdgeInsets.all(context.s(Sizes.gap)) : EdgeInsets.zero,
      child: Center(
        child: FittedBox(fit: BoxFit.scaleDown, child: child),
      ),
    );
  }
}

/// 把等大的選項卡排成「上下盡量平均的兩列」：≤4 個排一列；5 個 → 上 3 下 2；
/// 6 個 → 上 3 下 3。避免 [Wrap] 在窄螢幕擠成「上 4 下 1」這種不平均的醜排法。
/// 搭配 [FitBox] 使用：整塊會再等比縮到放得下，免捲動。
Widget balancedTileRows(
  BuildContext context,
  List<Widget> tiles, {
  double? spacing,
}) {
  final double sp = spacing ?? context.s(Sizes.bigGap);
  List<Widget> withGaps(List<Widget> ws) {
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < ws.length; i++) {
      if (i > 0) out.add(SizedBox(width: sp));
      out.add(ws[i]);
    }
    return out;
  }

  Row row(List<Widget> ws) =>
      Row(mainAxisSize: MainAxisSize.min, children: withGaps(ws));

  if (tiles.length <= 4) return row(tiles);
  final int top = (tiles.length / 2).ceil();
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      row(tiles.sublist(0, top)),
      SizedBox(height: sp),
      row(tiles.sublist(top)),
    ],
  );
}
