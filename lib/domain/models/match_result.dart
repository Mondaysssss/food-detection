// [OOP] Data model: matching result between a recipe and detected ingredients (hit/missing/extra, etc.).

class MatchResult {
  final List<String> match;
  final List<String> missing;
  const MatchResult(this.match, this.missing);
}
