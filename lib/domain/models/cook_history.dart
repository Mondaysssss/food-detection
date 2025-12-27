// [OOP] 資料模型：完成煮食後的歷史紀錄（時間、菜式、用到/缺少食材等）。

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