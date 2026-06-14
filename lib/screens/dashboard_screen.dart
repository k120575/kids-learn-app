import 'dart:math';

import 'package:flutter/material.dart';

import '../content/registry.dart';
import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/game_scaffold.dart';
import '../models/game_def.dart';

/// 家長學習報告（由家長鎖進入）：使用時間、遊玩次數、各遊戲表現與常錯處。
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _gameTitle(String id) {
    for (final GameDef g in gameRegistry) {
      if (g.id == id) return '${g.emoji} ${g.title}';
    }
    return id;
  }

  String _todayKey() {
    final DateTime n = DateTime.now();
    final String m = n.month.toString().padLeft(2, '0');
    final String d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final ProgressStore store = ProgressStore.instance;
    return GameScaffold(
      title: '學習報告・${store.activeProfile.name}',
      child: FutureBuilder<List<Object?>>(
        future: Future.wait<Object?>(<Future<Object?>>[
          store.dailyTime(),
          store.gameStats(),
        ]),
        builder: (BuildContext context, AsyncSnapshot<List<Object?>> snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final Map<String, int> daily = snap.data![0] as Map<String, int>;
          final List<Map<String, Object?>> stats =
              (snap.data![1] as List<Map<String, Object?>>);

          final int todaySec = daily[_todayKey()] ?? 0;
          final int weekSec = daily.values.fold<int>(
            0,
            (int a, int b) => a + b,
          );
          final int totalPlays = stats.fold<int>(
            0,
            (int a, Map<String, Object?> r) => a + (r['plays'] as int? ?? 0),
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: EdgeInsets.all(context.s(Sizes.bigGap)),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _StatCard(
                          icon: Icons.today_rounded,
                          label: '今天',
                          value: '${(todaySec / 60).round()} 分',
                        ),
                      ),
                      SizedBox(width: context.s(Sizes.gap)),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.date_range_rounded,
                          label: '近兩週',
                          value: '${(weekSec / 60).round()} 分',
                        ),
                      ),
                      SizedBox(width: context.s(Sizes.gap)),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.videogame_asset_rounded,
                          label: '遊玩次數',
                          value: '$totalPlays',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.s(Sizes.bigGap)),
                  _TrendChart(daily: daily),
                  SizedBox(height: context.s(Sizes.bigGap)),
                  Text(
                    '各遊戲表現',
                    style: TextStyle(
                      fontSize: context.s(20),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.s(8)),
                  if (stats.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: context.s(24)),
                      child: Text(
                        '還沒有遊玩紀錄，陪孩子玩幾關就會出現囉！',
                        style: TextStyle(
                          fontSize: context.s(16),
                          color: const Color(0xFF888888),
                        ),
                      ),
                    )
                  else
                    ...stats.map((Map<String, Object?> r) {
                      final int plays = r['plays'] as int? ?? 0;
                      final int mistakes = r['mistakes'] as int? ?? 0;
                      final int best = r['best'] as int? ?? 0;
                      return Card(
                        child: ListTile(
                          title: Text(
                            _gameTitle(r['game_id'] as String),
                            style: TextStyle(fontSize: context.s(18)),
                          ),
                          subtitle: Text(
                            '玩了 $plays 次・最佳 '
                            '${'⭐' * best}　累計答錯 $mistakes 次',
                          ),
                          trailing: mistakes >= plays * 3 && plays > 0
                              ? const Tooltip(
                                  message: '這個遊戲較常出錯，可多陪孩子練習',
                                  child: Icon(
                                    Icons.flag_rounded,
                                    color: Color(0xFFEF5350),
                                  ),
                                )
                              : null,
                        ),
                      );
                    }),
                  SizedBox(height: context.s(Sizes.gap)),
                  Text(
                    '小提醒：星星依「答對表現」給 1～3 顆；🚩 代表該遊戲較常答錯，'
                    '可以多陪孩子玩幾次或調整難度。',
                    style: TextStyle(
                      fontSize: context.s(14),
                      color: const Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 近兩週每日學習時間長條圖（用 dailyTime() 既有資料，不需額外儲存）。
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.daily});

  final Map<String, int> daily;

  String _key(DateTime d) {
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final List<DateTime> days = List<DateTime>.generate(
      14,
      (int i) => now.subtract(Duration(days: 13 - i)),
    );
    final List<int> mins = days
        .map((DateTime d) => ((daily[_key(d)] ?? 0) / 60).round())
        .toList();
    final int maxMin = max(1, mins.reduce(max));
    final bool hasAny = mins.any((int m) => m > 0);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.s(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '近兩週學習時間',
              style: TextStyle(
                fontSize: context.s(20),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.s(12)),
            if (!hasAny)
              Padding(
                padding: EdgeInsets.symmetric(vertical: context.s(20)),
                child: Text(
                  '還沒有紀錄，陪孩子玩幾關就會出現囉！',
                  style: TextStyle(
                    fontSize: context.s(15),
                    color: const Color(0xFF888888),
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints _) {
                  // 圖表高度依裝置螢幕高度調整（RWD，不寫死像素）。
                  final double chartH =
                      (MediaQuery.of(context).size.height * 0.24).clamp(
                        130.0,
                        240.0,
                      );
                  return SizedBox(
                    height: chartH,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List<Widget>.generate(days.length, (int i) {
                        final int m = mins[i];
                        final bool today = i == days.length - 1;
                        // 長條高度為「圖表高度的比例」（最高約 60%，0 分鐘留一點點），
                        // 上下方留給數字/日期標籤；外層 Flexible 夾住，任何裝置/字體都不溢出。
                        final double factor = m == 0
                            ? 0.02
                            : 0.08 + (m / maxMin) * 0.52;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.s(2),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                Text(
                                  m > 0 ? '$m' : '',
                                  style: TextStyle(
                                    fontSize: context.s(10),
                                    color: const Color(0xFF888888),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: context.s(2)),
                                Flexible(
                                  child: Container(
                                    height: chartH * factor,
                                    decoration: BoxDecoration(
                                      color: m == 0
                                          ? Colors.grey.shade300
                                          : (today
                                                ? const Color(0xFFFFC107)
                                                : const Color(0xFF42A5F5)),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: context.s(4)),
                                Text(
                                  '${days[i].day}',
                                  style: TextStyle(
                                    fontSize: context.s(10),
                                    color: today
                                        ? const Color(0xFFB8860B)
                                        : const Color(0xFFAAAAAA),
                                    fontWeight: today
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
            SizedBox(height: context.s(6)),
            Text(
              '數字為當天分鐘數，黃色是今天。',
              style: TextStyle(
                fontSize: context.s(12),
                color: const Color(0xFFAAAAAA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: context.s(16),
          horizontal: context.s(8),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: context.s(28), color: const Color(0xFF42A5F5)),
            SizedBox(height: context.s(6)),
            Text(
              value,
              style: TextStyle(
                fontSize: context.s(22),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: context.s(14),
                color: const Color(0xFF888888),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
