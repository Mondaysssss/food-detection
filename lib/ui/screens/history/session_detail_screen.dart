// [OOP] Session detail: shows detailed steps/duration/ingredients of a CookSession.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recipes_data.dart';
import '../../../domain/models/cook_session.dart';
import '../../../domain/services/matcher.dart';
import '../../../state/app_state.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/glass.dart';
import '../../widgets/ui_helpers.dart';
import '../../widgets/recipe_card.dart';

class SessionDetailScreen extends StatelessWidget {
  final CookSession session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final detected = context.watch<AppState>().ingredients;

    final entries = [
      for (final e in session.items.entries)
        (recipe: kRecipeById[e.key]!, qty: e.value, mr: computeMatch(kRecipeById[e.key]!, detected)),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          'History details | ${entries.fold<int>(0, (s, e) => s + e.qty)} dishes • ${session.totalMinutes} min',
        ),
      ),
      body: PageFrame(
        child: LayoutBuilder(
          builder: (_, c) {
            final w = c.maxWidth;
            final cols = w >= 1200 ? 3 : w >= 800 ? 2 : 1;
            const spacing = 12.0;
            final tileW = (w - (cols - 1) * spacing) / cols;

            const aspect = 21 / 9;
            final coverH = tileW / aspect;
            final baseInfoH = cols == 1 ? 110.0 : (cols == 2 ? 104.0 : 98.0);
            final tileH = coverH + baseInfoH;

            final grid = GridView.builder(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                mainAxisExtent: tileH,
              ),
              itemCount: entries.length,
              itemBuilder: (_, i) => RecipeCard(
                recipe: entries[i].recipe,
                mr: entries[i].mr,
                readOnly: true,
                qtyForCart: entries[i].qty,
                showMatchLines: false,
                showProgress: false,
                coverAspect: aspect,
                compact: true,
              ),
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  glass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleText('Summary'),
                        Text('Completed at: ${session.completedAt}', style: const TextStyle(color: Colors.white70)),
                        Text(
                          'Menu count: ${entries.fold<int>(0, (s, e) => s + e.qty)} dishes, total time: ${session.totalMinutes} min',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  grid,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}