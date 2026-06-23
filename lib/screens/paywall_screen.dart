import 'package:flutter/material.dart';

import '../core/entitlement_service.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/game_scaffold.dart';

/// 付費牆（解鎖完整版）。完整設計見 docs/PLAN_billing_sync.md §2.5。
///
/// 進到這頁前一定已通過 parent gate（鎖關卡點擊 / 設定頁入口），所以可直接對家長顯示價格。
/// 文案對「家長」講價值，不對孩子做誘導。一次買斷、非訂閱、不自動扣款是台灣家長的信任賣點。
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  // TODO(billing): 商店可用後改用 ProductDetails.price 顯示在地化價格字串，
  //   而非寫死；目前 StubGateway 不回商品資料，先用規劃定價。
  static const String _priceLabel = 'NT\$350';

  bool _busy = false;

  static const List<(String, String)> _benefits = <(String, String)>[
    ('🔓', '解鎖 4-5、5-6 歲全部關卡'),
    ('📊', '家長學習報告完整版'),
    ('👨‍👩‍👧‍👦', '全部孩子檔案共用，不限人數'),
    ('☁️', '進度雲端同步、換手機也不怕不見'),
    ('💛', '一次買斷 · 非訂閱 · 不會自動扣款'),
  ];

  Future<void> _buy() async {
    setState(() => _busy = true);
    final PurchaseResult r = await EntitlementService.instance.buyFullUnlock();
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == PurchaseResult.purchased || r == PurchaseResult.alreadyOwned) {
      _toast('解鎖成功，謝謝你！🎉');
      Navigator.of(context).pop(true);
    } else if (r == PurchaseResult.unavailable) {
      // 骨架階段（Play Console 商品尚未開通）會走到這裡。
      _toast('暫時無法購買，請稍後再試 🙏');
    } else if (r == PurchaseResult.error) {
      _toast('購買時發生問題，請稍後再試');
    }
    // cancelled：使用者自己取消，不提示。
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final bool ok = await EntitlementService.instance.restore();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(ok ? '已還原你的購買 ✅' : '這個帳號目前沒有可還原的購買');
    if (ok) Navigator.of(context).pop(true);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: '完整版',
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.s(Sizes.bigGap)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('🎁', style: TextStyle(fontSize: context.s(56))),
                SizedBox(height: context.s(Sizes.gap)),
                Text(
                  '解鎖寶貝的完整學習樂園',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: context.s(24),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: context.s(Sizes.bigGap)),
                ..._benefits.map(
                  (e) => Padding(
                    padding: EdgeInsets.symmetric(vertical: context.s(6)),
                    child: Row(
                      children: <Widget>[
                        Text(e.$1, style: TextStyle(fontSize: context.s(24))),
                        SizedBox(width: context.s(12)),
                        Expanded(
                          child: Text(
                            e.$2,
                            style: TextStyle(fontSize: context.s(18)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: context.s(Sizes.bigGap)),
                ElevatedButton(
                  onPressed: _busy ? null : _buy,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.fromHeight(context.s(64)),
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: Colors.white,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '解鎖完整版 · $_priceLabel',
                          style: TextStyle(
                            fontSize: context.s(20),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                SizedBox(height: context.s(Sizes.gap)),
                TextButton(
                  onPressed: _busy ? null : _restore,
                  child: Text(
                    '我已經買過了，還原購買',
                    style: TextStyle(fontSize: context.s(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
