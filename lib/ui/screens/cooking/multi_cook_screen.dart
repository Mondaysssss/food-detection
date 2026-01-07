// [OOP] MultiCookScreen：多菜入口頁
// 現在改做「轉去 CookFlowScreen」(多菜都用同一個一頁式 UI)

import 'package:flutter/material.dart';

import 'cook_flow_screen.dart';

class MultiCookScreen extends StatelessWidget {
  final Map<String, int> snapshot;
  final int totalPlannedMinutes;

  const MultiCookScreen({
    super.key,
    required this.snapshot,
    required this.totalPlannedMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return CookFlowScreen(
      snapshot: snapshot,
      totalPlannedMinutes: totalPlannedMinutes,
    );
  }
}
