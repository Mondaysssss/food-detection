// [OOP] 購物車頁：顯示已加入的食譜與數量，彙總所需食材，並開始煮食流程。

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/ingredients_meta.dart';
import '../../data/recipes_data.dart';
import '../../domain/services/matcher.dart';
import '../../state/app_state.dart';
import '../widgets/page_frame.dart';
import '../widgets/glass.dart';
import '../widgets/ui_helpers.dart';
import '../widgets/recipe_card.dart';
import 'cooking/multi_cook_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cart = app.cart;
    final detected = app.ingredients;

    final entries = [
      for (final e in cart.entries)
        (
          recipe: kRecipeById[e.key]!,
          qty: e.value,
          mr: computeMatch(kRecipeById[e.key]!, detected),
        ),
    ];

    void onGeneratePressed() {
      final snapshot = Map<String, int>.from(app.cart);
      final totalDishes = snapshot.values.fold<int>(0, (s, v) => s + v);
      int totalMinutes = 0;

      final Set<String> mainAll = {};
      final Map<String, double> seasonTsp = {};

      snapshot.forEach((menuId, qty) {
        final r = kRecipeById[menuId]!;
        totalMinutes +=
            qty * r.steps.fold<int>(0, (s, st) => s + st.durationMin);

        for (final ing in r.ingredientIds) {
          if (kSeasoningKeys.contains(ing)) {
            final add = (kSeasoningTeaspoons[ing] ?? 1.0) * qty;
            seasonTsp[ing] = (seasonTsp[ing] ?? 0) + add;
          } else {
            mainAll.add(ing);
          }
        }
      });

      final have = app.ingredients.toSet();
      final mainGreen = [
        for (final m in mainAll)
          if (have.contains(m)) m,
      ]..sort();
      final mainRed = [
        for (final m in mainAll)
          if (!have.contains(m)) m,
      ]..sort();

      final seasonKeys = seasonTsp.keys.toList()..sort();
      final totalSeasonTsp = seasonTsp.values.fold<double>(0, (s, v) => s + v);

      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Cooking info'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  kvPill('Total menus', '$totalDishes dishes'),
                  const SizedBox(height: 4),
                  kvPill('Total time', '$totalMinutes min'),
                  const SizedBox(height: 4),
                  kvPill('Main ingredient types', '${mainAll.length}'),
                  const SizedBox(height: 4),
                  kvPill(
                    'Total seasoning',
                    '${totalSeasonTsp.toStringAsFixed(1)} tsp',
                  ),
                  const SizedBox(height: 12),

                  sectionTitle('Main ingredients'),
                  const SizedBox(height: 6),
                  if (mainGreen.isNotEmpty)
                    Text(
                      'Have: ${mainGreen.map(prettyName).join(', ')}',
                      style: const TextStyle(color: Colors.greenAccent),
                    ),
                  if (mainRed.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Missing: ${mainRed.map(prettyName).join(', ')}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  const SizedBox(height: 12),

                  sectionTitle('Seasoning (tsp)'),
                  const SizedBox(height: 6),
                  if (seasonKeys.isNotEmpty)
                    Text(
                      'Have: ' +
                          seasonKeys
                              .map(
                                (k) =>
                                    '${prettyName(k)} ${seasonTsp[k]!.toStringAsFixed(1)} tsp',
                              )
                              .join(', '),
                      style: const TextStyle(color: Colors.greenAccent),
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    '(Amounts are estimated)',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);

                  final snapshot = Map<String, int>.from(app.cart);
                  final int totalMinutesPlanned = snapshot.entries.fold(0, (
                    sum,
                    e,
                  ) {
                    final r = kRecipeById[e.key]!;
                    final per = r.steps.fold<int>(
                      0,
                      (s, st) => s + st.durationMin,
                    );
                    return sum + per * e.value;
                  });

                  context.read<AppState>().clearCart();
                  context.read<AppState>().clearIngredients();

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MultiCookScreen(
                        snapshot: snapshot,
                        totalPlannedMinutes: totalMinutesPlanned,
                      ),
                    ),
                  );
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Cart')),
      body: PageFrame(
        child: entries.isEmpty
            ? glass(
                child: const Text(
                  'No menu items added yet.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : LayoutBuilder(
                builder: (_, c) {
                  final w = c.maxWidth;
                  final cols = w >= 1200
                      ? 3
                      : w >= 800
                      ? 2
                      : 1;
                  const spacing = 12.0;
                  final tileW = (w - (cols - 1) * spacing) / cols;
                  final coverH = tileW * 9 / 16;
                  final baseInfoH = cols == 1
                      ? 230.0
                      : (cols == 2 ? 220.0 : 210.0);
                  final tileH = coverH + baseInfoH;

                  final grid = GridView.builder(
                    shrinkWrap: true,
                    primary: false,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      mainAxisExtent: tileH,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (_, i) => RecipeCard(
                      recipe: entries[i].recipe,
                      mr: entries[i].mr,
                      readOnly: true,
                      qtyForCart: entries[i].qty,
                    ),
                  );

                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(children: [grid]),
                  );
                },
              ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: app.cart.isEmpty ? null : onGeneratePressed,
          icon: const Icon(Icons.playlist_add_check),
          label: const Text('Start cooking'),
        ),
      ),
    );
  }
}
