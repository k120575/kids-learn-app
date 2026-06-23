import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learn_app/core/entitlement_service.dart';

/// 假金流閘道：可設定「商店是否可用 / 已擁有哪些 SKU / 購買回傳什麼」。
class _FakeGateway implements PurchaseGateway {
  _FakeGateway({this.available = true, Set<String>? owned})
      : _owned = owned ?? <String>{};

  final bool available;
  final Set<String> _owned;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Set<String>> queryOwned(Set<String> skus) async =>
      _owned.intersection(skus);

  @override
  Future<PurchaseResult> buy(String sku) async {
    _owned.add(sku);
    return PurchaseResult.purchased;
  }
}

void main() {
  // 無平台環境 → AppDb 未就緒，entitlement 只在記憶體，不持久化。

  test('商店不可用（如骨架/未設定）→ 啟動維持未解鎖', () async {
    EntitlementService.debugSetGateway(_FakeGateway(available: false));
    await EntitlementService.instance.init();
    expect(EntitlementService.instance.isFullUnlocked, isFalse);
  });

  test('帳號已擁有商品 → 啟動對帳即自動解鎖（跨裝置還原）', () async {
    EntitlementService.debugSetGateway(
      _FakeGateway(available: true, owned: <String>{kFullUnlockSku}),
    );
    await EntitlementService.instance.init();
    expect(EntitlementService.instance.isFullUnlocked, isTrue);
  });

  test('購買成功 → 解鎖並通知', () async {
    EntitlementService.debugSetGateway(_FakeGateway(available: true));
    await EntitlementService.instance.init();
    expect(EntitlementService.instance.isFullUnlocked, isFalse);

    bool notified = false;
    EntitlementService.instance.addListener(() => notified = true);

    final PurchaseResult r =
        await EntitlementService.instance.buyFullUnlock();
    expect(r, PurchaseResult.purchased);
    expect(EntitlementService.instance.isFullUnlocked, isTrue);
    expect(notified, isTrue);
  });

  test('商店不可用時購買 → 回 unavailable、維持未解鎖', () async {
    EntitlementService.debugSetGateway(_FakeGateway(available: false));
    await EntitlementService.instance.init();
    final PurchaseResult r =
        await EntitlementService.instance.buyFullUnlock();
    expect(r, PurchaseResult.unavailable);
    expect(EntitlementService.instance.isFullUnlocked, isFalse);
  });

  test('退款撤銷：再次對帳時商店已不擁有 → 取消解鎖', () async {
    // 先擁有並解鎖
    final _FakeGateway g =
        _FakeGateway(available: true, owned: <String>{kFullUnlockSku});
    EntitlementService.debugSetGateway(g);
    await EntitlementService.instance.init();
    expect(EntitlementService.instance.isFullUnlocked, isTrue);
    // 模擬退款：帳號不再擁有 → restore 對帳後應撤銷
    g._owned.remove(kFullUnlockSku);
    final bool ok = await EntitlementService.instance.restore();
    expect(ok, isFalse);
    expect(EntitlementService.instance.isFullUnlocked, isFalse);
  });
}
