// [OOP] Data model: a single cooking flow/session (multiple dishes, current step, timers, etc.).

class CookSession {
  final String id;
  final DateTime completedAt;
  final Map<String, int> items; // menuId -> qty
  final int totalMinutes;

  CookSession({
    required this.id,
    required this.completedAt,
    required this.items,
    required this.totalMinutes,
  });
}