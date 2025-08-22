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
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.8, -1.0),
          radius: 1.2,
          colors: [Color(0xFF1E293B), Color(0xFF0B0F14)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22D3EE), Color(0xFFA78BFA)],
                  ),
                ),
                child: const Icon(Icons.restaurant_menu, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text('FoodLens', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('AI 食材辨識・離線菜單・逐步教學', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeShell()),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('使用 Google 登入（示範）'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// --------------------------- Home + BottomNav ----------------------------
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _pages = const [
    AiCameraPage(),
    HistoryPage(),
    SettingsPage(),
  ];
  final _titles = const ['AI 攝影', '歷史', '設定'];

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
            NavigationDestination(icon: Icon(Icons.photo_camera_outlined), selectedIcon: Icon(Icons.photo_camera), label: 'AI 攝影'),
            NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history_toggle_off), label: '歷史'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '設定'),
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
    name: '番茄炒蛋',
    type: '中式',
    taste: ['鮮', '微甜'],
    ingredientsRequired: ['tomato', 'egg', 'salt', 'oil'],
    cover: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?q=80&w=1200&auto=format&fit=crop',
    steps: [
      RecipeStep('切番茄', 3),
      RecipeStep('熱鍋下油', 2),
      RecipeStep('下蛋快炒', 2),
      RecipeStep('加番茄調味', 3),
    ],
  ),
  Recipe(
    menuId: 'r2',
    name: '蒜香牛油蝦',
    type: '西式',
    taste: ['香', '鹹'],
    ingredientsRequired: ['shrimp', 'garlic', 'butter', 'salt', 'pepper'],
    cover: 'https://images.unsplash.com/photo-1604908178196-1c9c1c9d9c36?q=80&w=1200&auto=format&fit=crop',
    steps: [
      RecipeStep('解凍去腸線', 4),
      RecipeStep('牛油熱鍋爆香蒜蓉', 2),
      RecipeStep('下蝦煎至轉色', 4),
    ],
  ),
  Recipe(
    menuId: 'r3',
    name: '和風沙律',
    type: '日式',
    taste: ['清爽', '酸甜'],
    ingredientsRequired: ['lettuce', 'tomato', 'cucumber', 'sesame', 'soy_sauce', 'vinegar', 'oil'],
    cover: 'https://images.unsplash.com/photo-1490474418585-ba9bad8fd0ea?q=80&w=1200&auto=format&fit=crop',
    steps: [
      RecipeStep('洗切菜', 3),
      RecipeStep('調和和風汁', 2),
      RecipeStep('拌勻撒芝麻', 2),
    ],
  ),
  Recipe(
    menuId: 'r4',
    name: '泰式打拋豬',
    type: '泰式',
    taste: ['辣', '香'],
    ingredientsRequired: ['pork', 'basil', 'garlic', 'chili', 'soy_sauce', 'sugar', 'oil'],
    cover: 'https://images.unsplash.com/photo-1544025162-d76694265947?q=80&w=1200&auto=format&fit=crop',
    steps: [
      RecipeStep('爆香蒜辣椒', 2),
      RecipeStep('下豬肉炒散', 4),
      RecipeStep('調味加九層塔拌勻', 2),
    ],
  ),
  Recipe(
    menuId: 'r5',
    name: '青醬蘑菇意粉',
    type: '西式',
    taste: ['香草', '鹹'],
    ingredientsRequired: ['pasta', 'mushroom', 'basil', 'garlic', 'oil', 'salt'],
    cover: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?q=80&w=1200&auto=format&fit=crop',
    steps: [
      RecipeStep('煮意粉', 6),
      RecipeStep('炒香蒜蓉蘑菇', 3),
      RecipeStep('加入青醬拌勻', 2),
    ],
  ),
];

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
  String _previewHint = '尚未擷取影像';

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
                _title('相機功能（示範，未接真相機）'),
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
                onPressed: () => setState(() => _previewHint = '已擷取影像（示範圖）'),
                icon: const Icon(Icons.photo_camera),
                label: const Text('擷取影像（示範）'),
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
                label: const Text('即時辨識（模擬）'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _previewHint = '尚未擷取影像'),
                icon: const Icon(Icons.refresh),
                label: const Text('重拍'),
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
          _title('食物紀錄表'),
          const Text('僅保存名稱（不含數量）。同名自動去重。', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 10),

          if (app.ingredients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('尚未有紀錄', style: TextStyle(color: Colors.white70)),
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
                      label: const Text('新增'),
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
                      label: const Text('確定食材'),
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
                      label: const Text('清空'),
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
        title: Text('新增食物（已選 ${selected.length} 項）'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _clearSelection,
            child: const Text('清除選取'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜尋框
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              decoration: _inputDecoration('搜尋食材', icon: Icons.search),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          // 快速操作
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _selectAllFiltered,
                  icon: const Icon(Icons.select_all),
                  label: const Text('選取篩選結果'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('清除選取'),
                ),
                const Spacer(),
                Text('${_filtered.length} 筆',
                    style: const TextStyle(color: Colors.white70)),
              ],
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
                      ? const Text('已在清單中', style: TextStyle(color: Colors.white60))
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
          label: const Text('確定加入'),
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
      title: const Text('偵測結果（模擬）'),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final d in detections) Chip(label: Text(d))],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('重拍')),
        ElevatedButton(onPressed: onConfirm, child: const Text('確認加入')),
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
  String typeFilter = '全部';
  String tasteFilter = '全部';
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

    final types = ['全部', ...{for (final r in kRecipes) r.type}];
    final tastes = ['全部', ...{for (final r in kRecipes) ...r.taste}];
    // 最愛集合（即時跟隨變更）
    final favSet = context.watch<AppState>().favorites;

    final filtered = list.where((e) {
      if (typeFilter != '全部' && e.recipe.type != typeFilter) return false;
      if (tasteFilter != '全部' && !e.recipe.taste.any((t) => t.contains(tasteFilter))) return false;
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
              _title('篩選'),
              const SizedBox(height: 8),
              _filterChips(
                label: '菜式類型',
                values: types,
                current: typeFilter,
                onChanged: (v) => setState(() => typeFilter = v),
              ),
              const SizedBox(height: 8),
              _filterChips(
                label: '口味',
                values: tastes,
                current: tasteFilter,
                onChanged: (v) => setState(() => tasteFilter = v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('只顯示最愛'),
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
                decoration: _inputDecoration('輸入食材或菜名', icon: Icons.search),
              ),
              const SizedBox(height: 8),
              const Text(
                '排序：先「食材齊全」，再依缺料數（少→多）。',
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

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final MatchResult mr;
  const _RecipeCard({required this.recipe, required this.mr});
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final ratio = mr.match.length / recipe.ingredientsRequired.length;
    return _glass(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // cover
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(recipe.cover, fit: BoxFit.cover),
                ),
                // 左上角：齊全徽章
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${mr.match.length}/${recipe.ingredientsRequired.length} 齊全',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                // 右上角：收藏星星
                Positioned(
                  right: 8,
                  top: 8,
                  child: FavoriteStar(menuId: recipe.menuId),
                ),
              ],
            ),
          ),
          // info
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                          Text('${recipe.type} ・ ${recipe.taste.join('/ ')}',
                              style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '已有：', style: TextStyle(fontSize: 12)),
                      TextSpan(text: mr.match.join(', ').isEmpty ? '—' : mr.match.join(', '),
                          style: const TextStyle(fontSize: 12, color: Color(0xFFBBF7D0))),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '缺少：', style: TextStyle(fontSize: 12)),
                      TextSpan(text: mr.missing.join(', ').isEmpty ? '—' : mr.missing.join(', '),
                          style: const TextStyle(fontSize: 12, color: Color(0xFFFECACA))),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: ratio, minHeight: 8),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    final done = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => CookingScreen(recipe: recipe)),
                    );
                    if (done == true) {
                      app.addHistory(recipe);
                    }
                  },
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('開始烹飪'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 菜單推介（可返回的全螢幕頁面；用 PageFrame 同步寬度）
class RecommendScreen extends StatelessWidget {
  const RecommendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ingredients = context.watch<AppState>().ingredients;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('菜單推介'),
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
                    _title('目前食材（${ingredients.length}）'),
                    if (ingredients.isEmpty)
                      const Text(
                        '尚未加入任何食材，請回上一頁新增或偵測。',
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
                              label: Text(i),
                              backgroundColor: Colors.white12,
                              side: const BorderSide(color: Colors.white24),
                              labelStyle: const TextStyle(color: Colors.white),
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
      return _glass(child: const Text('目前沒有最愛菜單。', style: TextStyle(color: Colors.white70)));
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
    final list = context.watch<AppState>().history;
    if (list.isEmpty) {
      return _glass(child: const Text('尚未完成任何菜單。', style: TextStyle(color: Colors.white70)));
    }
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final cols = w >= 1100 ? 3 : w >= 750 ? 2 : 1; // ⭐ 響應式欄數
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
                        Text('完成於 ${h.completedAt}',
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
    final app = context.watch<AppState>();
    // 包可捲動，避免窄螢幕溢位
    return SingleChildScrollView(
      child: Column(
        children: [
          _glass(
            child: Row(
              children: [
                const Expanded(
                  child: ListTile(
                    title: Text('嚴格模式'),
                    subtitle: Text('需完成計時才能進入下一步'),
                  ),
                ),
                Switch(
                  value: app.strictMode,
                  onChanged: context.read<AppState>().setStrictMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _glass(
            child: Row(
              children: [
                const Expanded(
                  child: ListTile(
                    title: Text('示範時間倍率'),
                    subtitle: Text('1 分鐘 = X 秒'),
                  ),
                ),
                DropdownButton<int>(
                  value: app.timeScale,
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5 秒/分')),
                    DropdownMenuItem(value: 10, child: Text('10 秒/分')),
                    DropdownMenuItem(value: 15, child: Text('15 秒/分')),
                  ],
                  onChanged: (v) {
                    if (v != null) context.read<AppState>().setTimeScale(v);
                  },
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _glass(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade200.withValues(alpha: .2),
                ),
                onPressed: () => context.read<AppState>().resetAll(),
                icon: const Icon(Icons.delete),
                label: const Text('重置所有示範資料'),
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
        title: Text('烹飪教學：${widget.recipe.name}'),
      ),
      body: PageFrame(
        child: _glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('步驟 ${index + 1} / $total', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(step.text, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('建議 ${step.durationMin} 分鐘（示範倍率 ${app.timeScale} 秒/分）',
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
              Text('剩餘時間：${secondsLeft}s', style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              Wrap(
                spacing: 10,
                children: [
                  ElevatedButton(onPressed: _start, child: const Text('開始')),
                  OutlinedButton(onPressed: _pause, child: const Text('暫停')),
                  OutlinedButton(
                    onPressed: index == 0 ? null : () => setState(() => _loadStep(index - 1)),
                    child: const Text('上一步'),
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
                    child: Text(index + 1 < total ? '下一步' : '完成'),
                  ),
                ],
              ),
              if (!canNext)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('（嚴格模式：需完成當前計時才能進入下一步）',
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
