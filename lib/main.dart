import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/audio_service.dart';
import 'core/progress_store.dart';
import 'core/screen_time.dart';

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
  await AudioService.instance.init();
  ScreenTimeManager.instance.start();

  runApp(const KidsLearnApp());
}
