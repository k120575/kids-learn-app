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
      home: const HomeAgeSelectScreen(),
    );
  }
}
