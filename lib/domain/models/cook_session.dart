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