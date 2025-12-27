// [OOP] 資料模型：食譜與偵測食材的匹配結果（命中/缺少/多餘等）。

class MatchResult {
  final List<String> match;
  final List<String> missing;
  const MatchResult(this.match, this.missing);
}