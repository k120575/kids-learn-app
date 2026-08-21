import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learn_app/core/game_complete.dart';
import 'package:kids_learn_app/games/memory_game.dart';

/// 記憶翻牌的星星/適性放寬規則：翻錯是探索的常態，以「相對牌數」正規化，
/// 不直接套全域「錯 1~2 次才有 2⭐」的選擇題標準（那會讓 3⭐ 全靠運氣、
/// 且適性難度因錯≥3 恆降級）。
void main() {
  test('錯 ≤ 對數 → 3⭐（正規化 0，難度會升）', () {
    expect(starsForMistakes(MemoryGame.normalizedMistakes(0, 6)), 3);
    expect(starsForMistakes(MemoryGame.normalizedMistakes(6, 6)), 3);
    expect(starsForMistakes(MemoryGame.normalizedMistakes(8, 8)), 3);
    expect(starsForMistakes(MemoryGame.normalizedMistakes(10, 10)), 3);
  });

  test('對數 < 錯 ≤ 兩倍對數 → 2⭐（正規化 2，難度持平）', () {
    expect(starsForMistakes(MemoryGame.normalizedMistakes(7, 6)), 2);
    expect(starsForMistakes(MemoryGame.normalizedMistakes(12, 6)), 2);
    expect(starsForMistakes(MemoryGame.normalizedMistakes(16, 8)), 2);
    // 適性難度：正規化 2 不觸發降級（recordOutcome 降級門檻是 ≥3）
    expect(MemoryGame.normalizedMistakes(12, 6), lessThan(3));
  });

  test('錯 > 兩倍對數 → 1⭐（正規化 3，難度會降）', () {
    expect(starsForMistakes(MemoryGame.normalizedMistakes(13, 6)), 1);
    expect(starsForMistakes(MemoryGame.normalizedMistakes(30, 8)), 1);
    expect(MemoryGame.normalizedMistakes(13, 6), 3);
  });
}
