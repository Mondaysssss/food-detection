// lib/data/recipe_meta.dart
// Recipe 補充資訊（不改 Recipe model 也可以顯示詳情）
// 用途：Recipe 詳細頁、Cart Summary、烹調統計、數量顯示、賣點 chips、verbose steps...

const Map<String, int> kRecipeServings = {
  'r1': 2, 'r2': 2, 'r3': 2, 'r4': 3, 'r5': 2,
};

const Map<String, int> kRecipeDifficulty = {
  'r1': 2, 'r2': 3, 'r3': 1, 'r4': 3, 'r5': 2,
};

const Map<String, String> kRecipeMethod = {
  'r1': 'Stir-fry',
  'r2': 'Sear / Sauté',
  'r3': 'Tossed',
  'r4': 'Stir-fry',
  'r5': 'Boil / Toss',
};

/// 已知調味料 key（其餘視為主料）
const Set<String> kSeasoningKeys = {
  'salt', 'pepper', 'soy_sauce', 'sugar', 'vinegar', 'oil',
};

/// 食材預設數量（沒有列到的顯示「to taste」）
const Map<String, String> kQtyDefaults = {
  'egg': '2 pcs',
  'tomato': '2 pcs (about 300g)',
  'lettuce': '150 g',
  'cucumber': '100 g',
  'shrimp': '200 g',
  'butter': '20 g',
  'garlic': '2 cloves',
  'pepper': 'a pinch',
  'vinegar': '1 tbsp',
  'sesame': '1 tsp',
  'pork': '200 g',
  'chili': '1 pc',
  'soy_sauce': '1 tbsp',
  'sugar': '1 tsp',
  'mushroom': '120 g',
  'pasta': '200 g',
  'basil': 'a handful',
  'oil': '1 tbsp',
  'salt': '1/2 tsp',
};

/// 單份菜單所需調味料折算（茶匙）
/// 用於 Cart Summary：彙總調味料量
const Map<String, double> kSeasoningTeaspoons = {
  'salt': 0.5,
  'pepper': 0.25,
  'soy_sauce': 3.0, // 1 tbsp = 3 tsp
  'sugar': 1.0,
  'vinegar': 3.0,
  'oil': 3.0,
};

/// 簡短賣點（可自由增修）
const Map<String, List<String>> kSellingPoints = {
  'r1': ['Quick Home-Style', 'High-Protein, Low-Cost', 'One-pan meal'],
  'r2': ['Garlicky & Rich', 'Seafood lovers', 'Great with drinks or rice'],
  'r3': ['Low-cal & Refreshing', 'Done in 5 minutes', 'Appetizing side'],
  'r4': ['Spicy & great with rice', 'Fragrant Thai basil', 'Perfect with white rice'],
  'r5': ['Herb-fresh', 'One-pot', 'Quick Dinner'],
};

/// 詳細步驟（若無對應就 fallback 用 Recipe.steps）
const Map<String, List<String>> kStepsVerbose = {
  'r1': [
    'Wash tomatoes and cut into large chunks.',
    'Beat the eggs, add a little water (about 2–3 tsp) and mix.',
    'Heat wok with oil, pour in egg mixture and stir-fry on high heat until about 70% done. Set aside.',
    'Stir-fry tomatoes briefly, then add salt, water and sugar to cook.',
    'When tomatoes soften, add tomato paste and a bit of cornstarch slurry, return eggs and stir-fry until cooked.',
  ],
};