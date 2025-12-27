// lib/ui/widgets/page_frame.dart
// PageFrame：統一頁面最大寬度 + 置中 + SafeArea + Padding
// 好處：你任何頁面 UI 都唔會「一頁爆版一頁唔爆」，保持一致。


import 'package:flutter/material.dart';

const double kPageMaxWidth = 1000;

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