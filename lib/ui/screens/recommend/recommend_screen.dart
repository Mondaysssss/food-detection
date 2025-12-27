// lib/ui/screens/recommend/recommend_screen.dart
// Recommend Screen（推薦頁）
// 用途：
// - 根據 AppState.ingredients（已偵測/已選食材）
// - 逐個 recipe 計算 match（主食材 match 數）
// - 顯示推薦結果（越多 match 越前）
// 註：調味料不計入主食材 match（用 kSeasoningKeys 過濾）

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recipe_meta.dart';
import '../../../data/recipes_data.dart';
import '../../../domain/services/matcher.dart';
import '../../../state/app_state.dart';
import '../../widgets/glass.dart';
import '../../widgets/recipe_card.dart';

class RecommendScreen extends StatelessWidget {
  const RecommendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final detected = app.ingredients;

    // 計分：只計主食材（非 seasoning）
    final scored = [
      for (final r in kAllRecipes)
        (recipe: r, mr: computeMatch(r, detected)),
    ]..sort((a, b) => b.mr.matchCount.compareTo(a.mr.matchCount));

    // 若冇任何食材，就提示用戶先偵測/揀食材
    if (detected.isEmpty) {
      return glass(
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No ingredients yet. Try AI Camera or Ingredient Picker first.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: scored.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final item = scored[i];

        // 額外：你想推薦只靠主食材？咁就再做一次過濾
        final mainMatch = item.recipe.ingredientsRequired.where((ing) => !kSeasoningKeys.contains(ing)).length;

        return RecipeCard(
          recipe: item.recipe,
          mr: item.mr.copyWith(totalRequiredMain: mainMatch),
        );
      },
    );
  }
}
