import '../core/entitlement_service.dart';
import '../models/age_band.dart';
import '../models/domain.dart';
import '../models/game_def.dart';
import 'registry.dart';

/// 免費／付費內容切分的單一事實來源。完整設計見 docs/PLAN_billing_sync.md §2.3。
///
/// 規則（純資料驅動，方便日後調整免費厚度）：
/// - 3-4 歲：全領域全關卡免費。
/// - 4-5 / 5-6 歲：每個（年齡段 × 領域）依 registry 順序的「第一關」免費試玩，其餘鎖。
/// - 已購買完整版（[EntitlementService.isFullUnlocked]）：全部解鎖。
///
/// 鎖定是「政策」不是 GameDef 的資料屬性，故獨立於 registry 之外，吃 registry 既有順序。
class AccessPolicy {
  const AccessPolicy._();

  /// 該（年齡段 × 領域）依 registry 順序的第一關 id（＝試玩關）。找不到回 null。
  static String? firstGameId(AgeBand band, Domain domain) {
    for (final GameDef g in gameRegistry) {
      if (g.matches(band, domain)) return g.id;
    }
    return null;
  }

  /// 不論是否付費，這一關本身是否屬「免費開放」（3-4 全段，或各領域試玩關）。
  static bool isGameFree(GameDef g, AgeBand band) {
    if (band == AgeBand.age3_4) return true;
    return g.id == firstGameId(band, g.domain);
  }

  /// 玩家現在能不能玩這一關（已購完整版，或這關本就免費）。
  static bool isUnlocked(GameDef g, AgeBand band) {
    return EntitlementService.instance.isFullUnlocked || isGameFree(g, band);
  }
}
