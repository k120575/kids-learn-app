import '../core/entitlement_service.dart';
import '../models/age_band.dart';
import '../models/domain.dart';
import '../models/game_def.dart';
import 'registry.dart';

/// v1.0 上架先「全部免費」：Billing 尚未接（StubGateway 買不動），先把付費鎖整個關掉，
/// 全關卡開放、不顯示任何付費 UI。等接好 PlayBillingGateway 要恢復付費分層時，改回 true 即可
/// —— 付費邏輯（[isGameFree]/EntitlementService/PaywallScreen）全部留著，翻旗標就回來。
const bool kPaywallEnabled = false;

/// 免費／付費內容切分的單一事實來源。完整設計見 docs/PLAN_billing_sync.md §2.3。
///
/// 規則（純資料驅動，方便日後調整免費厚度）：
/// - 3-4 歲：全領域全關卡免費。
/// - 4-5 / 5-6 歲：每個（年齡段 × 領域）依 registry 順序的「第一關」免費試玩，其餘鎖。
/// - 已購買完整版（[EntitlementService.isFullUnlocked]）：全部解鎖。
/// - [kPaywallEnabled] 為 false 時：全部視為已解鎖（v1.0 免費上架）。
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

  /// 玩家現在能不能玩這一關（付費鎖關閉時全開放；否則已購完整版或本就免費才開）。
  static bool isUnlocked(GameDef g, AgeBand band) {
    if (!kPaywallEnabled) return true;
    return EntitlementService.instance.isFullUnlocked || isGameFree(g, band);
  }
}
