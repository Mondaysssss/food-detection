// lib/data/ingredients_meta.dart
// 食材名稱顯示用（把 key 變得更好睇）
// 你之後可以加更多 key 對照（例如中文名、icon、分類等）。

String prettyIngredientName(String key) {
  switch (key) {
    case 'soy_sauce':
      return 'Soy sauce';
    case 'sesame':
      return 'Sesame';
    case 'pasta':
      return 'Pasta';
    default:
      return key.replaceAll('_', ' ');
  }
}