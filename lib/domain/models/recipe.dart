// [OOP] 資料模型：一個菜式/食譜（步驟、所需食材、封面等）。

class Recipe {
  final String menuId;
  final String name;
  final String type;
  final List<String> taste;
  final List<String> ingredientsRequired;
  final String cover;
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