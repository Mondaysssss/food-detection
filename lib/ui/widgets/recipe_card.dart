// [OOP] Shared widget: recipe card (cover image, name, match score, add to cart, etc.).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/match_result.dart';
import '../../domain/models/recipe.dart';
import '../../state/app_state.dart';
import 'favorite_star.dart';
import 'glass.dart';
import 'recipe_detail_sheet.dart';

/// Format seconds: ≥1h → "1h 30min"; <1h → "5min 30sec"; 0 → "0min"
String _fmtTime(int totalSec) {
  if (totalSec <= 0) return '0min';
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  if (h > 0) {
    return m > 0 ? '${h}h ${m}min' : '${h}h';
  }
  return s > 0 ? '${m}min ${s}sec' : '${m}min';
}

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final MatchResult mr;
  final List<String> allergyHits;

  final bool readOnly;
  final int? qtyForCart;

  final bool showMatchLines;
  final bool showProgress;

  final double coverAspect;
  final bool compact;
  final bool showQtyControls;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.mr,
    this.allergyHits = const [],
    this.readOnly = false,
    this.qtyForCart,
    this.showMatchLines = true,
    this.showProgress = true,
    this.coverAspect = 16 / 9,
    this.compact = false,
    this.showQtyControls = false,
  });

  void _showMenuLimitDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Menu limit reached'),
        content: const Text(
          'You can add at most 5 recipes in Menu suggestions. Remove one first before adding another.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final mainCount = mr.match.length + mr.missing.length;
    final count = context.select<AppState, int>(
      (s) => s.cartCountOf(recipe.menuId),
    );
    final limitReached = context.select<AppState, bool>(
      (s) => s.isMenuSuggestionLimitReached,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onLongPress: () => showRecipeDetailSheet(context, recipe, mr),
      child: glass(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: coverAspect,
                    child: Image.asset(
                      recipe.cover,
                      fit: BoxFit.cover,
                      cacheWidth: 600, // decode at smaller size to save memory
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${mr.match.length}/${mainCount} complete',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: FavoriteStar(menuId: recipe.menuId),
                  ),
                  if (readOnly && (qtyForCart ?? 0) > 0)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('x${qtyForCart!}'),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: compact
                  ? const EdgeInsets.fromLTRB(12, 6, 12, 8)
                  : const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${recipe.type} ・ ${recipe.taste.join('/ ')}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            if (!compact) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  _timeBadge(
                                    Icons.content_cut,
                                    'Prep',
                                    _fmtTime(recipe.prepTimeSec),
                                    const Color(0xFF90CAF9),
                                  ),
                                  _timeBadge(
                                    Icons.local_fire_department,
                                    'Cook',
                                    _fmtTime(recipe.cookTimeSec),
                                    const Color(0xFFFFAB91),
                                  ),
                                  _timeBadge(
                                    Icons.schedule,
                                    'Total',
                                    _fmtTime(recipe.combinedTimeSec),
                                    const Color(0xFFA5D6A7),
                                  ),
                                ],
                              ),
                            ],
                            if (allergyHits.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Allergy alert: ${allergyHits.join(', ')}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFFFB4B4),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (showMatchLines) ...[
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Already: ',
                            style: TextStyle(fontSize: 12),
                          ),
                          TextSpan(
                            text: mr.match.isEmpty ? '—' : mr.match.join(', '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFBBF7D0),
                            ),
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
                          const TextSpan(
                            text: 'Missing: ',
                            style: TextStyle(fontSize: 12),
                          ),
                          TextSpan(
                            text: mr.missing.isEmpty
                                ? '—'
                                : mr.missing.join(', '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFECACA),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (showProgress) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: mainCount == 0
                            ? 1
                            : (mr.match.length / mainCount).clamp(0.0, 1.0),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (!readOnly || showQtyControls)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton.filledTonal(
                          onPressed: count > 0
                              ? () => app.addToCart(recipe.menuId, -1)
                              : null,
                          icon: const Icon(Icons.remove),
                          tooltip: 'Decrease 1',
                          style: IconButton.styleFrom(
                            fixedSize: const Size(40, 40),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '$count',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton.filled(
                          onPressed: () {
                            if (limitReached) {
                              FocusScope.of(context).unfocus();
                              _showMenuLimitDialog(context);
                              return;
                            }
                            app.addToCart(recipe.menuId, 1);
                          },
                          icon: const Icon(Icons.add),
                          tooltip: limitReached
                              ? 'Maximum 5 recipes'
                              : 'Increase 1',
                          style: IconButton.styleFrom(
                            fixedSize: const Size(40, 40),
                            padding: EdgeInsets.zero,
                            backgroundColor: limitReached
                                ? Colors.grey.withValues(alpha: 0.35)
                                : null,
                            foregroundColor: limitReached
                                ? Colors.white38
                                : null,
                          ),
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

Widget _timeBadge(IconData icon, String label, String value, Color color) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 3),
      Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
