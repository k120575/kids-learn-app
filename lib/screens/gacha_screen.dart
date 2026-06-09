import 'package:flutter/material.dart';

import '../content/toys.dart';
import '../core/audio_service.dart';
import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/rewards.dart';
import '../core/theme.dart';
import '../core/widgets/game_scaffold.dart';
import '../core/widgets/gacha_machine.dart';
import '../core/widgets/reward_background.dart';
import 'collection_screen.dart';

/// 扭蛋機：用星星抽玩具模型。抽到重複退一點星星。
class GachaScreen extends StatefulWidget {
  const GachaScreen({super.key});

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen>
    with SingleTickerProviderStateMixin {
  final ProgressStore _store = ProgressStore.instance;
  GachaResult? _result;
  bool _spinning = false;
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    if (_spinning || _store.balance < kGachaCost) return;
    setState(() {
      _spinning = true;
      _result = null;
    });
    AudioService.instance.tap();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final GachaResult? r = drawGacha();
    if (!mounted) return;
    setState(() {
      _result = r;
      _spinning = false;
    });
    _ctrl.forward(from: 0);
    if (r != null && r.isNew) {
      AudioService.instance.correct();
    } else {
      AudioService.instance.tap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canDraw = _store.balance >= kGachaCost && !_spinning;
    return GameScaffold(
      title: '扭蛋機',
      backgroundWidget: const RewardBackground(),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Sizes.bigGap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 星星餘額
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFC107), width: 2),
                ),
                child: Text('⭐ ${_store.balance}',
                    style: TextStyle(
                        fontSize: context.s(26), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: Sizes.gap),
              // 扭蛋機本體 + 結果（高度別吃滿 1.6×，否則平板上整欄會超出可視範圍、
              // 把下方「收藏室」按鈕擠出畫面外）
              SizedBox(
                width: context.s(175),
                height: context.s(205),
                child: Center(
                  child: _result == null
                      ? GachaMachine(spinning: _spinning)
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ScaleTransition(
                            scale: CurvedAnimation(
                                parent: _ctrl, curve: Curves.elasticOut),
                            child: _ResultView(result: _result!),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: Sizes.bigGap),
              ElevatedButton.icon(
                onPressed: canDraw ? _draw : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(context.s(220), context.s(64)),
                  textStyle: TextStyle(
                      fontSize: context.s(22), fontWeight: FontWeight.bold),
                  // 用對比強的紫底（暖色背景上才看得到黃色星星）；
                  // 停用時也保持實心紫，不要變半透明暖色。
                  backgroundColor: const Color(0xFF7C4DFF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF9575CD),
                  disabledForegroundColor: Colors.white,
                ),
                icon: Icon(Icons.casino_rounded, size: context.s(28)),
                label: Text('轉一次（$kGachaCost ⭐）'),
              ),
              if (_store.balance < kGachaCost)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('再多玩幾關賺星星就能轉囉！',
                      style: TextStyle(fontSize: context.s(15), color: const Color(0xFF888888))),
                ),
              const SizedBox(height: Sizes.gap),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const CollectionScreen()),
                ),
                icon: const Icon(Icons.collections_bookmark_rounded),
                label: Text('我的收藏室（${_store.distinctToyCount}/${toyPool.length}）',
                    style: TextStyle(fontSize: context.s(16))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});
  final GachaResult result;

  @override
  Widget build(BuildContext context) {
    final Toy toy = result.toy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: toy.rarity.color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: toy.rarity.color, width: 3),
          ),
          child: Text(toy.id, style: TextStyle(fontSize: context.s(76))),
        ),
        const SizedBox(height: 6),
        Text('${toy.rarity.label}・${toy.name}',
            style: TextStyle(
                fontSize: context.s(18),
                fontWeight: FontWeight.bold,
                color: toy.rarity.color)),
        Text(
          result.isNew ? '🎉 新玩具！' : '已有，退回 ${result.refund} ⭐',
          style: TextStyle(fontSize: context.s(15), color: const Color(0xFF666666)),
        ),
      ],
    );
  }
}
