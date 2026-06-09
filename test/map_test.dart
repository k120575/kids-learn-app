import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learn_app/core/progress_store.dart';
import 'package:kids_learn_app/models/age_band.dart';
import 'package:kids_learn_app/screens/domain_select.dart';

void main() {
  testWidgets('探索地圖（遊樂園 / 太空）含動畫背景能正常建構繪製', (WidgetTester tester) async {
    await ProgressStore.instance.init();

    for (final AgeBand band in <AgeBand>[AgeBand.age3_4, AgeBand.age4_5]) {
      await tester.pumpWidget(MaterialApp(home: DomainSelectScreen(band: band)));
      await tester.pump(const Duration(milliseconds: 50)); // 跑一幀動畫繪製
      expect(tester.takeException(), isNull, reason: '$band 地圖繪製不應丟例外');
    }

    // 收掉動畫，避免測試結束殘留 ticker。
    await tester.pumpWidget(const SizedBox());
  });
}
