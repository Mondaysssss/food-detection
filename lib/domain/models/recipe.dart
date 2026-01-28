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
    required this.totalTimeMinutes,
  });
}

class RecipeStep {
  /// 英文描述（你原本用 text）
  final String text;

  /// 你原本用嘅分鐘（保留，方便 UI 顯示）
  final int durationMin;

  /// 第幾步（由 1 開始）
  final int stepNumber;

  /// 秒（for ipynb / scheduler）
  final int SteptimeInSeconds;

  /// 需要器材（例如: stove / oven / knife）
  final String? requiredEquipment;

  /// 是否「持續性」動作（例如要一路攪拌/照看）
  final bool isContinuous;

  /// 是否可與其他步驟同時進行（例如燜/焗/浸）
  final bool isConcurrent;

  const RecipeStep(
    this.text,
    this.durationMin, {
    required this.stepNumber,
    required this.SteptimeInSeconds,
    this.requiredEquipment,
    this.isContinuous = true,
    this.isConcurrent = false,
  });
}
