// lib/ui/widgets/recipe_card.dart
// ✅ RecipeCard：菜單卡片（推薦頁、購物車、歷史頁都重用）
// 功能：
// - 封面圖 + 主料完整度徽章 + 收藏星星
// - 已擁有 / 缺少食材列表（美化名稱）
// - 進度條（只算主料，不含調味料）
// - + / - 加入購物車（readOnly = true 時隱藏，只顯示數量）
// - 長按彈出詳細 BottomSheet
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/match_result.dart';
import '../../domain/models/recipe.dart';
import '../../state/app_state.dart';
import 'favorite_star.dart';
import 'glass.dart';
import 'recipe_detail_sheet.dart';

/// 將食材 key 轉成適合顯示的美化名稱（與 recipe_detail_sheet 一致）
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
    // 未來新增食材直接在這裡補上
    default:
      return key.replaceAll('_', ' ').split(' ').map((word) =>
          word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
  }
}

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final MatchResult mr;
  final bool readOnly;
  final int? qtyForCart;
  final bool showMatchLines;
  final bool showProgress;
  final double coverAspect;
  final bool compact;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.mr,
    this.readOnly = false,
    this.qtyForCart,
    this.showMatchLines = true,
    this.showProgress = true,
    this.coverAspect = 16 / 9,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final mainCount = mr.match.length + mr.missing.length;
    final ratio = mainCount == 0 ? 1.0 : mr.match.length / mainCount.toDouble();

    final count = context.select<AppState, int>(
      (s) => s.cartCountOf(recipe.menuId),
    );

    // 美化 Already / Missing 顯示文字
    final String alreadyText = mr.match.isEmpty
        ? '—'
        : mr.match.map(prettyIngredientName).join(', ');
    final String missingText = mr.missing.isEmpty
        ? '—'
        : mr.missing.map(prettyIngredientName).join(', ');

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onLongPress: () => showRecipeDetailSheet(context, recipe, mr),
      child: glass(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== 封面區 =====
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: coverAspect,
                    child: Image.network(
                      recipe.cover,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) =>
                          loadingProgress == null ? child : const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  // 完整度徽章
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${mr.match.length}/$mainCount complete',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ),
                  // 收藏星星
                  Positioned(
                    right: 8,
                    top: 8,
                    child: FavoriteStar(menuId: recipe.menuId),
                  ),
                  // 購物車數量（readOnly 模式）
                  if (readOnly && (qtyForCart ?? 0) > 0)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '×${qtyForCart!}',
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ===== 資訊區 =====
            Padding(
              padding: compact
                  ? const EdgeInsets.fromLTRB(12, 6, 12, 8)
                  : const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 菜名
                  Text(
                    recipe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  // 類型與口味
                  Text(
                    '${recipe.type} · ${recipe.taste.join(' / ')}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),

                  // 已擁有 / 缺少食材
                  if (showMatchLines) ...[
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Already: ', style: TextStyle(fontSize: 12)),
                          TextSpan(
                            text: alreadyText,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFBBF7D0)),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Missing: ', style: TextStyle(fontSize: 12)),
                          TextSpan(
                            text: missingText,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFFECACA)),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 進度條
                  if (showProgress) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 加入購物車按鈕（非 readOnly）
                  if (!readOnly)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton.filledTonal(
                          onPressed: count > 0 ? () => app.addToCart(recipe.menuId, -1) : null,
                          icon: const Icon(Icons.remove),
                          tooltip: '減少 1 份',
                          style: IconButton.styleFrom(fixedSize: const Size(40, 40), padding: EdgeInsets.zero),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        IconButton.filled(
                          onPressed: () => app.addToCart(recipe.menuId, 1),
                          icon: const Icon(Icons.add),
                          tooltip: '增加 1 份',
                          style: IconButton.styleFrom(fixedSize: const Size(40, 40), padding: EdgeInsets.zero),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}