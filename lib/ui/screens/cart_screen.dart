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

    final userAllergies = app.allergies;

    final entries = [
      for (final e in cart.entries)
        (
          recipe: kRecipeById[e.key]!,
          qty: e.value,
          mr: computeMatch(kRecipeById[e.key]!, detected),
          allergyHits: [
            for (final allergy in userAllergies)
              if (kRecipeById[e.key]!.ingredientIds.any(
                (id) => (allergyIngredientMap[allergy] ?? []).contains(id),
              ))
                allergy,
          ],
        ),
    ];

    void onGeneratePressed() {
      final snapshot = Map<String, int>.from(app.cart);
      final totalDishes = snapshot.values.fold<int>(0, (s, v) => s + v);
      int totalMinutes = 0;
      final Set<String> mainAll = {};
      final Map<String, double> mainQtyValue = {};
      final Map<String, String> mainQtyUnit = {};
      final Map<String, String> mainQtyFallback = {};
      final Map<String, double> seasonTsp = {};

      final userAllergies = app.allergies;
      final allergyWarnings = <String, List<String>>{};

      double? _parseQty(String raw) {
        final s = raw.trim();
        if (s.isEmpty) return null;

        if (s.contains('/')) {
          final parts = s.split('/');
          if (parts.length == 2) {
            final a = double.tryParse(parts[0].trim());
            final b = double.tryParse(parts[1].trim());
            if (a != null && b != null && b != 0) {
              return a / b;
            }
          }
        }

        return double.tryParse(s);
      }

      String _formatQty(double value) {
        if (value % 1 == 0) return value.toInt().toString();
        return value
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
      }

      String _mainQtyText(String ingredientId) {
        final value = mainQtyValue[ingredientId];
        if (value != null) {
          final unit = mainQtyUnit[ingredientId] ?? '';
          final qtyText = _formatQty(value);
          return unit.isEmpty ? qtyText : '$qtyText $unit';
        }
        return mainQtyFallback[ingredientId] ?? '';
      }

      snapshot.forEach((menuId, qty) {
        final r = kRecipeById[menuId]!;

        // Same recipe counts once only for total time.
        totalMinutes += r.steps.fold<int>(0, (s, st) => s + st.durationMin);

        for (final ri in r.recipeIngredients) {
          final ing = ri.ingredientId;

          if (kSeasoningKeys.contains(ing)) {
            final add = (kSeasoningTeaspoons[ing] ?? 1.0) * qty;
            seasonTsp[ing] = (seasonTsp[ing] ?? 0) + add;
          } else {
            mainAll.add(ing);

            final parsed = _parseQty(ri.quantity);
            if (parsed != null) {
              mainQtyValue[ing] = (mainQtyValue[ing] ?? 0) + (parsed * qty);
              mainQtyUnit.putIfAbsent(ing, () => ri.unit);
            } else {
              final display = ri.display.trim().isEmpty ? 'to taste' : ri.display.trim();
              mainQtyFallback.putIfAbsent(ing, () => display);
            }
          }
        }

        final blockedIngredientNames = <String>{};

        for (final allergy in userAllergies) {
          final blockedIngredients = allergyIngredientMap[allergy] ?? [];
          for (final id in r.ingredientIds) {
            if (blockedIngredients.contains(id)) {
              blockedIngredientNames.add(prettyName(id));
            }
          }
        }

        if (blockedIngredientNames.isNotEmpty) {
          final sorted = blockedIngredientNames.toList()..sort();
          allergyWarnings[r.name] = sorted;
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

      void proceedToCooking() {
        final snapshot = Map<String, int>.from(app.cart);
        final int totalMinutesPlanned = snapshot.entries.fold(0, (sum, e) {
          final r = kRecipeById[e.key]!;
          final per = r.steps.fold<int>(
            0,
            (s, st) => s + st.durationMin,
          );
          return sum + per;
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
      }

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
                      'Have: ' +
                          mainGreen
                              .map((k) {
                                final qtyText = _mainQtyText(k);
                                return qtyText.isEmpty ? prettyName(k) : '${prettyName(k)} $qtyText';
                              })
                              .join(', '),
                      style: const TextStyle(color: Colors.greenAccent),
                    ),
                  if (mainRed.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Missing: ' +
                            mainRed
                                .map((k) {
                                  final qtyText = _mainQtyText(k);
                                  return qtyText.isEmpty ? prettyName(k) : '${prettyName(k)} $qtyText';
                                })
                                .join(', '),
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

                  if (allergyWarnings.isEmpty) {
                    proceedToCooking();
                    return;
                  }

                  showDialog(
                    context: context,
                    builder: (warnCtx) {
                      final warningEntries = allergyWarnings.entries.toList();

                      return AlertDialog(
                        title: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.redAccent,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Allergy warning',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        content: SingleChildScrollView(
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(color: Colors.white),
                              children: [
                                const TextSpan(
                                  text:
                                      'These recipes contain ingredients related to your food allergies:\n\n',
                                ),
                                for (int i = 0; i < warningEntries.length; i++) ...[
                                  TextSpan(
                                    text: warningEntries[i].key,
                                    style: const TextStyle(
                                      color: Color(0xFFFFB4B4),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const TextSpan(text: ': '),
                                  for (int j = 0; j < warningEntries[i].value.length; j++) ...[
                                    TextSpan(
                                      text: warningEntries[i].value[j],
                                      style: const TextStyle(
                                        color: Color(0xFFFFB4B4),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (j < warningEntries[i].value.length - 1)
                                      const TextSpan(text: ', '),
                                  ],
                                  const TextSpan(text: '\n'),
                                ],
                                const TextSpan(
                                  text:
                                      '\nAre you sure you want to continue?',
                                ),
                              ],
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(warnCtx),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(warnCtx);
                              proceedToCooking();
                            },
                            child: const Text('Continue'),
                          ),
                        ],
                      );
                    },
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
                  final recipesSection = cols == 1
                      ? Column(
                          children: [
                            for (int i = 0; i < entries.length; i++) ...[
                              RecipeCard(
                                recipe: entries[i].recipe,
                                mr: entries[i].mr,
                                allergyHits: entries[i].allergyHits,
                                readOnly: true,
                                qtyForCart: entries[i].qty,
                              ),
                              if (i < entries.length - 1)
                                const SizedBox(height: spacing),
                            ],
                          ],
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          primary: false,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            mainAxisExtent: w >= 800 && w < 1200 ? 430.0 : 400.0,
                          ),
                          itemCount: entries.length,
                          itemBuilder: (_, i) => RecipeCard(
                            recipe: entries[i].recipe,
                            mr: entries[i].mr,
                            allergyHits: entries[i].allergyHits,
                            readOnly: true,
                            qtyForCart: entries[i].qty,
                            showQtyControls: true,
                          ),
                        );

                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(children: [recipesSection]),
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
