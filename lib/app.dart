import 'package:flutter/material.dart';

import 'core/nav.dart';
import 'core/theme.dart';
import 'screens/home_age_select.dart';

class KidsLearnApp extends StatelessWidget {
  const KidsLearnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '寶貝學習樂園',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: buildTheme(),
      // 系統字型放大最多吃到 1.3x：UI 已用 context.s 依螢幕縮放，
      // 更大的字型倍率會把固定尺寸卡片內的文字撐爆（溢繪/破版）。
      builder: (BuildContext context, Widget? child) =>
          MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.0,
            maxScaleFactor: 1.3,
            child: child!,
          ),
      home: const HomeAgeSelectScreen(),
    );
  }
}
