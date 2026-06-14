import 'package:flutter/material.dart';

import '../content/toys.dart';
import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/game_scaffold.dart';
import '../core/widgets/reward_background.dart';

/// 玩具收藏室（圖鑑）：扭蛋抽到的玩具收集在這。未取得顯示問號剪影。
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ProgressStore store = ProgressStore.instance;
    final int owned = store.distinctToyCount;
    return GameScaffold(
      title: '收藏室',
      backgroundWidget: const RewardBackground(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(context.s(12)),
                child: Text(
                  '已收集 $owned / ${toyPool.length}',
                  style: TextStyle(
                    fontSize: context.s(20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                // 依可用寬度自動決定每排格數（每格上限 ~150），窄手機少排、寬平板多排。
                child: GridView.extent(
                  maxCrossAxisExtent: context.s(150),
                  padding: EdgeInsets.all(context.s(Sizes.gap)),
                  mainAxisSpacing: context.s(12),
                  crossAxisSpacing: context.s(12),
                  children: toyPool.map((Toy t) {
                    final int count = store.toyCount(t.id);
                    final bool has = count > 0;
                    return Container(
                      decoration: BoxDecoration(
                        color: has
                            ? t.rarity.color.withValues(alpha: 0.12)
                            : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: has ? t.rarity.color : Colors.grey.shade300,
                          width: has ? 3 : 1,
                        ),
                      ),
                      child: Stack(
                        children: <Widget>[
                          Center(
                            child: has
                                ? Text(
                                    t.id,
                                    style: TextStyle(fontSize: context.s(44)),
                                  )
                                : Text(
                                    '❓',
                                    style: TextStyle(
                                      fontSize: context.s(40),
                                      color: const Color(0xFFBDBDBD),
                                    ),
                                  ),
                          ),
                          if (count > 1)
                            Positioned(
                              right: context.s(4),
                              bottom: context.s(4),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.s(6),
                                  vertical: context.s(1),
                                ),
                                decoration: BoxDecoration(
                                  color: t.rarity.color,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '×$count',
                                  style: TextStyle(
                                    fontSize: context.s(12),
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              // 稀有度圖例
              Padding(
                padding: EdgeInsets.all(context.s(10)),
                child: Wrap(
                  spacing: context.s(16),
                  alignment: WrapAlignment.center,
                  children: ToyRarity.values.map((ToyRarity r) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: context.s(14),
                          height: context.s(14),
                          decoration: BoxDecoration(
                            color: r.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: context.s(4)),
                        Text(
                          r.label,
                          style: TextStyle(
                            fontSize: context.s(14),
                            color: const Color(0xFF666666),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
