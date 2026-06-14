import 'dart:math';

import '../content/achievements.dart';
import '../content/registry.dart';
import '../content/toys.dart';
import '../models/domain.dart';
import '../models/game_def.dart';
import 'progress_store.dart';

/// 扭蛋一次的結果。
class GachaResult {
  const GachaResult(this.toy, this.isNew, this.refund);
  final Toy toy;
  final bool isNew; // 是否為新玩具
  final int refund; // 重複時退回的星星
}

/// 新解鎖（或升級）的成就。
class AchUnlock {
  const AchUnlock(this.achievement, this.tier);
  final Achievement achievement;
  final int tier; // 1=銅 2=銀 3=金
}

final Random _rng = Random();

/// 抽一次扭蛋。星星不足回傳 null。
GachaResult? drawGacha() {
  final ProgressStore store = ProgressStore.instance;
  if (!store.spendStars(kGachaCost)) return null;
  final Toy toy = _randomToy();
  final bool isNew = store.addToy(toy.id);
  int refund = 0;
  if (!isNew) {
    refund = kDuplicateRefund;
    store.refundStars(refund);
  }
  return GachaResult(toy, isNew, refund);
}

Toy _randomToy() {
  // 先依稀有度權重抽稀有度，再從該稀有度玩具中均勻抽一個。
  final int total = ToyRarity.values.fold<int>(
    0,
    (int a, ToyRarity r) => a + r.weight,
  );
  int roll = _rng.nextInt(total);
  ToyRarity picked = ToyRarity.common;
  for (final ToyRarity r in ToyRarity.values) {
    if (roll < r.weight) {
      picked = r;
      break;
    }
    roll -= r.weight;
  }
  final List<Toy> pool = toyPool.where((Toy t) => t.rarity == picked).toList();
  return pool[_rng.nextInt(pool.length)];
}

/// 重新評估所有成就，持久化升級者，回傳「這次新解鎖/升級」的清單（用於慶祝）。
List<AchUnlock> evaluateAchievements() {
  final ProgressStore store = ProgressStore.instance;
  final List<AchUnlock> unlocks = <AchUnlock>[];
  for (final Achievement a in achievements) {
    final int value = achievementMetric(a.metric);
    final int newTier = a.tierFor(value);
    if (newTier > store.achTier(a.id)) {
      store.setAchTier(a.id, newTier);
      unlocks.add(AchUnlock(a, newTier));
    }
  }
  return unlocks;
}

/// 算某個成就指標目前的數值。
int achievementMetric(AchMetric m) {
  final ProgressStore store = ProgressStore.instance;
  switch (m) {
    case AchMetric.domainsPlayed:
      final Set<String> played = store.playedGameIds();
      final Set<Domain> domains = <Domain>{};
      for (final GameDef g in gameRegistry) {
        if (played.contains(g.id)) domains.add(g.domain);
      }
      return domains.length;
    case AchMetric.gamesThreeStar:
      return store.gamesThreeStarCount;
    case AchMetric.earnedTotal:
      return store.earnedTotal;
    case AchMetric.toysCount:
      return store.distinctToyCount;
    case AchMetric.streakBest:
      return store.streakBest;
    case AchMetric.gamesPlayed:
      return store.playedGameIds().length;
    case AchMetric.legendaryToys:
      int n = 0;
      for (final String id in store.toys.keys) {
        if (toyById(id)?.rarity == ToyRarity.legendary) n++;
      }
      return n;
    case AchMetric.rareToys:
      int n = 0;
      for (final String id in store.toys.keys) {
        final ToyRarity? r = toyById(id)?.rarity;
        if (r == ToyRarity.rare || r == ToyRarity.legendary) n++;
      }
      return n;
  }
}
