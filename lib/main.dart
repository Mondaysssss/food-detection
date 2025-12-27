// lib/main.dart
// App 入口點：建立 Provider(AppState) 並啟動 MyApp（MaterialApp + Theme + 初始頁）
//
// 你之後加任何全域狀態（例如：登入資料、使用者偏好）都可以擺入 AppState，
// 然後 UI 用 Provider/Selector 去讀取。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'app/my_app.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MyApp(),
    ),
  );
}