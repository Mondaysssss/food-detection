// lib/app/my_app.dart
//  App 最外層 MaterialApp：設定 Theme / Title / 初始頁（IntroStartScreen）
// 你之後要加 route table / i18n / deep link，都係由呢個檔開始擴展。

import 'package:flutter/material.dart';

import '../ui/screens/intro_start_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF22C55E);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FoodLens',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      home: const IntroStartScreen(),
    );
  }
}