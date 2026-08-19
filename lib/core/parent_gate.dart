import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'responsive.dart';
import 'theme.dart';

/// 家長鎖：用一題「兩位數 × 個位數」乘法擋住設定/離開/付費入口。
/// 刻意比 App 內的數學遊戲（20 以內加減）更難，連 5-6 歲也算不出來，
/// 家長卻能一眼答對。回傳 true 表示通過。
///
/// 答案用「鍵盤輸入」而非選擇題：Google Families 對 parental gate 的要求是
/// 「不能靠亂猜通過」——4 選 1 亂點有 25% 機率過，輸入式沒有這個問題。
/// 答錯會換一題重出（不鎖死，家長按錯鍵也能再試）。
Future<bool> showParentGate(BuildContext context) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) => const _ParentGateDialog(),
  );
  return ok ?? false;
}

class _ParentGateDialog extends StatefulWidget {
  const _ParentGateDialog();

  @override
  State<_ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<_ParentGateDialog> {
  final Random _rng = Random();
  final TextEditingController _input = TextEditingController();
  late int _a;
  late int _b;
  bool _wrong = false; // 剛答錯（顯示「再試一次」並已換題）

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _newQuestion() {
    _a = 11 + _rng.nextInt(9); // 11~19
    _b = 3 + _rng.nextInt(7); // 3~9
    _input.clear();
  }

  void _submit() {
    final int? v = int.tryParse(_input.text.trim());
    if (v == _a * _b) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _wrong = true;
        _newQuestion(); // 答錯換一題，不能背答案重試
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true, // 矮螢幕 + 系統字型放大時不撐爆
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.radius),
      ),
      title: const Text('請家長作答 👨‍👩‍👧'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _wrong ? '答錯了，換一題再試一次' : '小朋友請找爸爸媽媽幫忙',
            style: TextStyle(
              fontSize: context.s(15),
              color: _wrong ? const Color(0xFFE53935) : const Color(0xFF888888),
            ),
          ),
          SizedBox(height: context.s(8)),
          Text(
            '$_a × $_b = ?',
            style: TextStyle(
              fontSize: context.s(40),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.s(Sizes.gap)),
          SizedBox(
            width: context.s(150),
            child: TextField(
              controller: _input,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: context.s(28),
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: '答案',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('確定'),
        ),
      ],
    );
  }
}
