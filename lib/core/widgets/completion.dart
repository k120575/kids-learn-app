import 'package:flutter/material.dart';

import '../../content/achievements.dart';
import '../audio_service.dart';
import '../responsive.dart';
import '../rewards.dart';
import '../theme.dart';
import 'big_card.dart';
import 'penguin.dart';

/// 完成一個遊戲時跳出的慶祝對話框。
/// 顯示本局賺到的星星、星星罐總額，以及這次新解鎖的成就獎盃。
/// 回傳 true 表示「再玩一次」，false / null 表示「回去」。
Future<bool> showCompletionDialog(
  BuildContext context, {
  required int stars,
  required int balance,
  List<AchUnlock> newAchievements = const <AchUnlock>[],
}) async {
  if (newAchievements.isNotEmpty) {
    AudioService.instance.speak('太棒了，你得到一個新獎盃！');
  }
  final bool? again = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: EdgeInsets.all(context.s(16)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sizes.radius),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: context.s(24),
              vertical: context.s(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Penguin(size: context.s(64)),
                SizedBox(height: context.s(6)),
                Text(
                  '全部完成！',
                  style: TextStyle(
                    fontSize: context.s(24),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: context.s(8)),
                StarsRow(count: stars, size: 32), // StarsRow 內部已縮放
                SizedBox(height: context.s(8)),
                // 賺到的星星進星星罐
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.s(16),
                    vertical: context.s(8),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '+$stars ⭐ 進星星罐　（共 $balance ⭐）',
                    style: TextStyle(
                      fontSize: context.s(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (newAchievements.isNotEmpty) ...<Widget>[
                  SizedBox(height: context.s(12)),
                  Text(
                    '🏆 解鎖新獎盃！',
                    style: TextStyle(
                      fontSize: context.s(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.s(6)),
                  ...newAchievements.map((AchUnlock u) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (BuildContext context, double t, Widget? child) {
                        return Transform.scale(scale: t, child: child);
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: context.s(4)),
                        padding: EdgeInsets.symmetric(
                          horizontal: context.s(14),
                          vertical: context.s(8),
                        ),
                        decoration: BoxDecoration(
                          color: Color(
                            kTierColors[u.tier],
                          ).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Color(kTierColors[u.tier]),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '${u.achievement.emoji} ${u.achievement.name}・'
                          '${kTierNames[u.tier]}牌',
                          style: TextStyle(
                            fontSize: context.s(16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                SizedBox(height: context.s(18)),
                Wrap(
                  spacing: context.s(Sizes.gap),
                  runSpacing: context.s(10),
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(context.s(150), context.s(56)),
                        textStyle: TextStyle(fontSize: context.s(20)),
                      ),
                      icon: Icon(Icons.refresh_rounded, size: context.s(26)),
                      label: const Text('再玩一次'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(context.s(150), context.s(56)),
                        textStyle: TextStyle(fontSize: context.s(20)),
                      ),
                      icon: Icon(Icons.home_rounded, size: context.s(26)),
                      label: const Text('回去'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return again ?? false;
}
