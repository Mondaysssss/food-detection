// lib/ui/widgets/favorite_star.dart
// FavoriteStar：右上角收藏星星（點擊切換收藏狀態）
// 用 Selector 只重建星星本身，避免整張卡重建。

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