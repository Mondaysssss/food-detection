// [OOP] 面板：顯示目前食材清單（已偵測/已選擇），並提供新增/移除入口。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/recipes_data.dart';
import '../../state/app_state.dart';
import '../screens/ingredient_picker_page.dart';
import '../screens/recommend/recommend_screen.dart';
import 'glass.dart';
import 'ui_helpers.dart';

class FoodListPanel extends StatelessWidget {
  final AppState app;
  const FoodListPanel({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final canManualAdd = app.manualAddUnlocked;

    return glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleText('Food log'),
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
                    onDeleted: () => app.removeIngredient(i),
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
                    onPressed: !canManualAdd
                        ? null
                        : () async {
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
                              app.addIngredients(picked);
                            }
                          },
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ),

                if (!canManualAdd)
                  SizedBox(
                    width: btnW,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Detect ingredients first to unlock manual add.',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
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
                      onPressed: app.ingredients.isEmpty ? null : app.clearIngredients,
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