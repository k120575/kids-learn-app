import 'package:flutter/foundation.dart';

import 'db.dart';

/// Phase 1 付費解鎖（一次性買斷）的 App 端核心。完整設計見 docs/PLAN_billing_sync.md §2。
///
/// 這是「骨架」：解鎖狀態的快取、持久化、對外 API、對帳/還原流程都已就緒且可單元測試。
/// 真正打 Google Play Billing 的部分抽在 [PurchaseGateway] 介面後，預設用 [StubGateway]
/// （永遠回報「商店不可用」）。等 Play Console 商品開好後，新增一個 in_app_purchase 的
/// 實作換上去即可，本檔與所有 UI 都不用改。

/// Play Console 上的商品 ID（非消耗型 managed product，NT$350）。
const String kFullUnlockSku = 'full_unlock_family';

/// 一次購買嘗試的結果。
enum PurchaseResult { purchased, alreadyOwned, cancelled, unavailable, error }

/// 金流閘道：把 in_app_purchase 隔在介面後，方便測試注入假實作，也方便日後替換驗證後端。
abstract class PurchaseGateway {
  /// 商店是否可用（未設定 / 不支援的平台 → false）。
  Future<bool> isAvailable();

  /// 查詢目前 Google 帳號已擁有哪些 SKU（啟動對帳 / 還原用）。
  Future<Set<String>> queryOwned(Set<String> skus);

  /// 發起購買。[PurchaseResult.purchased] 與 [alreadyOwned] 視為「已解鎖」。
  Future<PurchaseResult> buy(String sku);
}

/// 預設骨架實作：商店一律不可用。換成真的 Play Billing 前的佔位。
///
/// TODO(billing): 新增 `PlayBillingGateway implements PurchaseGateway`，以 in_app_purchase 實作：
///   - isAvailable() → `InAppPurchase.instance.isAvailable()`
///   - queryOwned()  → `restorePurchases()` + 監聽 `purchaseStream` 過濾 productID，
///                     對每筆做 `_verify()`（PLAN §2.2 本機+Google 簽章驗證），再 `completePurchase()`
///   - buy()         → `queryProductDetails({sku})` → `buyNonConsumable(...)` → 監聽 stream
///   接上後把 [EntitlementService.instance] 的 gateway 換成它（見檔尾說明）。
///   先決條件（Kevin 在 Play Console）：建好 managed product「full_unlock_family」NT$350、
///   設定 License 測試帳號，否則 isAvailable() 會是 false、購買流程跑不動。
class StubGateway implements PurchaseGateway {
  const StubGateway();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<Set<String>> queryOwned(Set<String> skus) async => <String>{};

  @override
  Future<PurchaseResult> buy(String sku) async => PurchaseResult.unavailable;
}

/// 解鎖狀態的單一事實來源。UI 同步讀 [isFullUnlocked]，購買後 notifyListeners 觸發刷新。
class EntitlementService extends ChangeNotifier {
  EntitlementService._(this._gateway);

  /// 全域單例。預設用骨架閘道；接上真 Billing 後改這裡的 gateway。
  static EntitlementService instance = EntitlementService._(const StubGateway());

  /// 測試用：注入假閘道並重置狀態。
  @visibleForTesting
  static void debugSetGateway(PurchaseGateway gateway) {
    instance = EntitlementService._(gateway);
  }

  final PurchaseGateway _gateway;

  static const String _settingKey = 'entitlement_full';

  bool _entitled = false;

  /// 是否已解鎖完整版（全域、跟 Google 帳號走）。UI 直接讀。
  bool get isFullUnlocked => _entitled;

  /// 啟動：先信任本機快取（離線也能用），再（商店可用時）對帳還原。失敗不阻擋進 App。
  Future<void> init() async {
    _entitled = await _loadCache();
    notifyListeners();
    await _reconcile();
  }

  /// 與商店對帳：以商店為準（涵蓋換機還原與退款撤銷）。商店不可用時維持快取。
  Future<void> _reconcile() async {
    try {
      if (!await _gateway.isAvailable()) return;
      final Set<String> owned = await _gateway.queryOwned(<String>{kFullUnlockSku});
      await _setEntitled(owned.contains(kFullUnlockSku));
    } catch (_) {
      // 離線 / 尚未設定 → 維持本機快取。
    }
  }

  /// 觸發購買（呼叫端須已通過 parent gate）。回傳購買結果供 UI 顯示訊息。
  Future<PurchaseResult> buyFullUnlock() async {
    try {
      if (!await _gateway.isAvailable()) return PurchaseResult.unavailable;
      final PurchaseResult r = await _gateway.buy(kFullUnlockSku);
      if (r == PurchaseResult.purchased || r == PurchaseResult.alreadyOwned) {
        await _setEntitled(true);
      }
      return r;
    } catch (_) {
      return PurchaseResult.error;
    }
  }

  /// 還原購買（換機後保險）。回傳還原後是否為已解鎖。
  Future<bool> restore() async {
    await _reconcile();
    return _entitled;
  }

  Future<void> _setEntitled(bool v) async {
    if (_entitled == v) return;
    _entitled = v;
    await _saveCache(v);
    notifyListeners();
  }

  Future<bool> _loadCache() async {
    if (!AppDb.instance.ready) return false;
    try {
      final Map<String, String> s = await AppDb.instance.loadSettings();
      return (s[_settingKey] ?? '0') == '1';
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveCache(bool v) async {
    if (!AppDb.instance.ready) return;
    try {
      await AppDb.instance.setSetting(_settingKey, v ? '1' : '0');
    } catch (_) {}
  }
}
