import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learn_app/content/toys.dart';
import 'package:kids_learn_app/core/progress_store.dart';
import 'package:kids_learn_app/core/rewards.dart';

void main() {
  final ProgressStore store = ProgressStore.instance;

  setUp(() async {
    await store.init();
    await store.clearProgress(); // 純記憶體清空，確保乾淨起點
  });

  test('星星錢包：賺、花、退', () async {
    expect(store.balance, 0);
    await store.addEarnedStars(20);
    expect(store.balance, 20);
    expect(store.earnedTotal, 20);
    expect(store.spendStars(15), isTrue);
    expect(store.balance, 5);
    expect(store.spendStars(15), isFalse); // 不夠
    store.refundStars(3);
    expect(store.balance, 8);
    expect(store.earnedTotal, 20); // 退款不計入累積
  });

  test('扭蛋：花 15 星抽到玩具、收進收藏', () async {
    await store.addEarnedStars(kGachaCost);
    final GachaResult? r = drawGacha();
    expect(r, isNotNull);
    expect(toyById(r!.toy.id), isNotNull);
    expect(store.distinctToyCount, 1);
    // 第一次抽必為新玩具 → 餘額歸 0（無退款）
    expect(store.balance, 0);
  });

  test('扭蛋：星星不足回傳 null', () async {
    await store.addEarnedStars(kGachaCost - 1);
    expect(drawGacha(), isNull);
  });

  test('成就：累積星星達門檻解鎖獎盃', () async {
    await store.addEarnedStars(50); // 星星收集家 銅牌門檻
    final List<AchUnlock> unlocks = evaluateAchievements();
    expect(unlocks.any((AchUnlock u) => u.achievement.id == 'star_collector'),
        isTrue);
    expect(store.achTier('star_collector'), 1);
    // 再評估一次不應重複解鎖同一級
    expect(evaluateAchievements().isEmpty, isTrue);
  });

  test('每日簽到：首次連續 1 天並發獎勵', () async {
    await store.dailyCheckIn();
    expect(store.streakCurrent, 1);
    expect(store.balance, greaterThanOrEqualTo(5)); // 至少基本獎勵
    final int afterFirst = store.balance;
    await store.dailyCheckIn(); // 同一天再簽不重複發
    expect(store.balance, afterFirst);
  });
}
