import 'package:flutter/material.dart';

import '../content/achievements.dart';
import '../core/responsive.dart';
import '../core/rewards.dart';
import '../core/theme.dart';
import '../core/widgets/game_scaffold.dart';
import '../core/widgets/reward_background.dart';

/// 獎盃櫃：展示所有成就與目前等級（銅／銀／金）及到下一級的進度。
class TrophyScreen extends StatelessWidget {
  const TrophyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: '獎盃櫃',
      backgroundWidget: const RewardBackground(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: EdgeInsets.all(context.s(Sizes.bigGap)),
            children: achievements.map((Achievement a) {
              final int value = achievementMetric(a.metric);
              final int tier = a.tierFor(value);
              final bool maxed = tier >= a.tiers.length;
              final int nextThreshold = maxed ? a.tiers.last : a.tiers[tier];
              final double progress = maxed
                  ? 1.0
                  : (value / nextThreshold).clamp(0.0, 1.0);
              final Color tierColor = Color(kTierColors[tier]);

              return Card(
                child: Padding(
                  padding: EdgeInsets.all(context.s(14)),
                  child: Row(
                    children: <Widget>[
                      // 獎盃圖示（未解鎖灰階感）
                      Opacity(
                        opacity: tier == 0 ? 0.4 : 1,
                        child: Container(
                          width: context.s(56),
                          height: context.s(56),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: tierColor, width: 2),
                          ),
                          child: Text(
                            a.emoji,
                            style: TextStyle(fontSize: context.s(28)),
                          ),
                        ),
                      ),
                      SizedBox(width: context.s(14)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Text(
                                  a.name,
                                  style: TextStyle(
                                    fontSize: context.s(18),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: context.s(8)),
                                if (tier > 0)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: context.s(8),
                                      vertical: context.s(2),
                                    ),
                                    decoration: BoxDecoration(
                                      color: tierColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${kTierNames[tier]}牌',
                                      style: TextStyle(
                                        fontSize: context.s(12),
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    '未解鎖',
                                    style: TextStyle(
                                      fontSize: context.s(13),
                                      color: const Color(0xFF999999),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: context.s(6)),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: context.s(8),
                                backgroundColor: const Color(0xFFEEEEEE),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  tierColor,
                                ),
                              ),
                            ),
                            SizedBox(height: context.s(4)),
                            Text(
                              maxed
                                  ? '已達最高級！（$value）'
                                  : '$value / $nextThreshold　→ ${kTierNames[tier + 1]}牌',
                              style: TextStyle(
                                fontSize: context.s(13),
                                color: const Color(0xFF888888),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
