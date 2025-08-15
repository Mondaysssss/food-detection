import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:collection'; // 為了使用 UnmodifiableListView

// ===================== 狀態：AI 辨識食物清單（Provider 管理） =====================
class FoodState extends ChangeNotifier {
  final List<String> _recognizedFoods = []; // 私有清單
  UnmodifiableListView<String> get recognizedFoods =>
      UnmodifiableListView(_recognizedFoods);

  // 新增一個食物名稱（模擬 AI 辨識結果）
  void addFood(String foodName) {
    // 避免重覆紀錄相同食物（若你需要）
    if (!_recognizedFoods.contains(foodName)) {
      _recognizedFoods.add(foodName);
      notifyListeners(); // 通知 UI 更新
    }
  }

  // 依索引刪除一筆
  void removeFoodAt(int index) {
    if (index >= 0 && index < _recognizedFoods.length) {
      _recognizedFoods.removeAt(index);
      notifyListeners();
    }
  }

  // 清空全部
  void clearFoods() {
    _recognizedFoods.clear();
    notifyListeners();
  }
}

// ===================== App 入口 =====================
void main() {
  runApp(
    // 把 FoodState 提供給整個應用
    ChangeNotifierProvider(
      create: (_) => FoodState(),
      child: const MyApp(),
    ),
  );
}

// ===================== MyApp：主題 / 路由起點 =====================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Menu App',
      theme: ThemeData(
        // 主題：綠色＋圓角按鈕
        primarySwatch: Colors.green,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20), // 圓角
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.green,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ===================== Login 畫面 =====================
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 簡潔的登入畫面：按一下就進 Home（未實作真登入）
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // 用 pushReplacement 防止返回到 Login
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          },
          child: const Text('Login with Google'),
        ),
      ),
    );
  }
}

// ===================== Home 畫面 =====================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 這裡僅作為導航入口
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiCameraScreen()),
                );
              },
              child: const Text('AI Camera'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MenuScreen()),
                );
              },
              child: const Text('Generate Menu'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== AI 攝影介面（紀錄清單 / 新增 / 清除） =====================
class AiCameraScreen extends StatelessWidget {
  const AiCameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final foods = context.watch<FoodState>().recognizedFoods; // 監聽清單變化

    return Scaffold(
      appBar: AppBar(title: const Text('AI Camera')),
      body: Column(
        children: [
          // 操作列：新增 / 清空
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CameraScreen()),
                    );
                  },
                  child: const Text('Add Food'),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.read<FoodState>().clearFoods();
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ),
          // 清單：顯示已紀錄的食物名稱
          Expanded(
            child: foods.isEmpty
                ? const Center(
                    child: Text('No food recognized yet.'),
                  )
                : ListView.builder(
                    itemCount: foods.length,
                    itemBuilder: (_, index) {
                      final name = foods[index];
                      return ListTile(
                        title: Text(name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            context.read<FoodState>().removeFoodAt(index);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ===================== 相機功能（UI Mock：確認 / 重拍） =====================
class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 真實相機未接；這裡只做畫面示意
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 90, color: Colors.grey),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // 模擬 AI 認出一個新食物：Food N
                    final state = context.read<FoodState>();
                    final nextIdx = state.recognizedFoods.length + 1;
                    state.addFood('Food $nextIdx'); // 新增假資料
                    Navigator.pop(context); // 回到 AI 攝影介面
                  },
                  child: const Text('Confirm'),
                ),
                const SizedBox(width: 32),
                ElevatedButton(
                  onPressed: () {
                    // 重拍：此範例不做事（保留空動作）
                  },
                  child: const Text('Retake'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== 食譜模型（假資料用） =====================
class Recipe {
  final String title; // 菜名
  final int missingCount; // 缺少食材數量（0 = 齊全）
  final List<RecipeStep> steps; // 步驟
  Recipe(this.title, this.missingCount, this.steps);
}

class RecipeStep {
  final String instruction; // 步驟文字
  final int minutes; // 需時（分鐘）
  RecipeStep(this.instruction, this.minutes);
}

// ===================== 生成菜單介面（排序：齊全 > 缺1 > 缺2） =====================
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 假資料（可改為從 assets/json 載入）
    final recipes = <Recipe>[
      Recipe('Salad', 0, [
        RecipeStep('Chop vegetables', 5),
        RecipeStep('Mix ingredients', 2),
      ]),
      Recipe('Pasta', 2, [
        RecipeStep('Boil water', 10),
        RecipeStep('Cook pasta', 8),
        RecipeStep('Drain and serve', 1),
      ]),
      Recipe('Omelette', 1, [
        RecipeStep('Beat eggs', 3),
        RecipeStep('Cook in pan', 5),
      ]),
    ];

    // 依缺料數排序：0(齊全) → 1 → 2
    recipes.sort((a, b) => a.missingCount.compareTo(b.missingCount));

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView.builder(
        itemCount: recipes.length,
        itemBuilder: (_, index) {
          final r = recipes[index];
          return ListTile(
            title: Text(r.title),
            subtitle: Text(
              r.missingCount == 0
                  ? 'All ingredients available'
                  : 'Missing ${r.missingCount} ingredient(s)',
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InstructionScreen(recipe: r)),
              );
            },
          );
        },
      ),
    );
  }
}

// ===================== 烹飪教學介面（下一步流程） =====================
class InstructionScreen extends StatefulWidget {
  final Recipe recipe;
  const InstructionScreen({super.key, required this.recipe});

  @override
  State<InstructionScreen> createState() => _InstructionScreenState();
}

class _InstructionScreenState extends State<InstructionScreen> {
  int _currentStep = 0; // 目前步驟索引

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final steps = recipe.steps;
    final total = steps.length;
    final current = steps[_currentStep];

    return Scaffold(
      appBar: AppBar(title: Text('${recipe.title} Recipe')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題：第幾步 / 總步數
            Text(
              'Step ${_currentStep + 1} of $total',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // 步驟說明
            Text(current.instruction, style: const TextStyle(fontSize: 16)),
            // 需時
            Text('Time: ${current.minutes} min',
                style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            const Spacer(),
            // 下一步 / 完成
            Center(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    if (_currentStep < total - 1) {
                      _currentStep++;
                    } else {
                      Navigator.pop(context); // 完成後返回
                    }
                  });
                },
                child: Text(_currentStep < total - 1 ? 'Next Step' : 'Finish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}