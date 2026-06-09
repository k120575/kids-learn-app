import 'package:flutter/material.dart';

/// 全域導覽鍵：讓非 UI 層（如休息提醒）也能跳出對話框、回到首頁。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
