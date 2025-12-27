// [OOP] 資料模型：一次煮食流程/Session（多道菜、目前步驟、計時等）。

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