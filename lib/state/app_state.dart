// [OOP] 全域狀態：管理已偵測食材、購物車、收藏、煮食紀錄等；透過 ChangeNotifier 通知 UI 更新。

import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/ingredients_meta.dart';
import '../domain/models/cook_history.dart';
import '../domain/models/cook_session.dart';
import '../domain/models/recipe.dart';

class AppState extends ChangeNotifier {
  // =========================================================
  // Persona / Profile (for Settings display)
  // =========================================================

  // login 未做，所以先用固定字
  String userName = 'User name';

  String? gender; // from PersonaWizard
  int age = 18; // from PersonaWizard

  // appliances counts (from PersonaWizard)
  final Map<String, int> _appliances = {
    'cookware': 0,
    'stove': 0,
    'electric': 0,
    'bake': 0,
  };
  Map<String, int> get appliances => Map.unmodifiable(_appliances);

  // same limits as persona_wizard_screen.dart
  static const Map<String, int> applianceMin = {
    'cookware': 1,
    'stove': 1,
    'electric': 0,
    'bake': 0,
  };

  static const Map<String, int> applianceMax = {
    'cookware': 2,
    'stove': 2,
    'electric': 2,
    'bake': 1,
  };

  int applianceValue(String key) {
    final v = _appliances[key] ?? 0;
    final max = applianceMax[key] ?? 999;
    if (v < 0) return 0;
    final mn = applianceMin[key] ?? 0;
    if (v < mn) return mn;
    return v;
  }

  void setAppliance(String key, int value) {
    final max = applianceMax[key] ?? 999;
    var v = value;
    if (v < 0) v = 0;
    if (v > max) v = max;
    _appliances[key] = v;
    notifyListeners();
  }

  // =========================================================
  // Allergies (from PersonaWizard / Preference page)
  // =========================================================
  final Set<String> _allergies = {};
  UnmodifiableSetView<String> get allergies => UnmodifiableSetView(_allergies);

  bool hasAllergy(String name) => _allergies.contains(name);

  void toggleAllergy(String name) {
    if (_allergies.contains(name))
      _allergies.remove(name);
    else
      _allergies.add(name);
    notifyListeners();
  }

  void setAllergies(Set<String> names) {
    _allergies
      ..clear()
      ..addAll(names);
    notifyListeners();
  }

  void setPersona({
    String? newGender,
    int? newAge,
    Map<String, int>? newAppliances,
  }) {
    if (newGender != null) gender = newGender;
    if (newAge != null) age = newAge;
    if (newAppliances != null) {
      for (final k in _appliances.keys) {
        final v = newAppliances[k] ?? _appliances[k] ?? 0;
        setAppliance(k, v); // 內部會 notify
      }
      return;
    }
    notifyListeners();
  }

  void clearPersona() {
    gender = null;
    age = 18;
    userName = 'User name';
    for (final k in _appliances.keys) {
      _appliances[k] = 0;
    }
    _allergies.clear();
    notifyListeners();
  }

  // =========================================================
  // Existing AppState (unchanged)
  // =========================================================

  // detected main ingredients (names only; no quantity)
  final List<String> _ingredients = [];
  UnmodifiableListView<String> get ingredients =>
      UnmodifiableListView(_ingredients);

  // favorites (menuId)
  final Set<String> _favorites = {};
  Set<String> get favorites => _favorites;

  // single-dish history (fallback)
  final List<CookHistory> _history = [];
  UnmodifiableListView<CookHistory> get history =>
      UnmodifiableListView(_history);

  // cart: menuId -> qty
  final Map<String, int> _cart = {};
  UnmodifiableMapView<String, int> get cart => UnmodifiableMapView(_cart);

  // cook sessions (from cart snapshot)
  final List<CookSession> _sessions = [];
  UnmodifiableListView<CookSession> get sessions =>
      UnmodifiableListView(_sessions);

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

  void addSessionFromFirestore({
    required Map<String, int> items,
    required int totalMinutes,
    required DateTime completedAt,
  }) {
    _sessions.add(
      CookSession(
        completedAt: completedAt,
        items: Map<String, int>.from(items),
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
    if (count <= 0)
      _cart.remove(menuId);
    else
      _cart[menuId] = count;
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
    _history.insert(
      0,
      CookHistory(title: r.name, cover: r.cover, completedAt: DateTime.now()),
    );
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

    // reset persona/profile
    userName = 'User name';
    gender = null;
    age = 18;
    _appliances['cookware'] = 0;
    _appliances['stove'] = 0;
    _appliances['electric'] = 0;
    _appliances['bake'] = 0;
    _allergies.clear();

    notifyListeners();
  }
}
