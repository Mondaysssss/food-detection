import 'package:flutter/material.dart';

import '../../data/ingredients_meta.dart';
import '../../data/recipe_meta.dart';
import '../../domain/models/match_result.dart';
import '../../domain/models/recipe.dart';
import 'ui_helpers.dart';

void showRecipeDetailSheet(BuildContext context, Recipe recipe, MatchResult mr) {
  final totalMin = recipe.steps.fold<int>(0, (s, st) => s + st.durationMin);
  final servings = kRecipeServings[recipe.menuId] ?? 2;
  final difficulty = kRecipeDifficulty[recipe.menuId] ?? 2;
  final method = kRecipeMethod[recipe.menuId] ?? '—';
  final selling = kSellingPoints[recipe.menuId] ?? ['Quick to table', 'Easy ingredients', 'Home-style flavor'];
  final verbose = kStepsVerbose[recipe.menuId] ?? recipe.steps.map((e) => e.text).toList();

  final mainIngr = <MapEntry<String, String>>[];
  final seasonings = <MapEntry<String, String>>[];

  for (final key in recipe.ingredientsRequired) {
    final qty = kQtyDefaults[key] ?? 'to taste';
    if (kSeasoningKeys.contains(key)) {
      seasonings.add(MapEntry(key, qty));
    } else {
      mainIngr.add(MapEntry(key, qty));
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    enableDrag: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (ctx) {
      final h = MediaQuery.of(ctx).size.height;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            constraints: BoxConstraints(maxHeight: h * 0.94),
            decoration: BoxDecoration(
              color: const Color(0xFF111318),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(recipe.cover, fit: BoxFit.cover),
                        ),
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Material(
                            color: Colors.black.withValues(alpha: .45),
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(ctx),
                              tooltip: 'Back',
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  recipe.name,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < difficulty ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final s in selling)
                                Chip(
                                  label: Text(s),
                                  backgroundColor: Colors.white12,
                                  side: const BorderSide(color: Colors.white24),
                                  labelStyle: const TextStyle(color: Colors.white),
                                ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              kvPill('Cuisine', recipe.type),
                              kvPill('Taste', recipe.taste.join(' / ')),
                              kvPill('Method', method),
                              kvPill('Difficulty', '$difficulty / 5'),
                              kvPill('Servings', '$servings servings'),
                              kvPill('Total time', '$totalMin min'),
                              kvPill('Completeness', '${mr.match.length}/${recipe.ingredientsRequired.length}'),
                            ],
                          ),

                          const SizedBox(height: 14),

                          sectionTitle('Main ingredients'),
                          const SizedBox(height: 6),
                          qtyList(mainIngr),

                          const SizedBox(height: 12),

                          sectionTitle('Seasoning'),
                          const SizedBox(height: 6),
                          qtyList(seasonings),

                          const SizedBox(height: 14),

                          sectionTitle('Detailed steps'),
                          const SizedBox(height: 6),
                          for (int i = 0; i < verbose.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text('${i + 1}. ${verbose[i]}'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}