// [OOP] 收藏頁：列出已收藏食譜。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/recipes_data.dart';
import '../../state/app_state.dart';
import '../widgets/glass.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final favIds = context.watch<AppState>().favorites;
    final favList = kRecipes.where((r) => favIds.contains(r.menuId)).toList();

    if (favList.isEmpty) {
      return glass(
        child: const Text(
          'No favorite menus yet.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final cols = w >= 1100
            ? 3
            : w >= 750
            ? 2
            : 1;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.86,
          ),
          itemCount: favList.length,
          itemBuilder: (_, i) {
            final r = favList[i];
            return glass(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.asset(r.cover, fit: BoxFit.cover),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${r.type} ・ ${r.taste.join('/ ')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
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
