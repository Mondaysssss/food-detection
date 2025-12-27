// lib/ui/screens/ingredient_picker_page.dart
// Ingredient Picker Page（手動揀食材頁）
// 用途：
// - 顯示全部食材清單（widget.all）
// - 用戶可以勾選/取消勾選
// - Confirm 後把選中的食材寫入 AppState.ingredients

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/recipe_meta.dart';
import '../../state/app_state.dart';
import '../widgets/glass.dart';

class IngredientPickerPage extends StatefulWidget {
  final List<String> all;
  const IngredientPickerPage({super.key, required this.all});

  @override
  State<IngredientPickerPage> createState() => _IngredientPickerPageState();
}

class _IngredientPickerPageState extends State<IngredientPickerPage> {
  final Set<String> _selected = {};

  // 只顯示「主食材」，唔顯示調味料
  List<String> get _allFoodOnly => widget.all.where((x) => !kSeasoningKeys.contains(x)).toList();

  @override
  void initState() {
    super.initState();
    // 初始選中：AppState 已有的 ingredients
    final app = context.read<AppState>();
    _selected.addAll(app.ingredients);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final list = _allFoodOnly;

    return Scaffold(
      appBar: AppBar(title: const Text('Pick ingredients')),
      body: glass(
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final key = list[i];
            final checked = _selected.contains(key);

            return CheckboxListTile(
              value: checked,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.add(key);
                  } else {
                    _selected.remove(key);
                  }
                });
              },
              title: Text(key, style: const TextStyle(color: Colors.white)),
              controlAffinity: ListTileControlAffinity.leading,
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: ElevatedButton(
          onPressed: () {
            app.setIngredients(_selected.toList());
            Navigator.pop(context);
          },
          child: const Text('Confirm'),
        ),
      ),
    );
  }
}