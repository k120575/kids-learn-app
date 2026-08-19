import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'entitlement_service.dart';

/// 真正的 Google Play Billing 付費解鎖閘道（換掉 [StubGateway]）。
///
/// 設計：把 `in_app_purchase` 全部隔在這個檔，`entitlement_service.dart` 與所有 UI 都不依賴它，
/// 方便測試、也保持核心乾淨（比照 [DriveCloudGateway] 對 googleapis 的做法）。
///
/// 阻抗轉換：in_app_purchase 是「事件流」模型——買 / 還原都把結果丟到共用的
/// [InAppPurchase.purchaseStream]；而 [PurchaseGateway] 是「請求 → 回應」的 Future 介面。
/// 本類用 completer 把兩者橋接：發起購買後掛一個 completer，等 stream 送來該商品的終態再解析。
///
/// ⚠️ 先決條件（Kevin 在 Play Console，見 docs/PLAY_STORE_LAUNCH.md 軸 B）：
///   1. 建 managed product（**非消耗型**）SKU = [kFullUnlockSku]、定價 TWD 350、狀態設「有效」。
///   2. 設定 License testing 帳號，才能用測試卡免費跑購買 / 還原流程。
///   3. App 必須從 **Play 軌道**（內部 / 封閉測試以上）安裝；本機 sideload 的 debug APK 買不動
///      （isAvailable() 可能為 true，但 queryProductDetails 找不到商品 → buy 回 unavailable）。
class PlayBillingGateway implements PurchaseGateway {
  PlayBillingGateway();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// 本 session 內從 purchaseStream 收集到、已驗證擁有的 SKU。
  final Set<String> _owned = <String>{};

  /// purchaseStream 在還原等待窗內出錯的旗標：此時「沒收到擁有事件」不可信，
  /// [queryOwned] 必須以失敗（丟例外）收場，避免把暫時性錯誤當成「沒買過」。
  bool _streamErrored = false;

  /// 進行中的購買：productID → 等待其終態的 completer。
  final Map<String, Completer<PurchaseResult>> _pendingBuys =
      <String, Completer<PurchaseResult>>{};

  /// 收集還原 / 對帳事件的等待窗：restorePurchases() 沒有「完成」訊號，
  /// 只會把過去的購買重新丟上 stream，故收一小段時間即視為結束。
  static const Duration _restoreWindow = Duration(seconds: 4);

  /// 單筆購買最長等待（避免家長卡在轉圈；正常幾秒內就回）。
  static const Duration _buyTimeout = Duration(minutes: 3);

  /// 懶初始化：第一次用到才訂閱 purchaseStream（整個 App 共用一條）。
  void _ensureListening() {
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (_) {
        _streamErrored = true;
        _failAllPending(PurchaseResult.error);
      },
    );
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          // 待處理（慢速付款 / 待家長核准）——先不解析，等後續終態事件。
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (await _verify(p)) {
            _owned.add(p.productID);
            _resolveBuy(p.productID, PurchaseResult.purchased);
          } else {
            _resolveBuy(p.productID, PurchaseResult.error);
          }
          break;
        case PurchaseStatus.error:
          _resolveBuy(p.productID, PurchaseResult.error);
          break;
        case PurchaseStatus.canceled:
          _resolveBuy(p.productID, PurchaseResult.cancelled);
          break;
      }
      // 不論成敗，pending 的交易都要 complete，否則 Play 會反覆重送同一筆。
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
      }
    }
  }

  /// 驗證購買真偽。買斷商品能出現在 Play 的 purchaseStream，本身即代表 Play 已在裝置端驗過；
  /// 這裡採「信任 Play 本機驗證」（PLAN §9：買斷可接受此風險，不值得自建驗證後端）。
  /// 日後要更強，可在此改用 [PurchaseDetails.verificationData] 做 RSA 簽章驗證或打自家伺服器。
  Future<bool> _verify(PurchaseDetails p) async => true;

  void _resolveBuy(String productId, PurchaseResult r) {
    final Completer<PurchaseResult>? c = _pendingBuys.remove(productId);
    if (c != null && !c.isCompleted) c.complete(r);
  }

  void _failAllPending(PurchaseResult r) {
    for (final Completer<PurchaseResult> c in _pendingBuys.values) {
      if (!c.isCompleted) c.complete(r);
    }
    _pendingBuys.clear();
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// 查詢已擁有的 SKU。⚠️ 回傳空集合＝「確定查過、真的沒有」（呼叫端據此撤銷解鎖）；
  /// 任何查不成的情況（商店不可用、restorePurchases 失敗、等待窗內 stream 出錯）
  /// 一律丟例外，讓 [EntitlementService._reconcile] 維持本機快取——
  /// 否則暫時性失敗會被誤判成「沒買過」，把已付費的家長鎖回去。
  @override
  Future<Set<String>> queryOwned(Set<String> skus) async {
    if (!await isAvailable()) {
      throw StateError('billing unavailable');
    }
    _ensureListening();
    _streamErrored = false;
    // restorePurchases() 把過去的購買重新丟上 purchaseStream；收一小段時間後回報。
    await _iap.restorePurchases();
    await Future<void>.delayed(_restoreWindow);
    if (_streamErrored) {
      throw StateError('purchase stream errored during restore window');
    }
    return _owned.intersection(skus);
  }

  @override
  Future<PurchaseResult> buy(String sku) async {
    if (!await isAvailable()) return PurchaseResult.unavailable;
    _ensureListening();

    // 對帳時已知擁有 → 直接回報，不重複發起購買。
    if (_owned.contains(sku)) return PurchaseResult.alreadyOwned;

    final ProductDetailsResponse resp =
        await _iap.queryProductDetails(<String>{sku});
    if (resp.error != null) return PurchaseResult.error;
    if (resp.productDetails.isEmpty) {
      // SKU 尚未在 Play Console 建好 / 未生效 / 非 Play 軌道安裝。
      return PurchaseResult.unavailable;
    }

    final ProductDetails product = resp.productDetails.first;
    final Completer<PurchaseResult> completer = Completer<PurchaseResult>();
    _pendingBuys[sku] = completer;

    bool started;
    try {
      started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      started = false;
    }
    if (!started) {
      _pendingBuys.remove(sku);
      return PurchaseResult.error;
    }

    // buyNonConsumable 只代表「購買流程已啟動」；真正結果由 purchaseStream 送回。
    return completer.future.timeout(
      _buyTimeout,
      onTimeout: () {
        _pendingBuys.remove(sku);
        return PurchaseResult.error;
      },
    );
  }
}
