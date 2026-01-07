// [OOP] CookingScreen：
// 舊版係「單菜步驟 + 單 timer」UI。
// 依家改為：直接委派到 CookFlowScreen（單頁完成：icon + step + 右邊菜單 + bottom sheet）。

import 'package:flutter/material.dart';

import 'cook_flow_screen.dart';

/// 單菜版本：轉去共用 CookFlowScreen
class CookingScreen extends StatelessWidget {
  final String menuId;

  const CookingScreen({super.key, required this.menuId});

  @override
  Widget build(BuildContext context) {
    return CookFlowScreen(
      snapshot: {menuId: 1},
      totalPlannedMinutes: 0,
    );
  }
}
