// lib/state/app_state.dart
// ✅ 全域狀態中心（ChangeNotifier）
// 包含：
// - 食材清單（ingredients）
// - 收藏（favorites）
// - 單菜歷史（history）
// - 購物車（cart）
// - 多菜 Session 歷史（sessions）
// - 教學模式設定（strictMode / timeScale）
//
// UI 任何頁都可以用 context.watch / read / select 去讀或改。

import 'dart:collection';
import 'package:flutter/foundation.dart';

import '../data/recipe_meta.dart';
import '../domain/models/cook_history.dart';
import '../domain/models/cook_session.dart';
import '../domain/models/recipe.dart';

class AppState extends ChangeNotifier {
  // ===================== Ingredients（食材紀錄表）=====================
  final List<String> _ingredients = [];
  UnmodifiableListView<String> get ingredients => UnmodifiableListView(_ingredients);

  /// 單筆新增（會自動去重；同時濾走調味料）
  void addIngredient(String name) {
    if (kSeasoningKeys.contains(name)) return;
    if (!_ingredients.contains(name)) {
      _ingredients.add(name);
      notifyListeners();
    }
  }

  /// 多筆新增（會自動去重；同時濾走調味料）
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

  // ===================== Favorites（收藏）=====================
  final Set<String> _favorites = {};
  Set<String> get favorites => _favorites;

  void toggleFavorite(String menuId) {
    if (_favorites.contains(menuId)) {
      _favorites.remove(menuId);
    } else {
      _favorites.add(menuId);
    }
    notifyListeners();
  }

  // ===================== History（單菜完成紀錄）=====================
  final List<CookHistory> _history = [];
  UnmodifiableListView<CookHistory> get history => UnmodifiableListView(_history);

  void addHistory(Recipe r) {
    _history.insert(
      0,
      CookHistory(title: r.name, cover: r.cover, completedAt: DateTime.now()),
    );
    notifyListeners();
  }

  // ===================== Cart（購物車：menuId -> qty）=====================
  final Map<String, int> _cart = {};
  UnmodifiableMapView<String, int> get cart => UnmodifiableMapView(_cart);

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

  // ===================== Cook Sessions（多菜完成紀錄）=====================
  final List<CookSession> _sessions = [];
  UnmodifiableListView<CookSession> get sessions => UnmodifiableListView(_sessions);

  /// 由購物車快照生成一個 Session（完成後寫入 sessions）
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

  // ===================== 教學模式設定 =====================
  bool strictMode = true; // 嚴格模式：需跑完計時先可下一步（單菜 CookingScreen 用）
  int timeScale = 10; // 1 分鐘 = X 秒（demo 用）

  void setStrictMode(bool v) {
    strictMode = v;
    notifyListeners();
  }

  void setTimeScale(int v) {
    timeScale = v;
    notifyListeners();
  }

  // ===================== Reset =====================
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