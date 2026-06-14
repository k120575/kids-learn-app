import 'dart:math';

import 'package:flutter/material.dart';

import 'responsive.dart';
import 'theme.dart';

/// 家長鎖：用一題「兩位數 × 個位數」乘法擋住設定/離開。
/// 刻意比 App 內的數學遊戲（20 以內加減）更難，連 5-6 歲也算不出來，
/// 家長卻能一眼答對。回傳 true 表示通過。
Future<bool> showParentGate(BuildContext context) async {
  final Random rng = Random();
  final int a = 11 + rng.nextInt(9); // 11~19
  final int b = 3 + rng.nextInt(7); // 3~9
  final int answer = a * b;

  // 產生 4 個選項（含正解），干擾項貼近正解但不重複。
  final Set<int> opts = <int>{answer};
  while (opts.length < 4) {
    final int d =
        answer + (rng.nextInt(2) == 0 ? -1 : 1) * (1 + rng.nextInt(9));
    if (d > 0) opts.add(d);
  }
  final List<int> options = opts.toList()..shuffle(rng);

  final bool? ok = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sizes.radius),
        ),
        title: const Text('請家長作答 👨‍👩‍👧'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '小朋友請找爸爸媽媽幫忙',
              style: TextStyle(
                fontSize: context.s(15),
                color: const Color(0xFF888888),
              ),
            ),
            SizedBox(height: context.s(8)),
            Text(
              '$a × $b = ?',
              style: TextStyle(
                fontSize: context.s(40),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.s(Sizes.gap)),
            Wrap(
              spacing: context.s(Sizes.gap),
              runSpacing: context.s(Sizes.gap),
              alignment: WrapAlignment.center,
              children: options.map((int o) {
                return ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(o == answer),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(context.s(72), context.s(64)),
                    textStyle: TextStyle(fontSize: context.s(26)),
                  ),
                  child: Text('$o'),
                );
              }).toList(),
            ),
          ],
        ),
      );
    },
  );
  return ok ?? false;
}
