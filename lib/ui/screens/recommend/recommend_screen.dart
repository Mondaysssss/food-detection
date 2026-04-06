// [OOP] 推薦清單：根據目前食材與偏好計算匹配，顯示可煮食譜。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/ingredients_meta.dart';
import '../../../data/recipes_data.dart';
import '../../../state/app_state.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/glass.dart';
import '../../widgets/ui_helpers.dart';
import '../cart_screen.dart';
import 'recommend_page.dart';

class RecommendScreen extends StatelessWidget {
  const RecommendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ingredients = app.ingredients;

    final usedIngredients = <String>{};
    app.cart.forEach((menuId, qty) {
      if (qty > 0) {
        final r = kRecipeById[menuId];
        if (r != null) {
          for (final ing in r.ingredientIds) {
            if (!kSeasoningKeys.contains(ing)) usedIngredients.add(ing);
          }
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Menu suggestions'),
      ),
      body: PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleText('Current ingredients (${ingredients.length})'),
                      if (ingredients.isEmpty)
                        const Text(
                          'No ingredients added yet. Please go back to add or detect.',
                          style: TextStyle(color: Colors.white70),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final i in ingredients)
                              Chip(
                                label: Text(
                                  i,
                                  style: TextStyle(
                                    color: usedIngredients.contains(i)
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: usedIngredients.contains(i)
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.red.withValues(alpha: 0.15),
                                side: BorderSide(
                                  color: usedIngredients.contains(i)
                                      ? Colors.green.withValues(alpha: 0.4)
                                      : Colors.red.withValues(alpha: 0.4),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Expanded(child: RecommendPage()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartScreen()),
          );
        },
        child: const Icon(Icons.shopping_cart),
      ),
    );
  }
}
