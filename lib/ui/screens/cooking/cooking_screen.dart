// [OOP] CookingScreen: single-dish entry page
// Now redirects to CookFlowScreen (single dish uses the same one-page UI)

import 'package:flutter/material.dart';
import 'package:flutter_application_1/domain/models/recipe.dart';
import 'package:flutter_application_1/ui/screens/cooking/cook_flow_screen.dart';

class CookingScreen extends StatelessWidget {
  final Recipe recipe;
  const CookingScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final totalMin = recipe.steps.fold<int>(0, (s, st) => s + st.durationMin);

    return CookFlowScreen(
      snapshot: {recipe.menuId: 1}, // ✅ Fixed: using menuId
      totalPlannedMinutes: totalMin,
      titleOverride: recipe.name,
    );
  }
}
