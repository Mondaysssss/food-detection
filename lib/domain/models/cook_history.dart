// [OOP] Data model: history record after completing a cooking session (time, dish, used/missing ingredients, etc.).

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
