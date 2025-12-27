// lib/domain/services/matcher.dart
// Domain Service：computeMatch()
// 專責「用戶已偵測食材」 vs 「菜單所需食材」配對。
// 規則：
// - 調味料永遠忽略（只計主料）
// - 回傳 match/missing（主料）

import '../../data/recipe_meta.dart';
import '../models/match_result.dart';
import '../models/recipe.dart';

MatchResult computeMatch(Recipe r, List<String> detected) {
  final have = detected.toSet();

  // 只留主料（非調味料）
  final requiredMain = <String>[
    for (final x in r.ingredientsRequired)
      if (!kSeasoningKeys.contains(x)) x,
  ];

  final match = <String>[];
  final missing = <String>[];

  for (final x in requiredMain) {
    (have.contains(x) ? match : missing).add(x);
  }

  return MatchResult(match, missing);
}