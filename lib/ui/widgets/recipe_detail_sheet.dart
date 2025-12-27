// lib/ui/widgets/recipe_detail_sheet.dart
// ✅ 長按菜單卡 → 彈出詳細 BottomSheet
// 顯示：封面圖、賣點、基本資訊、主料+數量、調味料、詳細步驟
// 未來擴充營養資訊 → 只需改 data/recipe_meta.dart 即可

import 'package:flutter/material.dart';

import '../../data/recipe_meta.dart';
import '../../domain/models/match_result.dart';
import '../../domain/models/recipe.dart';
import 'ui_helpers.dart';

/// 美化食材 key 成適合顯示的名稱（與 ui_helpers.dart 的 prettyName 一致）
String prettyIngredientName(String key) {
  switch (key) {
    case 'soy_sauce':
      return 'Soy sauce';
    case 'sesame':
      return 'Sesame';
    case 'pasta':
      return 'Pasta';
    case 'oil':
      return 'Cooking oil';
    case 'salt':
      return 'Salt';
    case 'sugar':
      return 'Sugar';
    case 'pepper':
      return 'Black pepper';
    case 'vinegar':
      return 'Vinegar';
    // 未來可繼續補充
    default:
      return key.replaceAll('_', ' ').split(' ').map((word) => 
          word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
  }
}

void showRecipeDetailSheet(BuildContext context, Recipe recipe, MatchResult mr) {
  final totalMin = recipe.steps.fold<int>(0, (s, st) => s + st.durationMin);
  final servings = kRecipeServings[recipe.menuId] ?? 2;
  final difficulty = kRecipeDifficulty[recipe.menuId] ?? 2;
  final method = kRecipeMethod[recipe.menuId] ?? '—';
  final selling = kSellingPoints[recipe.menuId] ?? const ['Quick to Table', 'Easy Ingredients', 'Home-style Flavor'];
  final verbose = kStepsVerbose[recipe.menuId] ?? recipe.steps.map((e) => e.text).toList();

  // 主料 / 調味料 + 美化名稱 + 數量
  final mainIngr = <MapEntry<String, String>>[];
  final seasonings = <MapEntry<String, String>>[];

  for (final key in recipe.ingredientsRequired) {
    final qty = kQtyDefaults[key] ?? 'to taste';
    final name = prettyIngredientName(key);
    final pair = MapEntry(name, qty);

    if (kSeasoningKeys.contains(key)) {
      seasonings.add(pair);
    } else {
      mainIngr.add(pair);
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.7),
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
                  color: Colors.black.withOpacity(0.5),
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
                    // ===== 頂部封面圖 + 返回按鈕 =====
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
                            color: Colors.black.withOpacity(0.45),
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

                    // ===== 主要內容 =====
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 標題 + 難度星星
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
                                children: List.generate(5, (i) =>
                                    Icon(i < difficulty ? Icons.star : Icons.star_border,
                                        color: Colors.amber, size: 18)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 賣點 Chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: selling.map((s) => Chip(
                                  label: Text(s),
                                  backgroundColor: Colors.white12,
                                  side: const BorderSide(color: Colors.white24),
                                  labelStyle: const TextStyle(color: Colors.white),
                                )).toList(),
                          ),
                          const SizedBox(height: 12),

                          // 基本資訊 Pill
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              kvPill('Cuisine', recipe.type),
                              kvPill('Taste', recipe.taste.join(' / ')),
                              kvPill('Method', method),
                              kvPill('Difficulty', '$difficulty / 5'),
                              kvPill('Servings', '$servings servings'),
                              kvPill('Total Time', '$totalMin min'),
                              kvPill('Ingredient Completeness', '${mr.match.length}/${recipe.ingredientsRequired.length}'),
                            ],
                          ),
                          const SizedBox(height: 14),

                          sectionTitle('Main Ingredients'),
                          const SizedBox(height: 6),
                          qtyList(mainIngr),

                          const SizedBox(height: 12),

                          sectionTitle('Seasoning'),
                          const SizedBox(height: 6),
                          qtyList(seasonings),

                          const SizedBox(height: 14),

                          sectionTitle('Detailed Steps'),
                          const SizedBox(height: 6),
                          for (int i = 0; i < verbose.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text('${i + 1}. ${verbose[i]}',
                                  style: const TextStyle(fontSize: 15)),
                            ),

                          const SizedBox(height: 20), // 底部留白
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