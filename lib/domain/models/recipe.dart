// lib/domain/models/recipe.dart
// ✅ Domain Model：Recipe + RecipeStep
// 代表「菜單」以及「步驟」資料結構（純資料，不含 UI / State）。

class Recipe {
  final String menuId;
  final String name;
  final String type; // Cuisine type (Chinese/Western/...)
  final List<String> taste; // Tags
  final List<String> ingredientsRequired; // 包含主料 + 調味料 key
  final String cover; // Image URL
  final List<RecipeStep> steps;

  const Recipe({
    required this.menuId,
    required this.name,
    required this.type,
    required this.taste,
    required this.ingredientsRequired,
    required this.cover,
    required this.steps,
  });
}

class RecipeStep {
  final String text;
  final int durationMin;
  const RecipeStep(this.text, this.durationMin);
}