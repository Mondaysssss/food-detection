// [OOP] CookingScreen：單菜入口頁
// 現在改做「轉去 CookFlowScreen」(單菜都用同一個一頁式 UI)

import 'package:flutter/material.dart';

import '../../../domain/models/recipe.dart';
import 'cook_flow_screen.dart';

class CookingScreen extends StatelessWidget {
  final Recipe recipe;

  const CookingScreen({
    super.key,
    required this.recipe,
  });

  @override
  Widget build(BuildContext context) {
    final totalMinutesPlanned = recipe.steps.fold<int>(0, (s, st) => s + st.durationMin);

    return CookFlowScreen(
      snapshot: {recipe.menuId: 1},
      totalPlannedMinutes: totalMinutesPlanned,
      singleRecipeTitle: recipe.name,
    );
  }
}
