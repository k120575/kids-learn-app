import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/audio_service.dart';
import 'core/entitlement_service.dart';
import 'core/progress_store.dart';
import 'core/drive_cloud_gateway.dart';
import 'core/screen_time.dart';
import 'core/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 平板橫向鎖定 + 沉浸式全螢幕（幼兒不易誤觸系統列）
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await ProgressStore.instance.init();
  await ProgressStore.instance.dailyCheckIn(); // 連續天數 + 每日獎勵星星
  await EntitlementService.instance.init(); // 付費解鎖：讀快取 + 與商店對帳（失敗不阻擋）
  // 跨裝置同步：旗標開時接上真實 Drive 閘道（否則維持骨架，不連網）。
  if (kSyncFeatureEnabled) {
    SyncService.useGateway(DriveCloudGateway());
  }
  await SyncService.instance.init(); // 載入設定 + device_id
  if (kSyncFeatureEnabled && SyncService.instance.enabled) {
    // 背景拉取，不阻擋進首頁（失敗靜默降級為純本機）。
    unawaited(SyncService.instance.syncNow());
  }
  await AudioService.instance.init();
  ScreenTimeManager.instance.start();

  runApp(const KidsLearnApp());
}
