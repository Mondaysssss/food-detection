// [OOP] 全域狀態：管理已偵測食材、購物車、收藏、煮食紀錄等；透過 ChangeNotifier 通知 UI 更新。

import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/ingredients_meta.dart';
import '../domain/models/cook_history.dart';
import '../domain/models/cook_session.dart';
import '../domain/models/recipe.dart';

class AppState extends ChangeNotifier {
  // detected main ingredients (names only; no quantity)
  final List<String> _ingredients = [];
  UnmodifiableListView<String> get ingredients => UnmodifiableListView(_ingredients);

  // favorites (menuId)
  final Set<String> _favorites = {};
  Set<String> get favorites => _favorites;

  // single-dish history (fallback)
  final List<CookHistory> _history = [];
  UnmodifiableListView<CookHistory> get history => UnmodifiableListView(_history);

  // cart: menuId -> qty
  final Map<String, int> _cart = {};
  UnmodifiableMapView<String, int> get cart => UnmodifiableMapView(_cart);

  // cook sessions (from cart snapshot)
  final List<CookSession> _sessions = [];
  UnmodifiableListView<CookSession> get sessions => UnmodifiableListView(_sessions);

  void addSessionFromCartSnapshot(Map<String, int> snapshot, int totalMinutes) {
    _sessions.insert(
      0,
      CookSession(
        completedAt: DateTime.now(),
        items: Map<String, int>.from(snapshot),
        totalMinutes: totalMinutes,
      ),
    );
    notifyListeners();
  }

  int cartCountOf(String menuId) => _cart[menuId] ?? 0;
  int get cartTotalCount => _cart.values.fold(0, (s, v) => s + v);

  void addToCart(String menuId, [int delta = 1]) {
    final n = (_cart[menuId] ?? 0) + delta;
    if (n <= 0) {
      _cart.remove(menuId);
    } else {
      _cart[menuId] = n;
    }
    notifyListeners();
  }

  void setCartCount(String menuId, int count) {
    if (count <= 0) _cart.remove(menuId);
    else _cart[menuId] = count;
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  // teaching options
  bool strictMode = true;
  int timeScale = 10; // 1 min = 10 sec (demo-friendly)

  void setStrictMode(bool v) {
    strictMode = v;
    notifyListeners();
  }

  void setTimeScale(int v) {
    timeScale = v;
    notifyListeners();
  }

  // add single ingredient (filter out seasoning)
  void addIngredient(String name) {
    if (kSeasoningKeys.contains(name)) return;
    if (!_ingredients.contains(name)) {
      _ingredients.add(name);
      notifyListeners();
    }
  }

  // add many (filter out seasoning)
  void addIngredients(Iterable<String> names) {
    bool changed = false;
    for (final n in names) {
      if (kSeasoningKeys.contains(n)) continue;
      if (!_ingredients.contains(n)) {
        _ingredients.add(n);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void removeIngredient(String name) {
    _ingredients.remove(name);
    notifyListeners();
  }

  void clearIngredients() {
    _ingredients.clear();
    notifyListeners();
  }

  void toggleFavorite(String menuId) {
    if (_favorites.contains(menuId)) {
      _favorites.remove(menuId);
    } else {
      _favorites.add(menuId);
    }
    notifyListeners();
  }

  void addHistory(Recipe r) {
    _history.insert(0, CookHistory(title: r.name, cover: r.cover, completedAt: DateTime.now()));
    notifyListeners();
  }

  void resetAll() {
    _ingredients.clear();
    _favorites.clear();
    _history.clear();
    _cart.clear();
    _sessions.clear();
    strictMode = true;
    timeScale = 10;
    notifyListeners();
  }
}