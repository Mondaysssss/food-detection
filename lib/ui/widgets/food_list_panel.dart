// lib/ui/widgets/food_list_panel.dart
// ✅ FoodListPanel：AI Camera 頁底部「Food Log + Add/Menu/Clear」面板
// 功能：
// - 顯示目前 ingredients（chip + 可刪除）
// - Add：進 IngredientPickerPage 全螢幕多選
// - Menu Suggestions：入 RecommendScreen
// - Clear：清空 ingredients

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/recipes_data.dart';
import '../../state/app_state.dart';
import '../screens/ingredient_picker_page.dart';
import '../screens/recommend/recommend_screen.dart';
import 'glass.dart';
import 'ui_helpers.dart';

class FoodListPanel extends StatelessWidget {
  const FoodListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleText('Food log'),
          const Text(
            'Names only (no quantity). Duplicates removed automatically.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 10),

          if (app.ingredients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No records yet', style: TextStyle(color: Colors.white70)),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final i in app.ingredients)
                  Chip(
                    backgroundColor: Colors.white12,
                    side: const BorderSide(color: Colors.white24),
                    label: Text(i),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => context.read<AppState>().removeIngredient(i),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
              ],
            ),

          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              double btnW;
              if (w < 340) {
                btnW = w;
              } else if (w < 520) {
                btnW = (w - 8) / 2;
              } else {
                btnW = (w - 16) / 3;
              }

              ButtonStyle styleFor(bool filled) => (filled ? FilledButton.styleFrom : ElevatedButton.styleFrom)(
                minimumSize: Size(btnW, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              );

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: btnW,
                    child: ElevatedButton.icon(
                      style: styleFor(false),
                      onPressed: () async {
                        final picked = await Navigator.push<List<String>>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IngredientPickerPage(
                              all: kAllIngredients,
                              existing: app.ingredients.toSet(),
                            ),
                          ),
                        );
                        if (picked != null && picked.isNotEmpty) {
                          context.read<AppState>().addIngredients(picked);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ),

                  SizedBox(
                    width: btnW,
                    child: FilledButton.icon(
                      style: styleFor(true),
                      onPressed: app.ingredients.isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RecommendScreen()),
                              );
                            },
                      icon: const Icon(Icons.check),
                      label: const Text('Menu suggestions'),
                    ),
                  ),

                  SizedBox(
                    width: btnW,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: Size(btnW, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        backgroundColor: Colors.red.shade200.withValues(alpha: 0.2),
                      ),
                      onPressed: app.ingredients.isEmpty ? null : () => context.read<AppState>().clearIngredients(),
                      icon: const Icon(Icons.delete),
                      label: const Text('Clear'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}