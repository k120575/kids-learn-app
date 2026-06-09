import 'package:flutter/material.dart';

import 'audio_service.dart';
import 'progress_store.dart';
import 'rewards.dart';
import 'widgets/completion.dart';

/// 依本局錯誤次數換算星數：全對 3 ⭐、錯 1~2 次 2 ⭐、錯 ≥3 次 1 ⭐。
/// 永遠至少 1 ⭐——不因失誤而「零分」，維持正向鼓勵。
int starsForMistakes(int mistakes) =>
    mistakes <= 0 ? 3 : (mistakes <= 2 ? 2 : 1);

/// 共用的「完成一關」流程：
/// 算星數（依表現）→ 記最佳星數 → 寫遊玩紀錄 → 微調難度 →
/// **把星星存進星星罐（貨幣）** → 評估成就 → 慶祝對話框（含賺到的星星與新獎盃）。
/// 回傳 true 表示玩家想「再玩一次」。
///
/// [mistakes]：本局答錯次數。沒有「對錯」概念的遊戲（數數、節奏、迷宮）省略，
/// 預設 0（即 3 ⭐）。
Future<bool> finishGame(
  BuildContext context,
  String gameId, {
  int mistakes = 0,
}) async {
  final int stars = starsForMistakes(mistakes);
  final ProgressStore store = ProgressStore.instance;
  await store.recordStars(gameId, stars); // 最佳星數（家長報告）
  await store.recordOutcome(gameId, mistakes); // 適性難度
  await store.logPlay(gameId, stars: stars, mistakes: mistakes);
  await store.addEarnedStars(stars); // 星星進錢包（可拿去扭蛋）
  final List<AchUnlock> unlocks = evaluateAchievements();
  AudioService.instance.finished();
  if (!context.mounted) return false;
  return showCompletionDialog(
    context,
    stars: stars,
    balance: store.balance,
    newAchievements: unlocks,
  );
}
