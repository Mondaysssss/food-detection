/// seasoning keys
const Set<String> kSeasoningKeys = {
  'salt', 'pepper', 'soy_sauce', 'sugar', 'vinegar', 'oil',
};

/// default quantities
const Map<String, String> kQtyDefaults = {
  'egg': '2 pieces',
  'tomato': '2 pieces (about 300g)',
  'lettuce': '150 g',
  'cucumber': '100 g',
  'shrimp': '200 g',
  'butter': '20 g',
  'garlic': '2 cloves',
  'pepper': 'a pinch',
  'vinegar': '1 tbsp',
  'sesame': '1 tsp',
  'pork': '200 g',
  'chili': '1 piece',
  'soy_sauce': '1 tbsp',
  'sugar': '1 tsp',
  'mushroom': '120 g',
  'pasta': '200 g',
  'basil': 'a handful',
  'oil': '1 tbsp',
  'salt': '1/2 tsp',
};

/// seasoning to teaspoons (estimation)
const Map<String, double> kSeasoningTeaspoons = {
  'salt': 0.5,
  'pepper': 0.25,
  'soy_sauce': 3.0, // 1 tbsp = 3 tsp
  'sugar': 1.0,
  'vinegar': 3.0,
  'oil': 3.0,
};