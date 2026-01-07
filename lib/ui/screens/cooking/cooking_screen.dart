// [OOP] CookingScreen：
// 舊版係「單菜步驟 + 單 timer」UI。
// 依家改為：直接委派到 CookFlowScreen（單頁完成：icon + step + 右邊菜單 + bottom sheet）。

import 'package:flutter/material.dart';

import '../../../domain/models/recipe.dart';
import 'cook_flow_screen.dart';

class CookingScreen extends StatelessWidget {
  final Recipe recipe;

  const CookingScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final totalMin = recipe.steps.fold<int>(0, (s, st) => s + st.durationMin);
    return CookFlowScreen(
      snapshot: {recipe.id: 1},
      totalPlannedMinutes: totalMin,
      titleOverride: recipe.name,
    );
  }
}
