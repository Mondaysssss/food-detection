import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MyApp(),
    ),
  );
}

/// --------------------------- App State ----------------------------------
class AppState extends ChangeNotifier {
  // 偵測到的食材（名稱，不含數量）
  final List<String> _ingredients = [];
  UnmodifiableListView<String> get ingredients =>
      UnmodifiableListView(_ingredients);

  // 最愛（menuId）
  final Set<String> _favorites = {};
  Set<String> get favorites => _favorites;

  // 歷史完成紀錄
  final List<CookHistory> _history = [];
  UnmodifiableListView<CookHistory> get history =>
      UnmodifiableListView(_history);

  // === Cart ===
  final Map<String, int> _cart = {};               // menuId -> qty
  UnmodifiableMapView<String, int> get cart =>
      UnmodifiableMapView(_cart);

  // === Cook Sessions（由購物車生成的多菜歷史） ===
  final List<CookSession> _sessions = [];
  UnmodifiableListView<CookSession> get sessions => UnmodifiableListView(_sessions);

  void addSessionFromCartSnapshot(Map<String, int> snapshot, int totalMinutes) {
    _sessions.insert(0, CookSession(
      completedAt: DateTime.now(),
      items: Map<String, int>.from(snapshot), // 存副本
      totalMinutes: totalMinutes,
    ));
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

  // 教學模式設定
  bool strictMode = true; // 嚴格模式：需跑完計時才能下一步
  int timeScale = 10; // 1 分鐘 = 10 秒（示範友好）

  // --- 新增 setter，避免在 UI 直接呼叫 notifyListeners() ---
  void setStrictMode(bool v) {
    strictMode = v;
    notifyListeners();
  }

  void setTimeScale(int v) {
    timeScale = v;
    notifyListeners();
  }

  void addIngredients(Iterable<String> names) {
    final lower = names.map((e) => e.toLowerCase().trim());
    final set = _ingredients.map((e) => e.toLowerCase()).toSet();
    bool changed = false;
    for (final n in lower) {
      if (!set.contains(n)) {
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
    strictMode = true;
    timeScale = 10;
    notifyListeners();
  }
}

class CookSession {
  final DateTime completedAt;
  final Map<String, int> items; // menuId -> qty
  final int totalMinutes;
  CookSession({
    required this.completedAt,
    required this.items,
    required this.totalMinutes,
  });
}

class CookHistory {
  final String title;
  final String cover;
  final DateTime completedAt;
  CookHistory({required this.title, required this.cover, required this.completedAt});
}

/// --------------------------- Theme & App --------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF22C55E);
    return MaterialApp(
      debugShowCheckedModeBanner: false, // ← 關掉右上角 DEBUG 標籤
      title: 'FoodLens',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

/// === 共用外框：統一頁面最大寬度、置中、標準 Padding ===
const double kPageMaxWidth = 1000; // 你可改成 960/1100 等

class PageFrame extends StatelessWidget {
  final Widget child;
  const PageFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kPageMaxWidth),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// --------------------------- Login --------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 0)),
    );
  }

  void _comingSoon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what — coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.restaurant_menu, size: 72, color: Colors.white70),
                  const SizedBox(height: 12),
                  //  App 名稱
                  const Text(
                    'CookCam AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  //  App 名稱 end
                  const SizedBox(height: 6),
                  const Text('Welcome',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  // Email / Password
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter email';
                            final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                            if (!re.hasMatch(v.trim())) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                              tooltip: _obscure ? 'Show' : 'Hide',
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.length < 4) ? 'At least 4 characters' : null,
                          onFieldSubmitted: (_) {
                            if (_formKey.currentState!.validate()) _goHome();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Email/Password Login
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _goHome(); // demo: login success
                      }
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Log in'),
                  ),

                  const SizedBox(height: 8),

                  // Google Login（示範，未串真登入）
                  OutlinedButton.icon(
                    onPressed: _goHome,
                    icon: const Icon(Icons.account_circle),
                    label: const Text('Continue with Google'),
                  ),

                  const SizedBox(height: 12),

                  // --- New: secondary actions (pure UI) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => _comingSoon('Create new account'),
                        child: const Text('Create new account'),
                      ),
                      TextButton(
                        onPressed: () => _comingSoon('Forgot password'),
                        child: const Text('Forgot password'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    ' ',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// --------------------------- Home + BottomNav ----------------------------
class HomeShell extends StatefulWidget {
  final int initialIndex;                         // ⭐ 新增
  const HomeShell({super.key, this.initialIndex = 0});

  @override
  State<HomeShell> createState() => _HomeShellState();
}


class _HomeShellState extends State<HomeShell> {
  late int _index;                                // ⭐ 改用 late

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;                 // ⭐ 用參數初始化
  }

  final _pages = const [
    AiCameraPage(),
    HistoryPage(),
    SettingsPage(),
  ];
  final _titles = const ['AI Camera', 'History', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.9, -1.0),
          radius: 1.3,
          colors: [Color(0xFF0EA5E9), Color(0xFF0B0F14)],
          stops: [0.0, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(_titles[_index]),
          actions: const [SizedBox(width: 8)],
        ),
        // ⭐ 所有分頁都經過 PageFrame → 統一寬度、置中
        body: PageFrame(child: _pages[_index]),
        bottomNavigationBar: NavigationBar(
          height: 64,
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.photo_camera_outlined), selectedIcon: Icon(Icons.photo_camera), label: 'AI Camera'),
            NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history_toggle_off), label: 'History'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

/// --------------------------- Sample Data ---------------------------------
class Recipe {
  final String menuId;
  final String name;
  final String type; // 中式 / 西式 / 日式 / 泰式
  final List<String> taste; // 口味標籤
  final List<String> ingredientsRequired;
  final String cover;
  final List<RecipeStep> steps;
  const Recipe({
    required this.menuId,
    required this.name,
    required this.type,
    required this.taste,
    required this.ingredientsRequired,
    required this.cover,
    required this.steps,
  });
}

class RecipeStep {
  final String text;
  final int durationMin;
  const RecipeStep(this.text, this.durationMin);
}

const List<Recipe> kRecipes = [
  Recipe(
    menuId: 'r1',
    name: 'Tomato & Egg Stir-fry',
    type: 'Chinese',
    taste: ['Savory', 'Slightly Sweet'],
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
    taste: ['Refreshing', 'Sweet & Sour'],
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

// 快速查表
final Map<String, Recipe> kRecipeById = {
  for (final r in kRecipes) r.menuId: r
};

/// 所有可能的食材（方便模擬偵測）
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
].toList()..sort();

// ---------- 額外資訊對照表
const Map<String, int> kRecipeServings = {
  'r1': 2, 'r2': 2, 'r3': 2, 'r4': 3, 'r5': 2,
};

const Map<String, int> kRecipeDifficulty = {
  'r1': 2, 'r2': 3, 'r3': 1, 'r4': 3, 'r5': 2,
};

const Map<String, String> kRecipeMethod = {
  'r1': 'Stir-fry', 'r2': 'Sear/Sauté', 'r3': 'Tossed', 'r4': 'Stir-fry', 'r5': 'Boil/Toss',
};

/// 已知調味料 key（其餘視為主料）
const Set<String> kSeasoningKeys = {
  'salt', 'pepper', 'soy_sauce', 'sugar', 'vinegar', 'oil',
};

/// 食材預設數量（沒有列到的就顯示「適量」）
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

/// 單份菜單所需調味料折算（「茶匙」為單位）
const Map<String, double> kSeasoningTeaspoons = {
  'salt': 0.5,
  'pepper': 0.25,
  'soy_sauce': 3.0, // 1 湯匙 = 3 茶匙
  'sugar': 1.0,
  'vinegar': 3.0,   // 1 湯匙
  'oil': 3.0,       // 1 湯匙
};

/// 簡短賣點（可自由增修）
const Map<String, List<String>> kSellingPoints = {
  'r1': ['Quick Home-Style', 'High-Protein, Low-Cost', 'One-pan meal'],
  'r2': ['Garlicky & Rich', 'Surf & Turf', 'Great with drinks or rice'],
  'r3': ['Low-cal & Refreshing', 'Done in 5 minutes', 'Appetizing side'],
  'r4': ['Spicy & great with rice', 'Fragrant Thai basil', 'Perfect with white rice'],
  'r5': ['Herb-fresh', 'One-pot', 'Quick Dinner'],
};

/// 詳細步驟（若無對應就用短步驟代替）
const Map<String, List<String>> kStepsVerbose = {
  'r1': [
    'Wash tomatoes and cut into large chunks.',
    'Beat the eggs, add a little water (about 2–3 tsp) and mix.',
    'Heat wok with oil, pour in egg mixture and stir-fry on high heat until about 70% done. Set aside.',
    'Stir-fry tomatoes briefly, then add salt, water and sugar to cook.',
    'When tomatoes soften, add tomato paste and a bit of cornstarch slurry, return eggs and stir-fry until cooked.',
  ],
};

/// 計算配料匹配/缺少
MatchResult computeMatch(Recipe recipe, List<String> detected) {
  final set = detected.toSet();
  final match = <String>[];
  final missing = <String>[];
  for (final i in recipe.ingredientsRequired) {
    if (set.contains(i)) {
      match.add(i);
    } else {
      missing.add(i);
    }
  }
  return MatchResult(match: match, missing: missing);
}

class MatchResult {
  final List<String> match;
  final List<String> missing;
  const MatchResult({required this.match, required this.missing});
}

/// --------------------------- Page: AI Camera ------------------------------
class AiCameraPage extends StatefulWidget {
  const AiCameraPage({super.key});
  @override
  State<AiCameraPage> createState() => _AiCameraPageState();
}

class _AiCameraPageState extends State<AiCameraPage> {
  String _previewHint = 'No image captured';

  // 模擬偵測：隨機取 1~4 個食材
  List<String> _detectMock() {
    final rnd = Random();
    final count = 1 + rnd.nextInt(4);
    final list = [...kAllIngredients]..shuffle(rnd);
    return list.take(count).toList();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    const cardAspect = 4 / 5; // 手機優先：相機卡片稍高，避免擠爆

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // 相機卡片
          _glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('Camera'),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: cardAspect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        border: Border.all(color: Colors.white24),
                      ),
                      // ⭐ 卡片內部可直向捲動
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: _cameraInner(app),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 食物紀錄表（與相機卡片上下排）
          _FoodListPanel(app: app),
        ],
      ),
    );
  }

  Widget _cameraInner(AppState app) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.photo_camera, size: 48, color: Colors.white70),
          const SizedBox(height: 8),
          Text(_previewHint, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() => _previewHint = 'Image captured'),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Capture image'),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  final res = _detectMock();
                  if (res.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (_) => _DetectionDialog(
                        detections: res,
                        onConfirm: () {
                          app.addIngredients(res);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Realtime recognition'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _previewHint = 'No image captured'),
                icon: const Icon(Icons.refresh),
                label: const Text('Retake'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const SizedBox.shrink(), // 提示先隱藏
        ],
      ),
    );
  }
}

class _FoodListPanel extends StatelessWidget {
  final AppState app;
  const _FoodListPanel({required this.app});

  @override
  Widget build(BuildContext context) {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Food Log'),
          const Text('Names only (no quantity). Duplicates removed automatically.', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 10),

          if (app.ingredients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No records yet', style: TextStyle(color: Colors.white70)),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final i in app.ingredients)
                  Chip(
                    backgroundColor: Colors.white12,
                    side: const BorderSide(color: Colors.white24),
                    label: Text(i),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => app.removeIngredient(i),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
              ],
            ),

          const SizedBox(height: 12),

          // ⭐ 按鈕列：自適應寬度，必要時自動換行
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              // 依容器寬度決定每顆按鈕寬度：小螢幕 1 欄 / 中等 2 欄 / 大螢幕 3 欄
              double btnW;
              if (w < 340) {
                btnW = w; // 1 欄，滿版
              } else if (w < 520) {
                btnW = (w - 8) / 2; // 2 欄
              } else {
                btnW = (w - 16) / 3; // 3 欄
              }

              ButtonStyle styleFor(bool filled) => (filled
                      ? FilledButton.styleFrom
                      : ElevatedButton.styleFrom)(
                    minimumSize: Size(btnW, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  );

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  // 新增
                  SizedBox(
                    width: btnW,
                    child: ElevatedButton.icon(
                      style: styleFor(false),
                      onPressed: () async {
                        final picked = await Navigator.push<List<String>>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IngredientPickerPage(
                              all: kAllIngredients,
                              existing: app.ingredients.toSet(),
                            ),
                          ),
                        );
                        if (picked != null && picked.isNotEmpty) {
                          app.addIngredients(picked);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ),

                  // 確定食材 → 菜單推介
                  SizedBox(
                    width: btnW,
                    child: FilledButton.icon(
                      style: styleFor(true),
                      onPressed: app.ingredients.isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RecommendScreen(),
                                ),
                              );
                            },
                      icon: const Icon(Icons.check),
                      label: const Text('Menu Suggestions'),
                    ),
                  ),

                  // 清空
                  SizedBox(
                    width: btnW,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: Size(btnW, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        backgroundColor: Colors.red.shade200.withValues(alpha: 0.2),
                      ),
                      onPressed: app.ingredients.isEmpty ? null : app.clearIngredients,
                      icon: const Icon(Icons.delete),
                      label: const Text('Clear'),
                    ),
                  ),
                ],
              );
            },
          ),

        ],
      ),
    );
  }
}

// ===================== 全螢幕多選清單：IngredientPickerPage =====================
class IngredientPickerPage extends StatefulWidget {
  final List<String> all;     // 全部可選食材
  final Set<String> existing; // 已在清單中的（顯示為已有且不可選）

  const IngredientPickerPage({
    super.key,
    required this.all,
    required this.existing,
  });

  @override
  State<IngredientPickerPage> createState() => _IngredientPickerPageState();
}

class _IngredientPickerPageState extends State<IngredientPickerPage> {
  final Set<String> selected = {}; // 本頁選取中的
  String query = '';

  List<String> get _filtered {
    if (query.trim().isEmpty) return widget.all;
    final q = query.toLowerCase();
    return widget.all.where((x) => x.toLowerCase().contains(q)).toList();
  }

  void _toggle(String name) {
    if (widget.existing.contains(name)) return; // 已有的不能改
    setState(() {
      if (selected.contains(name)) {
        selected.remove(name);
      } else {
        selected.add(name);
      }
    });
  }

  void _selectAllFiltered() {
    setState(() {
      for (final n in _filtered) {
        if (!widget.existing.contains(n)) selected.add(n);
      }
    });
  }

  void _clearSelection() {
    setState(() => selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Items (selected ${selected.length} ）'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _clearSelection,
            child: const Text('Clear Selection'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜尋框
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              decoration: _inputDecoration('Search ingredients', icon: Icons.search),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          // 快速操作
          // 快速操作（✅ 解法 A：Wrap + LayoutBuilder，自動換行不爆版）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                // 依寬度決定每顆按鈕的寬度：1 / 2 / 3 欄
                double btnW;
                if (w < 360) {
                  btnW = w;                     // 一欄（滿版）
                } else if (w < 560) {
                  btnW = (w - 8) / 2;           // 兩欄
                } else {
                  btnW = (w - 16) / 3;          // 三欄
                }

                final outlinedStyle = OutlinedButton.styleFrom(
                  minimumSize: Size(btnW, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: const StadiumBorder(),
                );

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: btnW,
                      child: OutlinedButton.icon(
                        style: outlinedStyle,
                        onPressed: _selectAllFiltered,
                        icon: const Icon(Icons.select_all),
                        // 長字串避免擠爆：單行＋省略號
                        label: const Text(
                          'Select filtered results',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: btnW,
                      child: OutlinedButton.icon(
                        style: outlinedStyle,
                        onPressed: _clearSelection,
                        icon: const Icon(Icons.clear_all),
                        label: const Text(
                          'Clear Selection',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // 顯示目前結果數（同樣佔一格，必要時會換行）
                    SizedBox(
                      width: btnW,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_filtered.length} items',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          // 清單
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final name = _filtered[i];
                final disabled = widget.existing.contains(name);
                final checked = selected.contains(name);
                return CheckboxListTile(
                  title: Text(name),
                  subtitle: disabled
                      ? const Text('Already in list', style: TextStyle(color: Colors.white60))
                      : null,
                  value: disabled ? true : checked,
                  onChanged: disabled ? null : (_) => _toggle(name),
                  controlAffinity: ListTileControlAffinity.trailing,
                  secondary: disabled
                      ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                      : const Icon(Icons.add_circle_outline),
                );
              },
            ),
          ),
        ],
      ),
      // 底部「確定」按鈕（SafeArea）
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: selected.isEmpty
              ? null
              : () => Navigator.pop(context, selected.toList()),
          icon: const Icon(Icons.check),
          label: const Text('Add Selected'),
        ),
      ),
    );
  }
}

class _DetectionDialog extends StatelessWidget {
  final List<String> detections;
  final VoidCallback onConfirm;
  const _DetectionDialog({required this.detections, required this.onConfirm});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Detection Result'),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final d in detections) Chip(label: Text(d))],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Retake')),
        ElevatedButton(onPressed: onConfirm, child: const Text('Confirm')),
      ],
    );
  }
}

/// --------------------------- Page: Recommend ------------------------------
class RecommendPage extends StatefulWidget {
  const RecommendPage({super.key});
  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  String typeFilter = 'All';
  String tasteFilter = 'All';
  String search = '';
  bool onlyFav = false; // 只顯示最愛

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final detected = app.ingredients;

    final list = kRecipes
        .map((r) => (recipe: r, mr: computeMatch(r, detected)))
        .toList()
      ..sort((a, b) => a.mr.missing.length.compareTo(b.mr.missing.length));

    final types = ['All', ...{for (final r in kRecipes) r.type}];
    final tastes = ['All', ...{for (final r in kRecipes) ...r.taste}];
    // 最愛集合（即時跟隨變更）
    final favSet = context.watch<AppState>().favorites;

    final filtered = list.where((e) {
      if (typeFilter != 'All' && e.recipe.type != typeFilter) return false;
      if (tasteFilter != 'All' && !e.recipe.taste.any((t) => t.contains(tasteFilter))) return false;
      if (search.trim().isNotEmpty) {
        final s = search.toLowerCase();
        if (!e.recipe.name.toLowerCase().contains(s) &&
            !e.recipe.ingredientsRequired.any((i) => i.toLowerCase().contains(s))) return false;
      }
      // 勾了「只顯示最愛」時，只保留在最愛清單中的菜單
      if (onlyFav && !favSet.contains(e.recipe.menuId)) return false;

      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;

        // 一欄式：上面篩選、下面 Grid
        final cols = w >= 1200 ? 3 : w >= 800 ? 2 : 1;

        // ★ 計算每格寬/高（固定高度，避免卡片內容撐爆）
        const spacing = 12.0;
        final tileW = (w - (cols - 1) * spacing) / cols;
        final coverH = tileW * 9 / 16;
        final baseInfoH = cols == 1 ? 230.0 : (cols == 2 ? 220.0 : 210.0);
        final tileH = coverH + baseInfoH;

        final filterPanel = _glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('Filters'),
              const SizedBox(height: 8),
              _filterChips(
                label: 'Cuisine Type',
                values: types,
                current: typeFilter,
                onChanged: (v) => setState(() => typeFilter = v),
              ),
              const SizedBox(height: 8),
              _filterChips(
                label: 'Taste',
                values: tastes,
                current: tasteFilter,
                onChanged: (v) => setState(() => tasteFilter = v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Show Favorites Only'),
                    selected: onlyFav,
                    onSelected: (v) => setState(() => onlyFav = v),
                    selectedColor: Colors.amber.withValues(alpha: .2),
                    checkmarkColor: Colors.amber,
                    side: const BorderSide(color: Colors.white24),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => setState(() => search = v),
                decoration: _inputDecoration('Enter ingredient or dish', icon: Icons.search),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sort: "All ingredients available" first, then by missing count (few → many).',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        );

        final grid = GridView.builder(
          shrinkWrap: true,
          primary: false, // 外層捲動
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: tileH, // ★ 固定卡片高度
          ),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _RecipeCard(
            recipe: filtered[i].recipe,
            mr: filtered[i].mr,
          ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              filterPanel,
              const SizedBox(height: 12),
              grid,
            ],
          ),
        );
      },
    );
  }


  Widget _filterChips({
    required String label,
    required List<String> values,
    required String current,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(v),
                selected: v == current,
                onSelected: (_) => onChanged(v),
                labelStyle: TextStyle(color: v == current ? Colors.black : Colors.white),
                selectedColor: Colors.white,
                backgroundColor: Colors.white12,
                side: const BorderSide(color: Colors.white24),
              ),
          ],
        ),
      ],
    );
  }
}

// 右上角收藏星星（灰白＝未收藏；黃色＝已收藏）
class FavoriteStar extends StatelessWidget {
  final String menuId;
  const FavoriteStar({super.key, required this.menuId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<AppState>().toggleFavorite(menuId),
      child: Selector<AppState, bool>(
        selector: (_, s) => s.favorites.contains(menuId),
        builder: (_, fav, __) => CircleAvatar(
          radius: 16,
          backgroundColor: fav ? Colors.black45 : Colors.black26,
          child: Icon(
            fav ? Icons.star : Icons.star_border,
            color: fav ? Colors.amber : Colors.white70,
            size: 18,
          ),
        ),
      ),
    );
  }
}

//-------顯示詳細頁-------start----------------
void _showRecipeDetailSheet(BuildContext context, Recipe recipe, MatchResult mr) {
  final totalMin = recipe.steps.fold<int>(0, (s, st) => s + st.durationMin);
  final servings = kRecipeServings[recipe.menuId] ?? 2;
  final difficulty = kRecipeDifficulty[recipe.menuId] ?? 2;
  final method = kRecipeMethod[recipe.menuId] ?? '—';
  final selling = kSellingPoints[recipe.menuId] ?? ['Quick to Table', 'Easy-to-find Ingredients', 'Home-style Flavor'];
  final verbose = kStepsVerbose[recipe.menuId] ?? recipe.steps.map((e) => e.text).toList();

  final mainIngr = <MapEntry<String, String>>[];
  final seasonings = <MapEntry<String, String>>[];
  for (final key in recipe.ingredientsRequired) {
    final qty = kQtyDefaults[key] ?? 'to taste';
    if (kSeasoningKeys.contains(key)) {
      seasonings.add(MapEntry(key, qty));
    } else {
      mainIngr.add(MapEntry(key, qty));
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    enableDrag: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,                     // 底層容器透明
    barrierColor: Colors.black.withValues(alpha: 0.7),       // ⭐ 更深的遮罩，不會透字
    builder: (ctx) {
      final h = MediaQuery.of(ctx).size.height;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            constraints: BoxConstraints(maxHeight: h * 0.94),
            // ⭐ 詳細頁本體改成「實心深色」卡片（不再太透明）
            decoration: BoxDecoration(
              color: const Color(0xFF111318),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== 頂部封面 + 返回箭咀（左上角） =====
                    Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(recipe.cover, fit: BoxFit.cover),
                        ),
                        Positioned(
                          left: 8, top: 8,
                          child: Material(
                            color: Colors.black.withValues(alpha: .45),
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(ctx),      // ⭐ 返回
                              tooltip: 'Back',
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ===== 內容 =====
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 標題 + 難度星星
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  recipe.name,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < difficulty ? Icons.star : Icons.star_border,
                                    color: Colors.amber, size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 賣點
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: [
                              for (final s in selling)
                                Chip(
                                  label: Text(s),
                                  backgroundColor: Colors.white12,
                                  side: const BorderSide(color: Colors.white24),
                                  labelStyle: const TextStyle(color: Colors.white),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 基本資訊
                          Wrap(
                            spacing: 12, runSpacing: 8,
                            children: [
                              _kv('Cuisine', recipe.type),
                              _kv('Taste', recipe.taste.join(' / ')),
                              _kv('Method', method),
                              _kv('Difficulty', '$difficulty / 5'),
                              _kv('Servings', '$servings servings'),
                              _kv('Total Time', '$totalMin min'),
                              _kv('Ingredient Completeness', '${mr.match.length}/${recipe.ingredientsRequired.length}'),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 主料
                          _sectionTitle('Main Ingredients'),
                          const SizedBox(height: 6),
                          _qtyList(mainIngr),
                          const SizedBox(height: 12),

                          // 調味料
                          _sectionTitle('Seasoning'),
                          const SizedBox(height: 6),
                          _qtyList(seasonings),
                          const SizedBox(height: 14),

                          // 詳細步驟
                          _sectionTitle('Detailed Steps'),
                          const SizedBox(height: 6),
                          for (int i = 0; i < verbose.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text('${i + 1}. ${verbose[i]}'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

// 小工具：標題
Widget _sectionTitle(String t) => Text(
      t,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );

// 小工具：key-value 標籤
Widget _kv(String k, String v) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text('$k：$v', style: const TextStyle(fontSize: 12)),
    );

// 小工具：數量清單
Widget _qtyList(List<MapEntry<String, String>> items) {
  if (items.isEmpty) {
    return const Text('—', style: TextStyle(color: Colors.white70));
  }
  return Column(
    children: [
      for (final e in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(_prettyName(e.key))),
              Text(e.value, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
    ],
  );
}

// 把 key 變得好看一點
String _prettyName(String key) {
  switch (key) {
    case 'soy_sauce': return 'Soy sauce';
    case 'sesame': return 'Sesame';
    case 'pasta': return 'Pasta';
    default: return key.replaceAll('_', ' ');
  }
}
//-------顯示詳細頁-------end----------------

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final MatchResult mr;
  final bool readOnly;     // 購物車頁用 true → 不顯示 +/−
  final int? qtyForCart;   // 購物車頁顯示數量徽章
  final bool showMatchLines;  // ⭐ 是否顯示「Already/Missing」
  final bool showProgress;    // ⭐ 是否顯示進度條
  // 封面長寬比（預設 16:9）
  final double coverAspect;
  // 緊湊模式（縮小內邊距/間距）
  final bool compact;

  const _RecipeCard({
    required this.recipe,
    required this.mr,
    this.readOnly = false,
    this.qtyForCart,
    this.showMatchLines = true,   // 預設顯示
    this.showProgress = true,     // 預設顯示
    this.coverAspect = 16 / 9, // 預設不變
    this.compact = false,      // 預設關閉
  });

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final ratio = mr.match.length / recipe.ingredientsRequired.length;

    final count = context.select<AppState, int>(
      (s) => s.cartCountOf(recipe.menuId),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onLongPress: () => _showRecipeDetailSheet(context, recipe, mr), // ⭐ 長按詳情
      child: _glass(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面 + 左上齊全徽章 + 右上收藏星星 +（購物車模式顯示 xN 徽章）
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: coverAspect,
                    child: Image.network(recipe.cover, fit: BoxFit.cover),
                  ),
                  Positioned(
                    left: 8, top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54, borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${mr.match.length}/${recipe.ingredientsRequired.length} complete',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8, top: 8,
                    child: FavoriteStar(menuId: recipe.menuId),
                  ),
                  if (readOnly && (qtyForCart ?? 0) > 0)
                    Positioned(
                      right: 8, bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54, borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('x${qtyForCart!}'),
                      ),
                    ),
                ],
              ),
            ),

            // 資訊區
            Padding(
              padding: compact
                ? const EdgeInsets.fromLTRB(12, 6, 12, 8)   //  緊湊
                : const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${recipe.type} ・ ${recipe.taste.join('/ ')}',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Already 行
                  if (showMatchLines) ...[
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Already: ', style: TextStyle(fontSize: 12)),
                          TextSpan(
                            text: mr.match.join(', ').isEmpty ? '—' : mr.match.join(', '),
                            style: const TextStyle(fontSize: 12, color: Color(0xFFBBF7D0)),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                  ],
                  //  Missing 行
                  if (showMatchLines) ...[
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Missing: ', style: TextStyle(fontSize: 12)),
                          TextSpan(
                            text: mr.missing.join(', ').isEmpty ? '—' : mr.missing.join(', '),
                            style: const TextStyle(fontSize: 12, color: Color(0xFFFECACA)),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (showMatchLines) const SizedBox(height: 10),
                  //  進度條
                  if (showProgress) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: mr.match.length / recipe.ingredientsRequired.length,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ⭐ 這裡用 +/− 控制數量；在購物車頁（readOnly=true）就不顯示
                  if (!readOnly)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 減一（保持不變）
                        IconButton.filledTonal(
                          onPressed: count > 0 ? () => app.addToCart(recipe.menuId, -1) : null,
                          icon: const Icon(Icons.remove),
                          tooltip: 'Decrease 1',
                          // 讓大小一致、易點（可選）
                          style: IconButton.styleFrom(
                            fixedSize: const Size(40, 40),
                            padding: EdgeInsets.zero,
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '$count',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),

                        // ⭐ 加一（改成只有 + 圖示的按鈕）
                        IconButton.filled(
                          onPressed: () => app.addToCart(recipe.menuId, 1), // 別寫 +1，寫 1
                          icon: const Icon(Icons.add),
                          tooltip: 'Increase 1',
                          style: IconButton.styleFrom(
                            fixedSize: const Size(40, 40),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  // 原本的「開始烹飪」按鈕暫時移除
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 菜單推介（可返回的全螢幕頁面；用 PageFrame 同步寬度）
class RecommendScreen extends StatelessWidget {
  const RecommendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ingredients = app.ingredients;

    // 先找出購物車中所有（數量 > 0）的菜單所用到的食材集合
    final usedIngredients = <String>{};
    app.cart.forEach((menuId, qty) {
      if (qty > 0) {
        final r = kRecipeById[menuId]; // ← 如果你已建立過這個 map
        if (r != null) usedIngredients.addAll(r.ingredientsRequired);
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Menu Suggestions'),
      ),
      body: PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 頂部：顯示「食物紀錄表」的食材（寬度固定，高度隨內容）
            SizedBox(
              width: double.infinity,
              child: _glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title('Current ingredients（${ingredients.length}）'),
                    if (ingredients.isEmpty)
                      const Text(
                        'No ingredients added yet. Please go back to add or detect.',
                        style: TextStyle(color: Colors.white70),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.start,
                        children: [
                          for (final i in ingredients)
                            Chip(
                              label: Text(
                                i,
                                style: TextStyle(
                                  // 被任何「已加入購物車（數量>0）」的菜單使用 → 綠色；否則紅色
                                  color: usedIngredients.contains(i) ? Colors.greenAccent : Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: usedIngredients.contains(i)
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.red.withValues(alpha: 0.15),
                              side: BorderSide(
                                color: usedIngredients.contains(i)
                                    ? Colors.green.withValues(alpha: 0.4)
                                    : Colors.red.withValues(alpha: 0.4),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Expanded(child: RecommendPage()),
          ],
        ),
      ),
      // ⭐ 新增購物車 FAB（圓形）
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartScreen()),
          );
        },
        child: const Icon(Icons.shopping_cart),
      ),
    );
  }
}

// 購物車頁
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cart = app.cart;
    final detected = app.ingredients;

    final entries = [
      for (final e in cart.entries)
        (recipe: kRecipeById[e.key]!, qty: e.value, mr: computeMatch(kRecipeById[e.key]!, detected)),
    ];

    // === 底部「生成」按鈕（空購物車時禁用） ===
    void onGeneratePressed() {
      // 計算彙總
      final snapshot = Map<String, int>.from(app.cart); // 拍快照
      final totalDishes = snapshot.values.fold<int>(0, (s, v) => s + v);
      int totalMinutes = 0;

      // 主料（唯一集合）與調味料（茶匙彙總）
      final Set<String> mainAll = {};
      final Map<String, double> seasonTsp = {};

      snapshot.forEach((menuId, qty) {
        final r = kRecipeById[menuId]!;
        totalMinutes += qty * r.steps.fold<int>(0, (s, st) => s + st.durationMin);
        for (final ing in r.ingredientsRequired) {
          if (kSeasoningKeys.contains(ing)) {
            final add = (kSeasoningTeaspoons[ing] ?? 1.0) * qty;
            seasonTsp[ing] = (seasonTsp[ing] ?? 0) + add;
          } else {
            mainAll.add(ing);
          }
        }
      });

      // 顏色邏輯：使用者食材紀錄表（擁有 = 綠；缺少 = 紅）
      final have = app.ingredients.toSet();
      final mainGreen = [for (final m in mainAll) if (have.contains(m)) m]..sort();
      final mainRed   = [for (final m in mainAll) if (!have.contains(m)) m]..sort();

      final seasonKeys = seasonTsp.keys.toList()..sort();
      final seasonGreen = [for (final s in seasonKeys) if (have.contains(s)) s];
      final seasonRed   = [for (final s in seasonKeys) if (!have.contains(s)) s];

      final totalSeasonTsp = seasonTsp.values.fold<double>(0, (s, v) => s + v);

      // 顯示確認彈窗
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Confirm Generation'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 彙總統計
                  _kv('Total Menus', '$totalDishes dishes'),
                  const SizedBox(height: 4),
                  _kv('Total Time', '$totalMinutes min'),
                  const SizedBox(height: 4),
                  _kv('Total ingredient types', '${mainAll.length} types'),
                  const SizedBox(height: 4),
                  _kv('Total seasoning (tsp)', totalSeasonTsp.toStringAsFixed(1)),
                  const SizedBox(height: 12),

                  // 主料：綠在上、紅在下
                  _sectionTitle('Main Ingredients'),
                  const SizedBox(height: 6),
                  if (mainGreen.isNotEmpty)
                    Text('Have:${mainGreen.map(_prettyName).join(', ')}',
                        style: const TextStyle(color: Colors.greenAccent)),
                  if (mainRed.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Missing:${mainRed.map(_prettyName).join(', ')}',
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                  const SizedBox(height: 12),

                  // 調味料：帶茶匙數，綠在上、紅在下
                  _sectionTitle('Seasoning (tsp)'),
                  const SizedBox(height: 6),
                  if (seasonGreen.isNotEmpty)
                    Text(
                      'Have:' +
                          seasonGreen
                              .map((k) => '${_prettyName(k)} ${seasonTsp[k]!.toStringAsFixed(1)}tsp')
                              .join(', '),
                      style: const TextStyle(color: Colors.greenAccent),
                    ),
                  if (seasonRed.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Missing:' +
                            seasonRed
                                .map((k) => '${_prettyName(k)} ${seasonTsp[k]!.toStringAsFixed(1)}tsp')
                                .join(', '),
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Text('(Amounts are estimated)', style: TextStyle(fontSize: 12, color: Colors.white60)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx), // 取消 → 回購物車頁
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // 關彈窗

                  // a) 拍下購物車快照 + 計總分鐘
                  final snapshot = Map<String, int>.from(app.cart);
                  final int totalMinutesPlanned = snapshot.entries.fold(0, (sum, e) {
                    final r = kRecipeById[e.key]!;
                    final per = r.steps.fold<int>(0, (s, st) => s + st.durationMin);
                    return sum + per * e.value;
                  });

                  // b) 立刻清空購物車與食材紀錄表（依你的要求）
                  context.read<AppState>().clearCart();
                  context.read<AppState>().clearIngredients();

                  // c) 進入「多菜同步逐步教學」頁
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MultiCookScreen(
                        snapshot: snapshot,                // menuId -> qty
                        totalPlannedMinutes: totalMinutesPlanned,
                      ),
                    ),
                  );
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Cart')),
      body: PageFrame(
        child: entries.isEmpty
            ? _glass(child: const Text('No menu items added yet.', style: TextStyle(color: Colors.white70)))
            : LayoutBuilder(
                builder: (_, c) {
                  final w = c.maxWidth;
                  final cols = w >= 1200 ? 3 : w >= 800 ? 2 : 1;
                  const spacing = 12.0;
                  final tileW = (w - (cols - 1) * spacing) / cols;
                  final coverH = tileW * 9 / 16;
                  final baseInfoH = cols == 1 ? 230.0 : (cols == 2 ? 220.0 : 210.0);
                  final tileH = coverH + baseInfoH;

                  final grid = GridView.builder(
                    shrinkWrap: true,
                    primary: false,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      mainAxisExtent: tileH,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (_, i) => _RecipeCard(
                      recipe: entries[i].recipe,
                      mr: entries[i].mr,
                      readOnly: true,
                      qtyForCart: entries[i].qty,
                    ),
                  );

                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(children: [grid]),
                  );
                },
              ),
      ),
      // ⭐ 底部生成按鈕（空購物車時禁用）
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: app.cart.isEmpty ? null : onGeneratePressed,
          icon: const Icon(Icons.playlist_add_check),
          label: const Text('Generate'),
        ),
      ),
    );
  }
}

// ===================== MultiCookScreen：多菜同步逐步教學 =====================
class MultiCookScreen extends StatefulWidget {
  final Map<String, int> snapshot;          // menuId -> qty（已拍快照）
  final int totalPlannedMinutes;            // 預估總時間（分）
  const MultiCookScreen({
    super.key,
    required this.snapshot,
    required this.totalPlannedMinutes,
  });

  @override
  State<MultiCookScreen> createState() => _MultiCookScreenState();
}

enum TaskStatus { waiting, running, paused, done }

class _PlanTask {
  final String id;                 // 唯一id
  final String recipeId;
  final String recipeName;
  final int copyIndex;             // 第幾份（1..qty）
  final int stepIndex;             // 第幾步（0-based）
  final String text;
  final int secondsTotal;          // 總秒數
  int secondsLeft;                 // 剩餘秒數
  TaskStatus status;
  Timer? timer;

  _PlanTask({
    required this.id,
    required this.recipeId,
    required this.recipeName,
    required this.copyIndex,
    required this.stepIndex,
    required this.text,
    required this.secondsTotal,
  })  : secondsLeft = secondsTotal,
        status = TaskStatus.waiting;
}

class _MultiCookScreenState extends State<MultiCookScreen> {
  final List<_PlanTask> _tasks = [];
  bool _allCompletedSnackShown = false;

  AppState get app => context.read<AppState>();
  int get scale => context.read<AppState>().timeScale; // 1分=scale秒

  @override
  void initState() {
    super.initState();
    _buildPlan();
  }

  @override
  void dispose() {
    for (final t in _tasks) {
      t.timer?.cancel();
    }
    super.dispose();
  }

  void _buildPlan() {
    // 依 snapshot 展開所有菜單與數量 → 任務清單（每份菜的每一步都成為一個任務）
    int seq = 0;
    widget.snapshot.forEach((menuId, qty) {
      final r = kRecipeById[menuId]!;
      for (int c = 1; c <= qty; c++) {
        for (int i = 0; i < r.steps.length; i++) {
          final st = r.steps[i];
          final secs = max(1, st.durationMin * scale);
          _tasks.add(_PlanTask(
            id: 't${seq++}',
            recipeId: r.menuId,
            recipeName: r.name,
            copyIndex: c,
            stepIndex: i,
            text: st.text,
            secondsTotal: secs,
          ));
        }
      }
    });
    // 預設不排序，維持「先展開的先顯示」。你也可以改排序規則。
    setState(() {});
  }

  void _startTask(_PlanTask t) {
    if (t.status == TaskStatus.running) return;
    t.timer?.cancel();
    t.status = TaskStatus.running;
    t.timer = Timer.periodic(const Duration(seconds: 1), (tm) {
      if (!mounted) return;
      if (t.secondsLeft <= 0) {
        tm.cancel();
        t.status = TaskStatus.done;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Done:${t.recipeName} #${t.copyIndex}｜ Step ${t.stepIndex + 1}')),
        );
        setState(() {});
        _checkAllDone();
      } else {
        setState(() => t.secondsLeft--);
      }
    });
    setState(() {});
  }

  void _pauseTask(_PlanTask t) {
    if (t.status != TaskStatus.running) return;
    t.timer?.cancel();
    t.status = TaskStatus.paused;
    setState(() {});
  }

  void _resetTask(_PlanTask t) {
    t.timer?.cancel();
    t.secondsLeft = t.secondsTotal;
    t.status = TaskStatus.waiting;
    setState(() {});
  }

  void _completeTask(_PlanTask t) {
    t.timer?.cancel();
    t.secondsLeft = 0;
    t.status = TaskStatus.done;
    setState(() {});
    _checkAllDone();
  }

  void _checkAllDone() {
    if (_tasks.every((t) => t.status == TaskStatus.done)) {
      if (_allCompletedSnackShown) return;
      _allCompletedSnackShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All steps complete! Tap "Finish Lesson" to end this session.')),
      );
    }
  }

  int get _runningCount => _tasks.where((t) => t.status == TaskStatus.running).length;
  int get _waitingCount => _tasks.where((t) => t.status == TaskStatus.waiting).length;
  int get _doneCount    => _tasks.where((t) => t.status == TaskStatus.done).length;

  Future<void> _finishAndSaveHistory() async {
    // 產生「Session 歷史」：使用原本 snapshot（在進入頁面前已清空 AppState.cart/ingredients）
    app.addSessionFromCartSnapshot(widget.snapshot, widget.totalPlannedMinutes);

    // 回到 AI 攝影（用 HomeShell 的 initialIndex=0）
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 0)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _tasks.where((t) => t.status == TaskStatus.waiting).toList();
    final running = _tasks.where((t) => t.status == TaskStatus.running || t.status == TaskStatus.paused).toList();
    final done    = _tasks.where((t) => t.status == TaskStatus.done).toList();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Sync Step-by-Step'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('Wait:${_waitingCount}｜Run:${_runningCount}｜Done:${_doneCount}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ),
          ),
        ],
      ),
      body: PageFrame(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              _glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title('Help'),
                    const Text(
                      'You can run multiple timers: e.g. while "Boiling water" runs, you can start "Chopping";'
                      'You\'ll be prompted when any timer completes. When all steps are done, tap "Finish Lesson" to end.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 正在進行 / 已暫停
              if (running.isNotEmpty) ...[
                _title('Running'),
                const SizedBox(height: 6),
                for (final t in running) _taskCard(t, running: true),
                const SizedBox(height: 12),
              ],

              // 待開始
              _title('Waiting'),
              const SizedBox(height: 6),
              if (waiting.isEmpty)
                _glass(child: const Text('No steps waiting to start', style: TextStyle(color: Colors.white70)))
              else
                for (final t in waiting) _taskCard(t),

              const SizedBox(height: 12),

              // 已完成（可收納）
              if (done.isNotEmpty) ...[
                _title('Done'),
                const SizedBox(height: 6),
                for (final t in done) _taskCard(t, done: true),
              ],
            ],
          ),
        ),
      ),

      // 底部大按鈕
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: _tasks.isNotEmpty && _tasks.every((t) => t.status == TaskStatus.done)
              ? _finishAndSaveHistory
              : null,
          icon: const Icon(Icons.flag),
          label: const Text('Finish Lesson'),
        ),
      ),
    );
  }

  Widget _taskCard(_PlanTask t, {bool running = false, bool done = false}) {
    Color barColor;
    if (done) {
      barColor = Colors.greenAccent;
    } else if (running) {
      barColor = Colors.amber;
    } else {
      barColor = Colors.white24;
    }

    final progress = 1 - (t.secondsLeft / max(1, t.secondsTotal));

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${t.recipeName} #${t.copyIndex}｜Step ${t.stepIndex + 1}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(t.text),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress, minHeight: 8, color: barColor),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Left：${t.secondsLeft}s', style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              if (!running && !done)
                ElevatedButton.icon(
                  onPressed: () => _startTask(t),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
              if (running && !done) ...[
                IconButton.filledTonal(
                  onPressed: () => _pauseTask(t),
                  icon: const Icon(Icons.pause),
                  tooltip: 'Pause',
                ),
                IconButton.filledTonal(
                  onPressed: () => _resetTask(t),
                  icon: const Icon(Icons.replay),
                  tooltip: 'Reset',
                ),
                IconButton.filled(
                  onPressed: () => _completeTask(t),
                  icon: const Icon(Icons.check),
                  tooltip: 'Finish',
                ),
              ],
              if (done)
                const Icon(Icons.check_circle, color: Colors.greenAccent),
            ],
          ),
        ],
      ),
    );
  }
}

//--新增的「歷史詳細頁」
class SessionDetailScreen extends StatelessWidget {
  final CookSession session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final detected = context.watch<AppState>().ingredients; // 此時通常已清空
    final entries = [
      for (final e in session.items.entries)
        (recipe: kRecipeById[e.key]!, qty: e.value, mr: computeMatch(kRecipeById[e.key]!, detected)),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('History Details｜${entries.fold<int>(0, (s, e) => s + e.qty)} dishes・${session.totalMinutes} min'),
      ),
      body: PageFrame(
        child: LayoutBuilder(
          builder: (_, c) {
            final w = c.maxWidth;
            final cols = w >= 1200 ? 3 : w >= 800 ? 2 : 1;
            const spacing = 12.0;
            final tileW = (w - (cols - 1) * spacing) / cols;

            //  改用更扁的封面比例（21:9），讓封面更矮
            const aspect = 21 / 9;
            final coverH = tileW / aspect;

            //  已拿掉 Already/Missing + 進度條，資訊區可以很小
            final baseInfoH = cols == 1 ? 110.0 : (cols == 2 ? 104.0 : 98.0);

            // 固定卡片高度（避免各裝置溢位）
            final tileH = coverH + baseInfoH;

            final grid = GridView.builder(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                mainAxisExtent: tileH, // 用上面算好的更矮高度
              ),
              itemCount: entries.length,
              itemBuilder: (_, i) => _RecipeCard(
                recipe: entries[i].recipe,
                mr: entries[i].mr,
                readOnly: true,
                qtyForCart: entries[i].qty,
                showMatchLines: false,   // 歷史頁不顯示
                showProgress: false,     // 歷史頁不顯示
                coverAspect: aspect,     // 傳入更扁的比例
                compact: true,           // 開啟緊湊模式（縮 padding）
              ),
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _glass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _title('Summary'),
                        Text(
                          'Completed at：${session.completedAt}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Menu count：${entries.fold<int>(0, (s, e) => s + e.qty)} dishes, total time：${session.totalMinutes} min',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  grid,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
/// --------------------------- Page: Favorites ------------------------------
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final favIds = context.watch<AppState>().favorites;
    final favList = kRecipes.where((r) => favIds.contains(r.menuId)).toList();
    if (favList.isEmpty) {
      return _glass(child: const Text('No favorite menus yet.', style: TextStyle(color: Colors.white70)));
    }
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;                          // 已經經過 PageFrame 限制
        final cols = w >= 1100 ? 3 : w >= 750 ? 2 : 1; // ⭐ 響應式欄數
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.86,
          ),
          itemCount: favList.length,
          itemBuilder: (_, i) {
            final r = favList[i];
            return _glass(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(r.cover, fit: BoxFit.cover),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${r.type} ・ ${r.taste.join('/ ')}',
                            style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// --------------------------- Page: History --------------------------------
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<AppState>().sessions;
    if (sessions.isNotEmpty) {
      return ListView.separated(
        itemCount: sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final s = sessions[i];
          final totalMenus = s.items.values.fold<int>(0, (sum, v) => sum + v);
          // 取第一道菜的封面當縮圖（若有）
          String? cover;
          if (s.items.isNotEmpty) {
            final firstId = s.items.keys.first;
            cover = kRecipeById[firstId]?.cover;
          }
          return InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s)),
            ),
            child: _glass(
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  if (cover != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                      child: SizedBox(
                        width: 140,
                        height: 90,
                        child: Image.network(cover!, fit: BoxFit.cover),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cooking Log', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Completed at：${s.completedAt}',
                              style: const TextStyle(fontSize: 12, color: Colors.white70)),
                          Text('Menu：$totalMenus dishes • Total time：${s.totalMinutes} min',
                              style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // 若沒有 Session 歷史，回退到你原本的單菜歷史 UI
    final list = context.watch<AppState>().history;
    if (list.isEmpty) {
      return _glass(child: const Text('No menus completed yet.', style: TextStyle(color: Colors.white70)));
    }
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final cols = w >= 1100 ? 3 : w >= 750 ? 2 : 1;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.86,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final h = list[i];
            return _glass(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(h.cover, fit: BoxFit.cover),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Finished on ${h.completedAt}',
                            style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// --------------------------- Page: Settings -------------------------------
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    // final app = context.watch<AppState>();
    // 包可捲動，避免窄螢幕溢位
    return SingleChildScrollView(
      child: Column(
        children: [
          // _glass(
          //   child: Row(
          //     children: [
          //       const Expanded(
          //         child: ListTile(
          //           title: Text('嚴格模式'),
          //           subtitle: Text('需完成計時才能進入下一步'),
          //         ),
          //       ),
          //       Switch(
          //         value: app.strictMode,
          //         onChanged: context.read<AppState>().setStrictMode,
          //       ),
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 12),
          // _glass(
          //   child: Row(
          //     children: [
          //       const Expanded(
          //         child: ListTile(
          //           title: Text('示範時間倍率'),
          //           subtitle: Text('1 分鐘 = X 秒'),
          //         ),
          //       ),
          //       DropdownButton<int>(
          //         value: app.timeScale,
          //         items: const [
          //           DropdownMenuItem(value: 5, child: Text('5 秒/分')),
          //           DropdownMenuItem(value: 10, child: Text('10 秒/分')),
          //           DropdownMenuItem(value: 15, child: Text('15 秒/分')),
          //         ],
          //         onChanged: (v) {
          //           if (v != null) context.read<AppState>().setTimeScale(v);
          //         },
          //       ),
          //       const SizedBox(width: 12),
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 12),
          _glass(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade200.withValues(alpha: .2),
                ),
                onPressed: () => context.read<AppState>().resetAll(),
                icon: const Icon(Icons.delete),
                label: const Text('Reset all data'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// --------------------------- Cooking Screen -------------------------------
class CookingScreen extends StatefulWidget {
  final Recipe recipe;
  const CookingScreen({super.key, required this.recipe});
  @override
  State<CookingScreen> createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen> {
  int index = 0;
  int secondsLeft = 0;
  Timer? _timer;

  AppState get app => context.read<AppState>();

  @override
  void initState() {
    super.initState();
    _loadStep(0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadStep(int i) {
    index = i;
    secondsLeft = widget.recipe.steps[i].durationMin * app.timeScale;
    _timer?.cancel();
    setState(() {});
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  void _pause() => _timer?.cancel();

  @override
  Widget build(BuildContext context) {
    final step = widget.recipe.steps[index];
    final total = widget.recipe.steps.length;
    final canNext = !app.strictMode || secondsLeft == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cooking Lesson：${widget.recipe.name}'),
      ),
      body: PageFrame(
        child: _glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Step ${index + 1} / $total', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(step.text, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('Suggested ${step.durationMin} min (demo scale ${app.timeScale} sec/min）',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (step.durationMin * app.timeScale - secondsLeft) /
                      max(1, step.durationMin * app.timeScale),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 6),
              Text('Time left：${secondsLeft}s', style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              Wrap(
                spacing: 10,
                children: [
                  ElevatedButton(onPressed: _start, child: const Text('Start')),
                  OutlinedButton(onPressed: _pause, child: const Text('Pause')),
                  OutlinedButton(
                    onPressed: index == 0 ? null : () => setState(() => _loadStep(index - 1)),
                    child: const Text('Previous'),
                  ),
                  ElevatedButton(
                    onPressed: canNext
                        ? () {
                            if (index + 1 < total) {
                              setState(() => _loadStep(index + 1));
                            } else {
                              Navigator.pop(context, true); // 完成
                            }
                          }
                        : null,
                    child: Text(index + 1 < total ? 'Next' : 'Finish'),
                  ),
                ],
              ),
              if (!canNext)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('（Strict mode: finish current timer before next step）',
                      style: TextStyle(fontSize: 12, color: Colors.white60)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// --------------------------- UI Helpers -----------------------------------
Widget _glass({required Widget child, EdgeInsets padding = const EdgeInsets.all(14)}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      // withOpacity → withValues，避免棄用警告
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white24),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: -8)],
    ),
    child: child,
  );
}

InputDecoration _inputDecoration(String hint, {IconData? icon}) {
  return InputDecoration(
    prefixIcon: icon == null ? null : Icon(icon),
    hintText: hint,
    filled: true,
    fillColor: Colors.white12,
    hintStyle: const TextStyle(color: Colors.white60),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white24)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white24)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white)),
  );
}

Widget _title(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    );
