// [OOP] 資料模型：一個菜式/食譜（步驟、所需食材、封面等）。

class Recipe {
  final String menuId;
  final String name;
  final String type;
  final List<String> taste;
  final List<String> ingredientsRequired;
  final String cover;
  final List<RecipeStep> steps;

  /// ✅ 新增：totalTimeMinutes（排程/顯示用）
  /// - 先做成「可選 + 預設 0」：避免你其他地方有新建 Recipe 時要全部改晒
  final int totalTimeMinutes;

  const Recipe({
    required this.menuId,
    required this.name,
    required this.type,
    required this.taste,
    required this.ingredientsRequired,
    required this.cover,
    required this.steps,

    /// ✅ 新增（可選）
    this.totalTimeMinutes = 0,
  });
}

class RecipeStep {
  final String text;
  final int durationMin;

  /// ✅ 新增：requiredEquipment / isContinuous / isConcurrent
  /// - 同樣做成「可選 + 預設值」：舊有 RecipeStep('xx', 3) 唔使改
  final String? requiredEquipment;
  final bool isContinuous;
  final bool isConcurrent;

  const RecipeStep(
    this.text,
    this.durationMin, {
    this.requiredEquipment,
    this.isContinuous = true,
    this.isConcurrent = false,
  });

  /// （可選）方便你之後同 DB / ipynb 對齊
  int get timeInSeconds => durationMin * 60;
}
