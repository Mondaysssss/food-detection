// [OOP] MultiCookScreen: multi-dish entry page
// Now redirects to CookFlowScreen (both single and multi-dish share the same one-page UI)

import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/screens/cooking/cook_flow_screen.dart';

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
      titleOverride: 'Multi-cook',
    );
  }
}
