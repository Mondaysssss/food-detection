import '../domain/models/recipe.dart';

// [OOP] 靜態資料：食材/調味料的顯示名稱、分類、預設份量等（包含調味料 key / 茶匙換算）。

/// seasoning keys
const Set<String> kSeasoningKeys = {
  // ===== salt / pepper =====
  'salt',
  'kosher_salt',
  'pepper',
  'black_pepper',
  'white_pepper',
  'salt_pepper',
  'garlic_salt',

  // ===== sugar / sweeteners =====
  'sugar',
  'brown_sugar',
  'honey',

  // ===== oils / fats =====
  'oil',
  'cooking_oil',
  'corn_oil',
  'neutral_oil',
  'olive_oil',
  'extra_virgin_olive_oil',
  'vegetable_oil',
  'sesame_oil',
  'butter',

  // ===== vinegar / wines / japanese seasoning =====
  'vinegar',
  'rice_vinegar',
  'shaoxing_wine',
  'red_wine',
  'white_wine',
  'sake',
  'mirin',

  // ===== soy / sauces / pastes / condiments =====
  'soy_sauce',
  'light_soy_sauce',
  'dark_soy_sauce',
  'tamari_soy_sauce',
  'oyster_sauce',
  'fish_sauce',
  'hoisin_sauce',
  'bbq_sauce',
  'ketchup',
  'mayonnaise',
  'mustard',
  'miso',
  'gochujang',
  'sriracha',
  'chili_oil',
  'doubanjiang',
  'curry_paste',

  // ===== spices / herbs (seasoning category) =====
  'five_spice_powder',
  'cumin',
  'paprika',
  'chili_powder',
  'cayenne',
  'oregano',
  'basil_dried',
  'thyme_dried',
  'rosemary_dried',

  // ===== misc =====
  'msg',
  'cornstarch',
};

/// 預設份量（UI 顯示用 fallback）
const Map<String, String> kQtyDefaults = {
  // common
  'salt': 'to taste',
  'pepper': 'to taste',
  'oil': '1 tbsp',
  'soy_sauce': '1 tbsp',

  // examples
  'egg': '2 pcs',
  'tomato': '2 pcs',
  'garlic': '2 cloves',
};

/// 調味料換算為 teaspoons（購物車彙總用）
const Map<String, double> kSeasoningTeaspoons = {
  // 1 tbsp = 3 tsp
  'soy_sauce': 3.0,
  'light_soy_sauce': 3.0,
  'dark_soy_sauce': 3.0,
  'oyster_sauce': 3.0,
  'sesame_oil': 3.0,
  'olive_oil': 3.0,
  'oil': 3.0,

  // already tsp-based
  'salt': 1.0,
  'pepper': 1.0,
  'sugar': 1.0,
};

/// =========================================================
/// 方案 B：由 Recipe.recipeIngredients 分類（主食材 / 調味料）
/// =========================================================
bool isSeasoningKey(String key) => kSeasoningKeys.contains(key);

List<RecipeIngredient> recipeSeasonings(Recipe r) => r.recipeIngredients
    .where((x) => isSeasoningKey(x.ingredientId))
    .toList(growable: false);

List<RecipeIngredient> recipeMainIngredients(Recipe r) => r.recipeIngredients
    .where((x) => !isSeasoningKey(x.ingredientId))
    .toList(growable: false);

List<String> recipeSeasoningIds(Recipe r) =>
    recipeSeasonings(r).map((x) => x.ingredientId).toList(growable: false);

List<String> recipeMainIngredientIds(Recipe r) =>
    recipeMainIngredients(r).map((x) => x.ingredientId).toList(growable: false);
