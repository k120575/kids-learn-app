/// 成就（獎盃）所依據的統計指標。值都能從 ProgressStore 的記憶體狀態即時算出。
enum AchMetric {
  domainsPlayed, // 玩過幾個領域
  gamesThreeStar, // 幾個遊戲拿過 3 星
  earnedTotal, // 累積賺到的星星總數
  toysCount, // 收集到幾個玩具
  streakBest, // 最佳連續天數
  gamesPlayed, // 玩過幾種遊戲
  legendaryToys, // 收集到幾個「傳說」玩具
  rareToys, // 收集到幾個「稀有或以上」玩具
}

/// 一個成就：三個門檻＝銅／銀／金。達到對應門檻即解鎖該級。
class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.emoji,
    required this.metric,
    required this.tiers, // 長度 3：[銅, 銀, 金] 門檻
  });

  final String id;
  final String name;
  final String emoji;
  final AchMetric metric;
  final List<int> tiers;

  /// 依目前數值算已達等級：0=未達、1=銅、2=銀、3=金。
  int tierFor(int value) {
    int t = 0;
    for (int i = 0; i < tiers.length; i++) {
      if (value >= tiers[i]) t = i + 1;
    }
    return t;
  }
}

const List<String> kTierNames = <String>['', '銅', '銀', '金'];
const List<int> kTierColors = <int>[0xFF9E9E9E, 0xFFCD7F32, 0xFFB0BEC5, 0xFFFFC107];

const List<Achievement> achievements = <Achievement>[
  Achievement(
    id: 'explorer',
    name: '探索家',
    emoji: '🧭',
    metric: AchMetric.domainsPlayed,
    tiers: <int>[1, 3, 5],
  ),
  Achievement(
    id: 'perfectionist',
    name: '完美高手',
    emoji: '🌟',
    metric: AchMetric.gamesThreeStar,
    tiers: <int>[1, 5, 10],
  ),
  Achievement(
    id: 'star_collector',
    name: '星星收集家',
    emoji: '⭐',
    metric: AchMetric.earnedTotal,
    tiers: <int>[50, 200, 500],
  ),
  Achievement(
    id: 'toy_collector',
    name: '玩具收藏家',
    emoji: '🧸',
    metric: AchMetric.toysCount,
    tiers: <int>[10, 30, 60],
  ),
  Achievement(
    id: 'daily_star',
    name: '天天來玩',
    emoji: '🔥',
    metric: AchMetric.streakBest,
    tiers: <int>[3, 7, 14],
  ),
  Achievement(
    id: 'game_master',
    name: '遊戲達人',
    emoji: '🎮',
    metric: AchMetric.gamesPlayed,
    tiers: <int>[3, 8, 16],
  ),
  Achievement(
    id: 'legend_hunter',
    name: '傳說獵人',
    emoji: '🐉',
    metric: AchMetric.legendaryToys,
    tiers: <int>[1, 3, 6],
  ),
  Achievement(
    id: 'rare_collector',
    name: '稀有收藏家',
    emoji: '💠',
    metric: AchMetric.rareToys,
    tiers: <int>[5, 15, 25],
  ),
  Achievement(
    id: 'star_tycoon',
    name: '星星大富翁',
    emoji: '🤑',
    metric: AchMetric.earnedTotal,
    tiers: <int>[1000, 2500, 5000],
  ),
  Achievement(
    id: 'perfect_master',
    name: '完美大師',
    emoji: '💯',
    metric: AchMetric.gamesThreeStar,
    tiers: <int>[15, 22, 29],
  ),
  Achievement(
    id: 'streak_master',
    name: '毅力之星',
    emoji: '📅',
    metric: AchMetric.streakBest,
    tiers: <int>[30, 60, 100],
  ),
  Achievement(
    id: 'collection_king',
    name: '圖鑑之王',
    emoji: '📚',
    metric: AchMetric.toysCount,
    tiers: <int>[45, 55, 65],
  ),
];
