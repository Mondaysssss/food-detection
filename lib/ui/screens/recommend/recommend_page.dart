// [OOP] 推薦頁容器：包裝 RecommendScreen，處理頁面結構/滾動。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recipes_data.dart';
import '../../../domain/services/matcher.dart';
import '../../../state/app_state.dart';
import '../../widgets/glass.dart';
import '../../widgets/ui_helpers.dart';
import '../../widgets/recipe_card.dart';

class RecommendPage extends StatefulWidget {
  const RecommendPage({super.key});

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  String typeFilter = 'All';
  String tasteFilter = 'All';
  String search = '';
  bool onlyFav = false;
  bool showAllergyRecipes = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final detected = app.ingredients;
    final userAppliances = app.appliances;
    final userAllergies = app.allergies;

    final list = kRecipes.map((r) {
      final allergyHits = <String>[];

      for (final allergy in userAllergies) {
        final blockedIngredients = allergyIngredientMap[allergy] ?? [];
        final hasBlockedIngredient = r.ingredientIds.any(
          (id) => blockedIngredients.contains(id),
        );
        if (hasBlockedIngredient) {
          allergyHits.add(allergy);
        }
      }

      return (
        recipe: r,
        mr: computeMatch(r, detected),
        allergyHits: allergyHits,
      );
    }).toList()
      ..sort((a, b) {
        final cmp = b.mr.match.length.compareTo(a.mr.match.length);
        if (cmp != 0) return cmp;
        return a.mr.missing.length.compareTo(b.mr.missing.length);
      });

    final types = [
      'All',
      ...{for (final r in kRecipes) r.type},
    ];
    final tastes = [
      'All',
      ...{for (final r in kRecipes) ...r.taste},
    ];
    final favSet = context.watch<AppState>().favorites;

    final filtered = list.where((e) {
      if (typeFilter != 'All' && e.recipe.type != typeFilter) return false;
      if (tasteFilter != 'All' &&
          !e.recipe.taste.any((t) => t.contains(tasteFilter)))
        return false;

      if (search.trim().isNotEmpty) {
        final s = search.toLowerCase();
        if (!e.recipe.name.toLowerCase().contains(s) &&
            !e.recipe.ingredientIds.any((i) => i.toLowerCase().contains(s)))
          return false;
      }
      if (!showAllergyRecipes && e.allergyHits.isNotEmpty) {
        return false;
      }

      final hasRequiredAppliances = e.recipe.requiredAppliances.every(
        (key) => (userAppliances[key] ?? 0) > 0,
      );
      if (!hasRequiredAppliances) return false;

      if (onlyFav && !favSet.contains(e.recipe.menuId)) return false;

      return true;

    }).toList();

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w >= 1200
            ? 3
            : w >= 800
            ? 2
            : 1;

        const spacing = 12.0;

        final filterPanel = glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleText('Filters'),
              const SizedBox(height: 8),
              _filterChips(
                label: 'Cuisine type',
                values: types,
                current: typeFilter,
                onChanged: (v) => setState(() => typeFilter = v),
              ),
              const SizedBox(height: 8),
              _filterChips(
                label: 'Taste',
                values: tastes,
                current: tasteFilter,
                onChanged: (v) => setState(() => tasteFilter = v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Show favorites only'),
                    selected: onlyFav,
                    onSelected: (v) => setState(() => onlyFav = v),
                    selectedColor: Colors.amber.withValues(alpha: .2),
                    checkmarkColor: Colors.amber,
                    side: const BorderSide(color: Colors.white24),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  FilterChip(
                    // ← 加這個
                    label: const Text('Show allergy recipes'),
                    selected: showAllergyRecipes,
                    onSelected: (v) => setState(() => showAllergyRecipes = v),
                    selectedColor: Colors.red.withValues(alpha: .2),
                    checkmarkColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.white24),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => setState(() => search = v),
                decoration: inputDecoration(
                  'Enter ingredient or dish',
                  icon: Icons.search,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );

        final recipesSection = cols == 1
            ? Column(
                children: [
                  for (int i = 0; i < filtered.length; i++) ...[
                    RecipeCard(
                      recipe: filtered[i].recipe,
                      mr: filtered[i].mr,
                      allergyHits: filtered[i].allergyHits,
                    ),
                    if (i < filtered.length - 1) const SizedBox(height: spacing),
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
                itemCount: filtered.length,
                itemBuilder: (_, i) => RecipeCard(
                  recipe: filtered[i].recipe,
                  mr: filtered[i].mr,
                  allergyHits: filtered[i].allergyHits,
                ),
              );

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [filterPanel, const SizedBox(height: 12), recipesSection],
          ),
        );
      },
    );
  }

  Widget _filterChips({
    required String label,
    required List<String> values,
    required String current,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(v),
                selected: v == current,
                onSelected: (_) => onChanged(v),
                labelStyle: TextStyle(
                  color: v == current ? Colors.black : Colors.white,
                ),
                selectedColor: Colors.white,
                backgroundColor: Colors.white12,
                side: const BorderSide(color: Colors.white24),
              ),
          ],
        ),
      ],
    );
  }
}
