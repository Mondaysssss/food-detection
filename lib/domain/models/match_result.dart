// lib/domain/models/match_result.dart
// Domain Model：配對結果（已有/缺少）
// 用於 Recommend/Cart/RecipeCard UI 顯示。

class MatchResult {
  final List<String> match;
  final List<String> missing;
  const MatchResult(this.match, this.missing);
}