// lib/domain/models/cook_session.dart
// Domain Model：多菜 Session 完成紀錄（主要 History 用）
//
// items: menuId -> qty
// totalMinutes: 預估總時間（分）

class CookSession {
  final DateTime completedAt;
  final Map<String, int> items; // menuId -> qty
  final int totalMinutes;

  CookSession({
    required this.completedAt,
    required this.items,
    required this.totalMinutes,
  });
}