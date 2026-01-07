// [OOP] MultiCookScreen：
// 舊版係「多菜同時多個 timer」UI。
// 依家改為：直接委派到 CookFlowScreen（單頁完成：icon + step + 右邊菜單 + bottom sheet）。

import 'package:flutter/material.dart';

import 'cook_flow_screen.dart';

class MultiCookScreen extends StatelessWidget {
  final Map<String, int> snapshot;
  final int totalPlannedMinutes;

  const MultiCookScreen({super.key, required this.snapshot, required this.totalPlannedMinutes});

  @override
  Widget build(BuildContext context) {
    return CookFlowScreen(snapshot: snapshot, totalPlannedMinutes: totalPlannedMinutes);
  }
}
