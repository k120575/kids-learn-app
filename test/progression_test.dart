import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learn_app/core/game_complete.dart';
import 'package:kids_learn_app/core/progress_store.dart';

void main() {
  test('分級星星：全對 3、錯 1~2 給 2、錯 3+ 給 1（永不為 0）', () {
    expect(starsForMistakes(0), 3);
    expect(starsForMistakes(1), 2);
    expect(starsForMistakes(2), 2);
    expect(starsForMistakes(3), 1);
    expect(starsForMistakes(9), 1);
  });

  test('適性難度：全對升級、錯多降級、夾在 0~2', () async {
    await ProgressStore.instance.init(); // 無平台 → 純記憶體
    const String g = 'diff_test_game';

    expect(ProgressStore.instance.levelFor(g), 1); // 預設一般

    await ProgressStore.instance.recordOutcome(g, 0); // 全對 → 升
    expect(ProgressStore.instance.levelFor(g), 2);

    await ProgressStore.instance.recordOutcome(g, 0); // 已最高，維持
    expect(ProgressStore.instance.levelFor(g), 2);

    await ProgressStore.instance.recordOutcome(g, 4); // 錯多 → 降
    expect(ProgressStore.instance.levelFor(g), 1);

    await ProgressStore.instance.recordOutcome(g, 4); // 再降
    expect(ProgressStore.instance.levelFor(g), 0);

    await ProgressStore.instance.recordOutcome(g, 4); // 已最低，維持
    expect(ProgressStore.instance.levelFor(g), 0);

    await ProgressStore.instance.recordOutcome(g, 1); // 1~2 錯 → 不變
    expect(ProgressStore.instance.levelFor(g), 0);
  });

  test('星星只保留最佳成績', () async {
    await ProgressStore.instance.init();
    const String g = 'best_star_game';
    await ProgressStore.instance.recordStars(g, 2);
    expect(ProgressStore.instance.starsFor(g), 2);
    await ProgressStore.instance.recordStars(g, 1); // 較差 → 不覆蓋
    expect(ProgressStore.instance.starsFor(g), 2);
    await ProgressStore.instance.recordStars(g, 3); // 較好 → 更新
    expect(ProgressStore.instance.starsFor(g), 3);
  });
}
