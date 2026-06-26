import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learn_app/content/access_policy.dart';
import 'package:kids_learn_app/content/registry.dart';
import 'package:kids_learn_app/core/entitlement_service.dart';
import 'package:kids_learn_app/models/age_band.dart';
import 'package:kids_learn_app/models/domain.dart';
import 'package:kids_learn_app/models/game_def.dart';

GameDef _game(String id) =>
    gameRegistry.firstWhere((GameDef g) => g.id == id);

/// 假閘道：固定回報「是否已購」，讓我們切換 entitled 狀態測 isUnlocked。
class _Gateway implements PurchaseGateway {
  _Gateway(this.owned);
  final bool owned;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<Set<String>> queryOwned(Set<String> skus) async =>
      owned ? skus : <String>{};
  @override
  Future<PurchaseResult> buy(String sku) async => PurchaseResult.purchased;
}

Future<void> _setEntitled(bool v) async {
  EntitlementService.debugSetGateway(_Gateway(v));
  await EntitlementService.instance.init();
}

void main() {
  group('isGameFree（與付費無關的免費切分）', () {
    test('3-4 歲：整段免費', () {
      expect(AccessPolicy.isGameFree(_game('listen_point'), AgeBand.age3_4),
          isTrue);
      expect(AccessPolicy.isGameFree(_game('count_tap'), AgeBand.age3_4),
          isTrue);
    });

    test('4-5 歲：每領域第一關免費試玩、其餘鎖', () {
      // 語文第一關 = listen_point_45（registry 順序）
      expect(AccessPolicy.firstGameId(AgeBand.age4_5, Domain.language),
          'listen_point_45');
      expect(AccessPolicy.isGameFree(_game('listen_point_45'), AgeBand.age4_5),
          isTrue);
      expect(AccessPolicy.isGameFree(_game('opposites'), AgeBand.age4_5),
          isFalse);
      // 數學第一關 = arithmetic
      expect(AccessPolicy.isGameFree(_game('arithmetic'), AgeBand.age4_5),
          isTrue);
      expect(AccessPolicy.isGameFree(_game('compare'), AgeBand.age4_5),
          isFalse);
    });

    test('5-6 歲：同樣只有第一關免費', () {
      final String? first =
          AccessPolicy.firstGameId(AgeBand.age5_6, Domain.language);
      expect(first, isNotNull);
      expect(AccessPolicy.isGameFree(_game(first!), AgeBand.age5_6), isTrue);
    });
  });

  group('isUnlocked（疊上付費狀態）', () {
    if (kPaywallEnabled) {
      test('未購買：鎖的關卡 isUnlocked = false', () async {
        await _setEntitled(false);
        expect(AccessPolicy.isUnlocked(_game('opposites'), AgeBand.age4_5),
            isFalse);
        // 免費試玩關仍可玩
        expect(
            AccessPolicy.isUnlocked(_game('listen_point_45'), AgeBand.age4_5),
            isTrue);
      });

      test('已購買：全部解鎖', () async {
        await _setEntitled(true);
        expect(AccessPolicy.isUnlocked(_game('opposites'), AgeBand.age4_5),
            isTrue);
        expect(AccessPolicy.isUnlocked(_game('compare'), AgeBand.age4_5),
            isTrue);
      });
    } else {
      test('付費鎖關閉（v1.0 免費）：未購買也全部 isUnlocked = true', () async {
        await _setEntitled(false);
        expect(AccessPolicy.isUnlocked(_game('opposites'), AgeBand.age4_5),
            isTrue);
        expect(AccessPolicy.isUnlocked(_game('compare'), AgeBand.age4_5),
            isTrue);
      });
    }

    // 還原預設狀態，避免污染其他測試的全域單例。
    tearDownAll(() => _setEntitled(false));
  });
}
