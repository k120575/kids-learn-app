import '../core/entitlement_service.dart';
import '../models/age_band.dart';
import '../models/domain.dart';
import '../models/game_def.dart';
import 'registry.dart';

/// 付費分層總開關。true＝依 [isGameFree] 鎖付費關卡、顯示付費 UI，接 [PlayBillingGateway] 真實購買。
///
/// ⚠️ 送審／打包前必查（見 docs/PLAY_STORE_LAUNCH.md 軸 B 清單、[[play-phase2-must-change]]）：
/// 這個 true 只能搭配「Play Console 已建好商品 [kFullUnlockSku]（NT$350 非消耗型、狀態有效）」
/// 一起出貨，否則會「鎖了又買不了」。同時 Play 問卷要改：App access 否→是（附審查解鎖說明）、
/// Content ratings 數位購買 No→Yes。付費只能在 Play 軌道（內部/封閉測試以上）測，本機 sideload 買不動。
const bool kPaywallEnabled = true;

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
