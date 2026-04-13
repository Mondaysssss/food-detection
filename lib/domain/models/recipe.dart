// [OOP] 資料模型：一個菜式/食譜（步驟、所需食材、封面等）.

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

  /// 需要嘅廚房器材類別，對應 AppState._appliances 嘅 key：
  /// 'cookware' | 'stove' | 'electric' | 'bake'
  final List<String> requiredAppliances;

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
    this.requiredAppliances = const [],
  });

  List<String> get ingredientIds =>
      recipeIngredients.map((e) => e.ingredientId).toList(growable: false);

  /// 準備步驟總秒數（isPrep == true）
  int get prepTimeSec =>
      steps.where((s) => s.isPrep).fold(0, (sum, s) => sum + s.durationSec);

  /// 烹飪步驟總秒數（isPrep == false）
  int get cookTimeSec =>
      steps.where((s) => !s.isPrep).fold(0, (sum, s) => sum + s.durationSec);

  /// 總時間（準備 + 烹飪）
  int get combinedTimeSec => prepTimeSec + cookTimeSec;
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

  /// 是否屬於「準備步驟」（切菜、醃製、洗菜、打蛋等），排程時優先執行
  final bool isPrep;

  const RecipeStep(
    this.text,
    this.durationSec, {
    required this.stepNumber,
    this.requiredEquipment,
    this.isContinuous = true,
    this.isConcurrent = false,
    this.isPrep = false,
  });

  /// （可選）UI 想顯示分鐘就用
  int get durationMin => (durationSec / 60).ceil();
}
