// lib/ui/screens/ai_camera_page.dart
// AI Camera Page（食材掃描頁）
// 用途：
// - 模擬相機介面（目前為 placeholder）
// - 提供 Capture（模擬拍照）與 Upload image（觸發偵測）按鈕
// - 偵測後彈出 DetectionDialog 確認
// - 底部顯示目前食材清單（FoodListPanel）

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/ingredients_meta.dart';
import '../../state/app_state.dart';
import '../widgets/detection_dialog.dart';
import '../widgets/food_list_panel.dart';
import '../widgets/glass.dart';
import '../widgets/ui_helpers.dart';

class AiCameraPage extends StatefulWidget {
  const AiCameraPage({super.key});

  @override
  State<AiCameraPage> createState() => _AiCameraPageState();
}

class _AiCameraPageState extends State<AiCameraPage> {
  String _previewHint = 'No image captured';

  List<String> _detectMock() {
    // demo: fixed sample（保持原始固定結果）
    final raw = <String>['egg', 'tomato'];
    return raw.where((x) => !kSeasoningKeys.contains(x)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    const cardAspect = 4 / 5;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // 相機區
          glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleText('Camera'),
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

          // 食材清單面板
          FoodListPanel(app: app),
        ],
      ),
    );
  }

  Widget _cameraInner(AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 預覽區
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black26,
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image, size: 48, color: Colors.white30),
                const SizedBox(height: 6),
                Text(_previewHint, style: const TextStyle(color: Colors.white60)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 操作按鈕
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            ElevatedButton.icon(
              onPressed: () => setState(() => _previewHint = 'Captured'),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Capture'),
            ),

            FilledButton.tonalIcon(
              onPressed: () {
                final res = _detectMock();
                if (res.isNotEmpty) {
                  showDialog(
                    context: context,
                    builder: (_) => DetectionDialog(
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
              label: const Text('Upload image'),
            ),

            // 保留原始隱藏的 Retake（不顯示但保留程式碼）
            Visibility(
              visible: false,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _previewHint = 'No image captured'),
                icon: const Icon(Icons.refresh),
                label: const Text('Retake'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}