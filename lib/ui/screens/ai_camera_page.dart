// lib/ui/screens/ai_camera_page.dart
// AI Camera Page（模擬偵測食材）
// 用途：
// - 模擬拍照 / 偵測一批食材（mock）
// - 把偵測結果寫入 AppState.ingredients
// - 顯示偵測結果對話框 + 下方 FoodListPanel（目前已加入的食材清單）

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/recipe_meta.dart';
import '../../state/app_state.dart';
import '../widgets/detection_dialog.dart';
import '../widgets/food_list_panel.dart';
import '../widgets/glass.dart';

class AiCameraPage extends StatefulWidget {
  const AiCameraPage({super.key});

  @override
  State<AiCameraPage> createState() => _AiCameraPageState();
}

class _AiCameraPageState extends State<AiCameraPage> {
  bool _busy = false;

  // mock 偵測：回傳一批「可能偵測到的食材」
  Future<List<String>> _detectMock() async {
    await Future.delayed(const Duration(milliseconds: 500));

    // 你可以按需要改呢個 mock list
    const raw = <String>[
      'egg',
      'tomato',
      'onion',
      'garlic',
      'salt',
      'black_pepper',
      'soy_sauce',
    ];

    // 過濾掉調味料（只保留主食材）
    return raw.where((x) => !kSeasoningKeys.contains(x)).toList();
  }

  Future<void> _onDetectPressed(AppState app) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final detected = await _detectMock();

      // 寫入 AppState
      app.addIngredients(detected);

      if (!mounted) return;

      // 彈出偵測結果視窗
      showDialog(
        context: context,
        builder: (_) => DetectionDialog(detected: detected),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Column(
      children: [
        glass(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Mock AI Camera',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _onDetectPressed(app),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                  label: const Text('Detect'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ✅ FoodListPanel 本身唔收 app:，佢內部自己 watch AppState
        const FoodListPanel(),
      ],
    );
  }
}