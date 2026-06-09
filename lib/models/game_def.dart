import 'package:flutter/material.dart';

import 'age_band.dart';
import 'domain.dart';

typedef GameBuilder = Widget Function(BuildContext context);

/// 一個遊戲的中繼資料。新增遊戲 = 寫好遊戲畫面 + 在 registry 加一筆 [GameDef]。
class GameDef {
  const GameDef({
    required this.id,
    required this.title,
    required this.emoji,
    required this.domain,
    required this.ageBands,
    required this.builder,
  });

  /// 全域唯一 id，用於儲存星星進度（key = `stars_<id>`）。
  final String id;
  final String title;
  final String emoji;
  final Domain domain;

  /// 此遊戲支援的年齡段（同一遊戲可用不同關卡資料支援多個齡段）。
  final List<AgeBand> ageBands;

  final GameBuilder builder;

  bool matches(AgeBand band, Domain d) =>
      domain == d && ageBands.contains(band);
}
