// [OOP] Core logic: computes the match score between "detected ingredients" and "recipe required ingredients".

import '../../data/ingredients_meta.dart';
import '../models/match_result.dart';
import '../models/recipe.dart';

MatchResult computeMatch(Recipe r, List<String> detected) {
  final have = detected.toSet();

  // only main ingredients (ignore seasoning)
  final requiredMain = <String>[
    for (final x in r.ingredientIds)
      if (!kSeasoningKeys.contains(x)) x,
  ];

  final match = <String>[];
  final missing = <String>[];

  for (final x in requiredMain) {
    (have.contains(x) ? match : missing).add(x);
  }

  return MatchResult(match, missing);
}
