import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

class FavoriteStar extends StatelessWidget {
  final String menuId;
  const FavoriteStar({super.key, required this.menuId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<AppState>().toggleFavorite(menuId),
      child: Selector<AppState, bool>(
        selector: (_, s) => s.favorites.contains(menuId),
        builder: (_, fav, __) => CircleAvatar(
          radius: 16,
          backgroundColor: fav ? Colors.black45 : Colors.black26,
          child: Icon(
            fav ? Icons.star : Icons.star_border,
            color: fav ? Colors.amber : Colors.white70,
            size: 18,
          ),
        ),
      ),
    );
  }
}