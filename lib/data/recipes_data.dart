// [OOP] 靜態資料：所有食譜清單與索引（例如 kAllRecipes / kRecipeById）。

import '../domain/models/recipe.dart';

const List<Recipe> kRecipes = [
  Recipe(
    menuId: 'r1',
    name: 'Tomato & Egg Stir-fry',
    type: 'Chinese',
    taste: ['Savory', 'Slightly sweet'],
    ingredientsRequired: ['tomato', 'egg', 'salt', 'oil'],
    cover: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?q=80&w=1200&auto=format&fit=crop',
    steps: [
      RecipeStep('Cut tomatoes', 3),
      RecipeStep('Heat pan, add oil', 2),
      RecipeStep('Add eggs and stir-fry', 2),
      RecipeStep('Add tomatoes & season', 3),
    ],
  ),
  Recipe(
    menuId: 'r2',
    name: 'Garlic Butter Shrimp',
    type: 'Western',
    taste: ['Aromatic', 'Salty'],
    ingredientsRequired: ['shrimp', 'garlic', 'butter', 'salt', 'pepper'],
    cover: 'https://images.unsplash.com/photo-1604908178196-1c9c1c9d9c36?q=80&w=1200&auto=format&fit=crop',
    steps: [
      RecipeStep('Thaw & devein', 4),
      RecipeStep('Heat butter, sauté minced garlic', 2),
      RecipeStep('Add shrimp and cook until color changes', 4),
    ],
  ),
  Recipe(
    menuId: 'r3',
    name: 'Japanese-Style Salad',
    type: 'Japanese',
    taste: ['Refreshing', 'Sweet & sour'],
    ingredientsRequired: ['lettuce', 'tomato', 'cucumber', 'sesame', 'soy_sauce', 'vinegar', 'oil'],
    cover: 'https://images.unsplash.com/photo-1490474418585-ba9bad8fd0ea?q=80&w=1200&auto=format&fit=crop',
    steps: [
      RecipeStep('Wash & cut veggies', 3),
      RecipeStep('Mix wafu dressing', 2),
      RecipeStep('Toss and sprinkle sesame', 2),
    ],
  ),
  Recipe(
    menuId: 'r4',
    name: 'Thai Basil Pork',
    type: 'Thai',
    taste: ['Spicy', 'Aromatic'],
    ingredientsRequired: ['pork', 'basil', 'garlic', 'chili', 'soy_sauce', 'sugar', 'oil'],
    cover: 'https://images.unsplash.com/photo-1544025162-d76694265947?q=80&w=1200&auto=format&fit=crop',
    steps: [
      RecipeStep('Sauté garlic and chili', 2),
      RecipeStep('Add pork and stir-fry until crumbly', 4),
      RecipeStep('Season, add Thai basil and toss', 2),
    ],
  ),
  Recipe(
    menuId: 'r5',
    name: 'Pesto Mushroom Pasta',
    type: 'Western',
    taste: ['Herbs', 'Salty'],
    ingredientsRequired: ['pasta', 'mushroom', 'basil', 'garlic', 'oil', 'salt'],
    cover: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?q=80&w=1200&auto=format&fit=crop',
    steps: [
      RecipeStep('Cook pasta', 6),
      RecipeStep('Sauté garlic and mushrooms', 3),
      RecipeStep('Add pesto and toss', 2),
    ],
  ),
];

final Map<String, Recipe> kRecipeById = {
  for (final r in kRecipes) r.menuId: r,
};

final List<String> kAllIngredients = [
  ...{
    for (final r in kRecipes) ...r.ingredientsRequired,
    'egg',
    'tomato',
    'lettuce',
    'cucumber',
    'shrimp',
    'butter',
    'pepper',
    'vinegar',
    'sesame',
    'pork',
    'chili',
    'soy_sauce',
    'sugar',
    'mushroom',
    'pasta',
  }
].toList()
  ..sort();