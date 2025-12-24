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

const Map<String, List<String>> kSellingPoints = {
  'r1': ['Quick home-style', 'High-protein, low-cost', 'One-pan meal'],
  'r2': ['Garlicky & rich', 'Great with rice', 'Fast to cook'],
  'r3': ['Low-cal & refreshing', 'Done in 5 minutes', 'Appetizing side'],
  'r4': ['Spicy & great with rice', 'Fragrant Thai basil', 'Classic street-style'],
  'r5': ['Herb-fresh', 'One-pot friendly', 'Quick dinner'],
};

const Map<String, List<String>> kStepsVerbose = {
  'r1': [
    'Wash tomatoes and cut into large chunks.',
    'Beat the eggs, add a little water (about 2–3 tsp) and mix.',
    'Heat wok with oil, pour in egg mixture and stir-fry on high heat until about 70% done. Set aside.',
    'Stir-fry tomatoes briefly, then add salt, water and sugar to cook.',
    'When tomatoes soften, add tomato paste and a bit of cornstarch slurry, return eggs and stir-fry until cooked.',
  ],
};