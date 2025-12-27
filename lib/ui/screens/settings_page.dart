// lib/ui/screens/settings_page.dart
// Settings Page（設定頁）
// 用途：
// - 放置全局設定 / Debug 操作
// - 目前只有 Reset all data（清空 ingredients / favorites / history / sessions / cart 等）

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/glass.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          glass(
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