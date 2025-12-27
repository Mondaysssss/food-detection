// lib/domain/models/cook_history.dart
// Domain Model：單菜完成紀錄（舊版 History fallback 用）

class CookHistory {
  final String title;
  final String cover;
  final DateTime completedAt;

  CookHistory({
    required this.title,
    required this.cover,
    required this.completedAt,
  });
}