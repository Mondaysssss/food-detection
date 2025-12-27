// lib/ui/screens/history/history_page.dart
// History Page（烹飪歷史紀錄）
// 用途：
// - 優先顯示多菜烹飪紀錄（sessions）
// - 若無 sessions，才顯示單菜完成紀錄（history）
// - 點擊 session 進入 SessionDetailScreen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_state.dart';
import '../../widgets/glass.dart';
import '../../widgets/ui_helpers.dart';
import 'session_detail_screen.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<AppState>().sessions;

    // 優先顯示 Sessions
    if (sessions.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final s = sessions[i];
          final totalMenus = s.items.values.fold<int>(0, (sum, v) => sum + v);

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s)),
            ),
            child: glass(
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cooking log', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Completed at: ${s.completedAt}',
                              style: const TextStyle(fontSize: 12, color: Colors.white70)),
                          Text('Menus: $totalMenus dishes • Total time: ${s.totalMinutes} min',
                              style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // 無 sessions 時顯示單菜 History
    final list = context.watch<AppState>().history;

    if (list.isEmpty) {
      return Center(
        child: glass(
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No menus completed yet.', style: TextStyle(color: Colors.white70)),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final cols = w >= 1100 ? 3 : w >= 750 ? 2 : 1;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.86,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final h = list[i];
            return glass(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(h.cover, fit: BoxFit.cover),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Finished on ${h.completedAt}',
                            style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}