import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learn_app/content/registry.dart';
import 'package:kids_learn_app/models/age_band.dart';
import 'package:kids_learn_app/models/domain.dart';
import 'package:kids_learn_app/models/game_def.dart';

void main() {
  test('開放的年齡段：3-4 / 4-5 / 5-6', () {
    expect(AgeBand.enabledBands,
        <AgeBand>[AgeBand.age3_4, AgeBand.age4_5, AgeBand.age5_6]);
  });

  test('註冊表中的遊戲 id 不重複', () {
    final Set<String> ids = <String>{};
    for (final GameDef g in gameRegistry) {
      expect(ids.add(g.id), isTrue, reason: '重複的遊戲 id: ${g.id}');
    }
  });

  test('每個語文遊戲都至少存在', () {
    final List<GameDef> langGames =
        gameRegistry.where((GameDef g) => g.domain == Domain.language).toList();
    expect(langGames.isNotEmpty, isTrue);
  });
}
