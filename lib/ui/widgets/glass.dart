// [OOP] 共用元件：玻璃磨砂卡片樣式（半透明背景）。

import 'package:flutter/material.dart';

Widget glass({
  required Widget child,
  EdgeInsets padding = const EdgeInsets.all(14),
}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white24),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: -8),
      ],
    ),
    child: child,
  );
}