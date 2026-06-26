import 'package:flutter/material.dart';

import '../content/access_policy.dart';
import '../core/audio_service.dart';
import '../core/entitlement_service.dart';
import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/game_scaffold.dart';
import 'dashboard_screen.dart';
import 'paywall_screen.dart';
import 'profiles_screen.dart';

/// 設定頁（由家長鎖進入）：音效、螢幕時間提醒、總星數、清除進度。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ProgressStore _store = ProgressStore.instance;

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: '設定',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: EdgeInsets.all(context.s(Sizes.bigGap)),
            children: <Widget>[
              // 付費鎖關閉（v1.0 免費）時不顯示升級/還原卡。
              if (kPaywallEnabled) ...<Widget>[
                _buildUnlockCard(context),
                SizedBox(height: context.s(Sizes.gap)),
              ],
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.star_rounded,
                    color: const Color(0xFFFFC107),
                    size: context.s(32),
                  ),
                  title: Text(
                    '累積星星',
                    style: TextStyle(fontSize: context.s(20)),
                  ),
                  trailing: Text(
                    '${_store.totalStars()} ⭐',
                    style: TextStyle(
                      fontSize: context.s(22),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: context.s(Sizes.gap)),
              Card(
                child: SwitchListTile(
                  secondary: Icon(Icons.volume_up_rounded, size: context.s(32)),
                  title: Text(
                    '聲音（語音／音效）',
                    style: TextStyle(fontSize: context.s(20)),
                  ),
                  value: _store.soundEnabled,
                  onChanged: (bool v) =>
                      setState(() => _store.soundEnabled = v),
                ),
              ),
              SizedBox(height: context.s(Sizes.gap)),
              Card(
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      secondary: Icon(
                        Icons.music_note_rounded,
                        size: context.s(32),
                      ),
                      title: Text(
                        '背景音樂',
                        style: TextStyle(fontSize: context.s(20)),
                      ),
                      value: _store.musicEnabled,
                      onChanged: (bool v) {
                        setState(() => _store.musicEnabled = v);
                        AudioService.instance.applyMusicSetting();
                      },
                    ),
                    if (_store.musicEnabled)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.s(16),
                          context.s(0),
                          context.s(16),
                          context.s(12),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.volume_down_rounded,
                              color: Color(0xFF90A4AE),
                            ),
                            Expanded(
                              child: Slider(
                                value: _store.musicVolume,
                                divisions: 10,
                                label: '${(_store.musicVolume * 100).round()}%',
                                onChanged: (double v) {
                                  setState(() => _store.musicVolume = v);
                                  AudioService.instance.applyMusicSetting();
                                },
                              ),
                            ),
                            const Icon(
                              Icons.volume_up_rounded,
                              color: Color(0xFF90A4AE),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: context.s(Sizes.gap)),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.insights_rounded,
                    size: context.s(32),
                    color: const Color(0xFF42A5F5),
                  ),
                  title: Text(
                    '學習報告',
                    style: TextStyle(fontSize: context.s(20)),
                  ),
                  subtitle: const Text('使用時間、各遊戲表現與常錯處'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DashboardScreen(),
                    ),
                  ),
                ),
              ),
              SizedBox(height: context.s(Sizes.gap)),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.people_rounded,
                    size: context.s(32),
                    color: const Color(0xFF66BB6A),
                  ),
                  title: Text(
                    '孩子檔案',
                    style: TextStyle(fontSize: context.s(20)),
                  ),
                  subtitle: Text(
                    '目前：${_store.activeProfile.emoji} '
                    '${_store.activeProfile.name}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfilesScreen(),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),
              ),
              SizedBox(height: context.s(Sizes.gap)),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(context.s(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.timer_rounded, size: context.s(32)),
                          SizedBox(width: context.s(12)),
                          Expanded(
                            child: Text(
                              '休息提醒（分鐘）',
                              style: TextStyle(fontSize: context.s(20)),
                            ),
                          ),
                          Text(
                            _store.screenTimeMinutes == 0
                                ? '關閉'
                                : '${_store.screenTimeMinutes} 分',
                            style: TextStyle(
                              fontSize: context.s(20),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _store.screenTimeMinutes.toDouble(),
                        min: 0,
                        max: 40,
                        divisions: 8,
                        label: _store.screenTimeMinutes == 0
                            ? '關閉'
                            : '${_store.screenTimeMinutes} 分',
                        onChanged: (double v) => setState(
                          () => _store.screenTimeMinutes = v.round(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: context.s(Sizes.bigGap)),
              OutlinedButton.icon(
                onPressed: _confirmClear,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(context.s(60)),
                  foregroundColor: Colors.red,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(
                  '清除所有進度',
                  style: TextStyle(fontSize: context.s(18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 完整版狀態卡：未解鎖→升級（設定頁已在家長鎖後，直接進付費牆）；已解鎖→顯示 + 還原。
  Widget _buildUnlockCard(BuildContext context) {
    final bool unlocked = EntitlementService.instance.isFullUnlocked;
    if (unlocked) {
      return Card(
        color: const Color(0xFFFFF8E1),
        child: ListTile(
          leading: Icon(
            Icons.verified_rounded,
            color: const Color(0xFFFFB300),
            size: context.s(32),
          ),
          title: Text('完整版已解鎖', style: TextStyle(fontSize: context.s(20))),
          subtitle: const Text('謝謝你的支持 💛'),
          trailing: TextButton(
            onPressed: _restore,
            child: const Text('還原購買'),
          ),
        ),
      );
    }
    return Card(
      color: const Color(0xFFFFF8E1),
      child: ListTile(
        leading: Icon(
          Icons.lock_open_rounded,
          color: const Color(0xFFFFB300),
          size: context.s(32),
        ),
        title: Text('升級完整版', style: TextStyle(fontSize: context.s(20))),
        subtitle: const Text('解鎖全部關卡與完整學習報告'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
          );
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _restore() async {
    final bool ok = await EntitlementService.instance.restore();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(ok ? '已還原你的購買 ✅' : '目前沒有可還原的購買')),
      );
  }

  Future<void> _confirmClear() async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('清除所有進度？'),
        content: const Text('星星紀錄會全部歸零，無法復原。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('確定清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (yes ?? false) {
      await _store.clearProgress();
      if (mounted) setState(() {});
    }
  }
}
