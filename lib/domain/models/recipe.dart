// [OOP] Data model: a dish/recipe (steps, required ingredients, cover image, etc.).

class Recipe {
  final String menuId;
  final String name;
  final String type;
  final List<String> taste;
  // final List<String> ingredientsRequired; // TODO: update
  final String cover;
  final List<RecipeStep> steps;

  /// totalTimeMinutes (used for scheduling/display)
  /// - Made optional with default 0 to avoid breaking other Recipe constructors
  final int totalTimeMinutes;

  /// The actual ingredient data source (used exclusively across the entire system)
  final List<RecipeIngredient> recipeIngredients;

  /// Required kitchen appliance categories, corresponding to AppState._appliances keys:
  /// 'cookware' | 'stove' | 'electric' | 'bake'
  final List<String> requiredAppliances;

  const Recipe({
    required this.menuId,
    required this.name,
    required this.type,
    required this.taste,
    // required this.ingredientsRequired, // TODO: update
    required this.cover,
    required this.steps,
    required this.totalTimeMinutes,
    this.recipeIngredients = const [],
    this.requiredAppliances = const [],
  });

  List<String> get ingredientIds =>
      recipeIngredients.map((e) => e.ingredientId).toList(growable: false);

  /// Total seconds for preparation steps (isPrep == true)
  int get prepTimeSec =>
      steps.where((s) => s.isPrep).fold(0, (sum, s) => sum + s.durationSec);

  /// Total seconds for cooking steps (isPrep == false)
  int get cookTimeSec =>
      steps.where((s) => !s.isPrep).fold(0, (sum, s) => sum + s.durationSec);

  /// Total time (prep + cooking)
  int get combinedTimeSec => prepTimeSec + cookTimeSec;
}

// Per-recipe ingredient entry with quantity and unit
class RecipeIngredient {
  final String ingredientId; // e.g. 'salt', 'soy_sauce'
  final String
  quantity; // e.g. '1/2', '2' (empty string means unknown/not provided)
  final String
  unit; // e.g. 'tsp', 'tbsp', 'g', 'ml', 'pcs' (empty string allowed)

  const RecipeIngredient({
    required this.ingredientId,
    this.quantity = '',
    this.unit = '',
  });

  String get display => unit.isEmpty ? quantity : '$quantity $unit';
}

class RecipeStep {
  /// Step description (originally named text)
  final String text;

  /// Duration in seconds (original field)
  final int durationSec;

  /// Step number (starting from 1)
  final int stepNumber;

  /// Required equipment (e.g. stove / oven / knife)
  final String? requiredEquipment;

  /// Whether this is a "continuous" action (e.g. must keep stirring/watching)
  final bool isContinuous;

  /// Whether this step can run concurrently with others (e.g. simmering/soaking)
  final bool isConcurrent;

  /// Whether this is a "prep step" (chopping, marinating, washing, beating eggs, etc.), executed first in scheduling
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

  /// (Optional) Use this to display duration in minutes in the UI
  int get durationMin => (durationSec / 60).ceil();
}
