// lib/ui/screens/ingredient_picker_page.dart
// Ingredient Picker Page（手動補充食材多選頁）
// 用途：
// - 從所有食材中搜尋並多選（自動排除調味料與已存在的食材）
// - 已存在食材顯示為 disabled + 提示
// - 支援 Select filtered / Clear selection
// - 確認後回傳新增的食材列表

import 'package:flutter/material.dart';

import '../../data/ingredients_meta.dart';
import '../widgets/ui_helpers.dart';

class IngredientPickerPage extends StatefulWidget {
  final List<String> all;
  final Set<String> existing;

  const IngredientPickerPage({
    super.key,
    required this.all,
    required this.existing,
  });

  @override
  State<IngredientPickerPage> createState() => _IngredientPickerPageState();
}

class _IngredientPickerPageState extends State<IngredientPickerPage> {
  final Set<String> selected = {};
  String query = '';

  List<String> get _allFoodOnly => widget.all.where((x) => !kSeasoningKeys.contains(x)).toList();

  List<String> get _filtered {
    if (query.trim().isEmpty) return _allFoodOnly;
    final q = query.toLowerCase();
    return _allFoodOnly.where((x) => x.toLowerCase().contains(q)).toList();
  }

  void _toggle(String name) {
    if (widget.existing.contains(name)) return;
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
        if (!widget.existing.contains(n)) {
          selected.add(n);
        }
      }
    });
  }

  void _clearSelection() => setState(() => selected.clear());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add items (selected ${selected.length})'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Close',
        ),
        actions: [
          TextButton(
            onPressed: _clearSelection,
            child: const Text('Clear selection'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜尋欄
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              decoration: inputDecoration('Search ingredients', icon: Icons.search),
              onChanged: (v) => setState(() => query = v),
            ),
          ),

          // 輔助按鈕列
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                double btnW;
                if (w < 360) {
                  btnW = w;
                } else if (w < 560) {
                  btnW = (w - 8) / 2;
                } else {
                  btnW = (w - 16) / 3;
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
                        label: const Text('Select filtered', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    SizedBox(
                      width: btnW,
                      child: OutlinedButton.icon(
                        style: outlinedStyle,
                        onPressed: _clearSelection,
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear selection', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    SizedBox(
                      width: btnW,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('${_filtered.length} items', style: const TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),

          // 食材列表
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
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: selected.isEmpty ? null : () => Navigator.pop(context, selected.toList()),
          icon: const Icon(Icons.check),
          label: const Text('Add selected'),
        ),
      ),
    );
  }
}