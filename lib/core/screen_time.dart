import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio_service.dart';
import 'nav.dart';
import 'progress_store.dart';
import 'responsive.dart';
import 'theme.dart';
import 'widgets/penguin.dart';

/// 螢幕時間管理：
/// 1. 只在 App 於前景時累計「實際使用時間」，週期性寫進每日紀錄（家長報告用）。
/// 2. 累計達到家長設定的「休息提醒（分鐘）」時，跳出企企的溫和休息提醒。
///
/// 設定值 0 = 關閉提醒（但仍會累計時間供報告）。
class ScreenTimeManager with WidgetsBindingObserver {
  ScreenTimeManager._();
  static final ScreenTimeManager instance = ScreenTimeManager._();

  static const int _tick = 5; // 每 5 秒一拍
  static const int _flushEvery = 30; // 每 30 秒寫一次每日時間

  Timer? _timer;
  bool _foreground = true;
  bool _showingReminder = false;
  int _sinceBreak = 0; // 距上次休息的秒數
  int _buffer = 0; // 尚未寫入 DB 的秒數

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _timer ??= Timer.periodic(const Duration(seconds: _tick), (_) => _onTick());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _flush(); // 切到背景先把累計寫入
  }

  void _onTick() {
    if (!_foreground || _showingReminder) return;
    _sinceBreak += _tick;
    _buffer += _tick;
    if (_buffer >= _flushEvery) _flush();

    final int limit = ProgressStore.instance.screenTimeMinutes * 60;
    if (limit > 0 && _sinceBreak >= limit) {
      _showReminder();
    }
  }

  void _flush() {
    if (_buffer <= 0) return;
    final int s = _buffer;
    _buffer = 0;
    ProgressStore.instance.addActiveSeconds(s);
  }

  Future<void> _showReminder() async {
    final NavigatorState? nav = rootNavigatorKey.currentState;
    final BuildContext? ctx = nav?.context;
    if (nav == null || ctx == null) return;
    _showingReminder = true;
    _flush();

    final int minutes = ProgressStore.instance.screenTimeMinutes;
    AudioService.instance.speak('我們玩好久囉，休息一下吧！');

    final bool? rest = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext c) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sizes.radius),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Penguin(size: c.s(84)),
              SizedBox(height: c.s(10)),
              Text(
                '休息一下吧！',
                style: TextStyle(
                  fontSize: c.s(24),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: c.s(8)),
              Text(
                '我們已經玩了 $minutes 分鐘了，\n讓眼睛休息一下，動一動身體好嗎？',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: c.s(18), height: 1.4),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            ElevatedButton.icon(
              onPressed: () => Navigator.of(c).pop(true),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(c.s(160), c.s(56)),
                textStyle: TextStyle(fontSize: c.s(18)),
              ),
              icon: const Icon(Icons.bedtime_rounded),
              label: const Text('好，結束休息'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(c).pop(false),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(c.s(120), c.s(56)),
                textStyle: TextStyle(fontSize: c.s(16)),
              ),
              child: const Text('再玩一下下'),
            ),
          ],
        );
      },
    );

    _sinceBreak = 0; // 不論選擇，都重新計時
    _showingReminder = false;
    if (rest ?? true) {
      // 真的結束：關閉 App，幫助孩子停下來（不是只回首頁還能繼續玩）。
      AudioService.instance.stop();
      await SystemNavigator.pop();
    }
  }
}
