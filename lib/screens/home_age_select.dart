import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/parent_gate.dart';
import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/big_card.dart';
import '../core/widgets/cloud_title.dart';
import '../core/widgets/home_background.dart';
import '../core/widgets/penguin.dart';
import '../models/age_band.dart';
import '../models/profile.dart';
import 'collection_screen.dart';
import 'domain_select.dart';
import 'gacha_screen.dart';
import 'profiles_screen.dart';
import 'settings_screen.dart';
import 'trophy_screen.dart';

/// 首頁：選擇年齡段，並可進入扭蛋機 / 收藏室 / 獎盃櫃。
class HomeAgeSelectScreen extends StatefulWidget {
  const HomeAgeSelectScreen({super.key});

  @override
  State<HomeAgeSelectScreen> createState() => _HomeAgeSelectScreenState();
}

class _HomeAgeSelectScreenState extends State<HomeAgeSelectScreen> {
  static const String _greeting = '嗨！我是企企，一起來玩吧！';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioService.instance.speak(_greeting);
      _showWelcomeBonus();
    });
  }

  /// 每日簽到獎勵：若 main() 的 dailyCheckIn 有發獎勵，這裡顯示一次。
  void _showWelcomeBonus() {
    final (int, int)? w = ProgressStore.instance.pendingWelcome;
    if (w == null || !mounted) return;
    ProgressStore.instance.pendingWelcome = null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF42A5F5),
        duration: const Duration(seconds: 4),
        content: Text(
          '🔥 連續 ${w.$2} 天！歡迎回來，送你 +${w.$1} ⭐',
          style: TextStyle(
            fontSize: context.s(18),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {}); // 回來刷新星星 / 收藏數
  }

  Future<void> _showProfileSwitcher() async {
    final ProgressStore store = ProgressStore.instance;
    await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(sheetContext.s(16)),
                child: Text(
                  '誰要玩呢？',
                  style: TextStyle(
                    fontSize: sheetContext.s(20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...store.profiles.map((Profile p) {
                final bool active = p.id == store.activeProfileId;
                return ListTile(
                  leading: Text(
                    p.emoji,
                    style: TextStyle(fontSize: sheetContext.s(30)),
                  ),
                  title: Text(
                    p.name,
                    style: TextStyle(fontSize: sheetContext.s(18)),
                  ),
                  trailing: active
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF4CAF50),
                        )
                      : null,
                  onTap: () async {
                    await store.switchProfile(p.id);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  },
                );
              }),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: Text(
                  '管理孩子檔案',
                  style: TextStyle(fontSize: sheetContext.s(16)),
                ),
                subtitle: const Text('新增／改名／刪除（需家長）'),
                onTap: () => Navigator.of(sheetContext).pop('manage'),
              ),
            ],
          ),
        );
      },
    ).then((String? result) async {
      if (result == 'manage' && mounted) {
        final bool ok = await showParentGate(context);
        if (ok && mounted) await _push(const ProfilesScreen());
      }
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ProgressStore store = ProgressStore.instance;
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: HomeBackground()),
          SafeArea(
            child: Stack(
              children: <Widget>[
                _buildMainColumn(store),
                // 左下角獎勵入口：相對螢幕大小定位 + 縮放（RWD，不寫死座標）
                Positioned(
                  left: MediaQuery.of(context).size.width * 0.03,
                  bottom: MediaQuery.of(context).size.height * 0.03,
                  child: _RewardDock(
                    scale: (MediaQuery.of(context).size.shortestSide / 400)
                        .clamp(0.85, 1.4),
                    onGacha: () => _push(const GachaScreen()),
                    onCollection: () => _push(const CollectionScreen()),
                    onTrophy: () => _push(const TrophyScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainColumn(ProgressStore store) {
    return Column(
      children: <Widget>[
        // 頂列：標題 + 連續天數 + 星星餘額 + 孩子 + 設定
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.s(12),
            vertical: context.s(8),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(width: context.s(4)),
              CloudTitle(fontSize: context.s(30)),
              const Spacer(),
              if (store.streakCurrent > 0) ...<Widget>[
                _Pill(
                  color: const Color(0xFFFFEBEE),
                  child: Text(
                    '🔥 ${store.streakCurrent}',
                    style: TextStyle(
                      fontSize: context.s(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: context.s(8)),
              ],
              _Pill(
                color: const Color(0xFFFFF8E1),
                child: Text(
                  '⭐ ${store.balance}',
                  style: TextStyle(
                    fontSize: context.s(16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: context.s(8)),
              // 孩子切換
              Material(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(26),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: _showProfileSwitcher,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.s(12),
                      vertical: context.s(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          store.activeProfile.emoji,
                          style: TextStyle(fontSize: context.s(22)),
                        ),
                        SizedBox(width: context.s(4)),
                        Text(
                          store.activeProfile.name,
                          style: TextStyle(
                            fontSize: context.s(15),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.expand_more_rounded, size: context.s(18)),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.s(8)),
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    final bool ok = await showParentGate(context);
                    if (ok && mounted) {
                      await _push(const SettingsScreen());
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.all(context.s(10)),
                    child: Icon(
                      Icons.settings_rounded,
                      size: context.s(26),
                      color: const Color(0xFF90A4AE),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: context.s(Sizes.gap)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildMascot(context),
                  SizedBox(height: context.s(Sizes.gap)),
                  _buildAgeChooser(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 吉祥物企企（點一下會說話）：對話框 + 企鵝。
  Widget _buildMascot(BuildContext context) {
    return GestureDetector(
      onTap: () => AudioService.instance.speak(_greeting),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.s(18),
              vertical: context.s(10),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _greeting,
              style: TextStyle(
                fontSize: context.s(17),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: context.s(4)),
          Penguin(size: context.s(72)),
        ],
      ),
    );
  }

  /// 「我幾歲呢？」+ 年齡段卡片。
  Widget _buildAgeChooser(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '我幾歲呢？',
          style: TextStyle(
            fontSize: context.s(24),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: context.s(Sizes.gap)),
        Wrap(
          spacing: context.s(Sizes.bigGap),
          runSpacing: context.s(Sizes.bigGap),
          alignment: WrapAlignment.center,
          children: AgeBand.values.map((AgeBand band) {
            return BigCard(
              emoji: band.emoji,
              // 卡片尺寸隨裝置縮放（原本寫死 160，手機放不下 3 張）。
              size: context.s(108),
              label: band.enabled ? band.label : '即將推出',
              color: const Color(0xFF4DD0E1),
              solid: true, // 實心白底卡片，在背景上更跳、更好按
              dimmed: !band.enabled,
              onTap: () {
                if (!band.enabled) {
                  AudioService.instance.speak('這個還在準備中喔');
                  return;
                }
                AudioService.instance.speak(band.label);
                _push(DomainSelectScreen(band: band));
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.s(12),
        vertical: context.s(8),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
      ),
      child: child,
    );
  }
}

/// 左下角獎勵入口群組：縱向排列三顆縮小的按鈕，整體依 [scale] 放大縮小。
class _RewardDock extends StatelessWidget {
  const _RewardDock({
    required this.scale,
    required this.onGacha,
    required this.onCollection,
    required this.onTrophy,
  });

  final double scale;
  final VoidCallback onGacha;
  final VoidCallback onCollection;
  final VoidCallback onTrophy;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SmallRewardButton(
          emoji: '🎰',
          label: '扭蛋機',
          color: const Color(0xFFFF7043),
          scale: scale,
          onTap: onGacha,
        ),
        SizedBox(height: 8 * scale),
        _SmallRewardButton(
          emoji: '🧸',
          label: '收藏室',
          color: const Color(0xFF42A5F5),
          scale: scale,
          onTap: onCollection,
        ),
        SizedBox(height: 8 * scale),
        _SmallRewardButton(
          emoji: '🏆',
          label: '獎盃櫃',
          color: const Color(0xFFFFB300),
          scale: scale,
          onTap: onTrophy,
        ),
      ],
    );
  }
}

class _SmallRewardButton extends StatelessWidget {
  const _SmallRewardButton({
    required this.emoji,
    required this.label,
    required this.color,
    required this.scale,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final Color color;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double radius = 16 * scale;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      elevation: 3,
      shadowColor: color.withValues(alpha: 0.45),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12 * scale,
            vertical: 7 * scale,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: color, width: 2.5 * scale),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(emoji, style: TextStyle(fontSize: 22 * scale)),
              SizedBox(width: 6 * scale),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
