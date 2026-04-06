// [OOP] 資料模型：一個菜式/食譜（步驟、所需食材、封面等）。

class Recipe {
  final String menuId;
  final String name;
  final String type;
  final List<String> taste;
  // final List<String> ingredientsRequired;//要改
  final String cover;
  final List<RecipeStep> steps;

  /// totalTimeMinutes（排程/顯示用）
  /// - 先做成「可選 + 預設 0」：避免你其他地方有新建 Recipe 時要全部改晒
  final int totalTimeMinutes;

  /// 真正食材資料來源（全系統只用呢個）
  final List<RecipeIngredient> recipeIngredients;

  /// 所需大件廚具（統一名稱：stove / oven / microven / ricecooker）
  final List<String> kitchenEquipmentNeeded;

  const Recipe({
    required this.menuId,
    required this.name,
    required this.type,
    required this.taste,
    // required this.ingredientsRequired,//要改
    required this.cover,
    required this.steps,
    required this.totalTimeMinutes,
    this.recipeIngredients = const [],
    this.kitchenEquipmentNeeded = const [],
  });

  List<String> get ingredientIds =>
      recipeIngredients.map((e) => e.ingredientId).toList(growable: false);
}

// 每個食譜的「食材 + 份量 + 單位」
class RecipeIngredient {
  final String ingredientId; // e.g. 'salt', 'soy_sauce'
  final String quantity; // e.g. '1/2', '2' (可空字串代表未知/不提供)
  final String unit; // e.g. 'tsp', 'tbsp', 'g', 'ml', 'pcs' (可空字串)

  const RecipeIngredient({
    required this.ingredientId,
    this.quantity = '',
    this.unit = '',
  });

  String get display => unit.isEmpty ? quantity : '$quantity $unit';
}

class RecipeStep {
  /// 英文描述（你原本用 text）
  final String text;

  /// 你原本用嘅秒
  final int durationSec;

  /// 第幾步（由 1 開始）
  final int stepNumber;

  /// 需要器材（例如: stove / oven / knife）
  final String? requiredEquipment;

  /// 是否「持續性」動作（例如要一路攪拌/照看）
  final bool isContinuous;

  /// 是否可與其他步驟同時進行（例如燜/焗/浸）
  final bool isConcurrent;

  const RecipeStep(
    this.text,
    this.durationSec, {
    required this.stepNumber,
    this.requiredEquipment,
    this.isContinuous = true,
    this.isConcurrent = false,
  });

  /// （可選）UI 想顯示分鐘就用
  int get durationMin => (durationSec / 60).ceil();
}
