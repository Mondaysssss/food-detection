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

    if (sessions.isNotEmpty) {
      return ListView.separated(
        itemCount: sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final s = sessions[i];
          final totalMenus = s.items.values.fold<int>(0, (sum, v) => sum + v);

          String? cover;
          if (s.items.isNotEmpty) {
            // cover will be shown in detail; keep list simple
          }

          return InkWell(
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

    final list = context.watch<AppState>().history;
    if (list.isEmpty) {
      return glass(child: const Text('No menus completed yet.', style: TextStyle(color: Colors.white70)));
    }

    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final cols = w >= 1100 ? 3 : w >= 750 ? 2 : 1;

        return GridView.builder(
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