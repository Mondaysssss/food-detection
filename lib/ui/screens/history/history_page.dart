// [OOP] 歷史頁：列出過往 CookSession / CookHistory。
// ✅ sessions: 顯示長方形卡片（完成幾多道 / 完成時間 / 總完成時間）
// ✅ 點卡片：Bottom Sheet 詳情
// ✅ Bottom Sheet 入面每道菜：長按 → 彈出食譜詳細 (showRecipeDetailSheet)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/services/auth_service.dart';
import '../../../data/recipes_data.dart';
import '../../../domain/models/cook_session.dart';
import '../../../domain/models/match_result.dart';
import '../../../state/app_state.dart';
import '../../widgets/glass.dart';
import '../../widgets/recipe_detail_sheet.dart';
import '../../widgets/ui_helpers.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _newestFirst = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedSessionIds = <String>{};

  String _fmt2(int v) => v.toString().padLeft(2, '0');

  // yyyy.MM.dd, HH:mm
  String _fmtDone(DateTime dt) {
    return '${dt.year}.${_fmt2(dt.month)}.${_fmt2(dt.day)}, ${_fmt2(dt.hour)}:${_fmt2(dt.minute)}';
  }

  void _openSessionSheet(BuildContext context, CookSession s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (_) => _SessionDetailSheet(session: s, fmtDone: _fmtDone),
    );
  }

  void _enterSelectionMode([String? sessionId]) {
    setState(() {
      _isSelectionMode = true;
      if (sessionId != null) {
        _selectedSessionIds.add(sessionId);
      }
    });
  }

  void _toggleSelection(String sessionId) {
    setState(() {
      if (_selectedSessionIds.contains(sessionId)) {
        _selectedSessionIds.remove(sessionId);
      } else {
        _selectedSessionIds.add(sessionId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedSessionIds.clear();
    });
  }

  Future<void> _confirmDeleteSelectedSessions(BuildContext context) async {
    if (_selectedSessionIds.isEmpty) return;

    final count = _selectedSessionIds.length;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete history'),
        content: Text(
          'Are you sure you want to delete these $count history record(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    final auth = AuthService();
    final user = auth.currentUser;

    try {
      if (user != null) {
        await auth.deleteCookSessionsByIds(
          uid: user.uid,
          ids: _selectedSessionIds,
        );
      }

      if (!mounted) return;
      context.read<AppState>().deleteSessionsByIds(_selectedSessionIds);
      _exitSelectionMode();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count history record(s) deleted')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete history. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawSessions = context.watch<AppState>().sessions;

    // 排序
    final sessions = _newestFirst
        ? rawSessions.toList()
        : rawSessions.reversed.toList();

    if (sessions.isNotEmpty) {
      return Column(
        children: [
          // 排序按鈕列
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_newestFirst ? 'Recent' : 'Oldest'),
                        const SizedBox(width: 4),
                        Icon(
                          _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                          size: 16,
                        ),
                      ],
                    ),
                    onPressed: () => setState(() => _newestFirst = !_newestFirst),
                  ),
                  if (!_isSelectionMode)
                    ActionChip(
                      avatar: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      onPressed: _enterSelectionMode,
                    ),
                  if (_isSelectionMode)
                    ActionChip(
                      label: const Text('Cancel'),
                      onPressed: _exitSelectionMode,
                    ),
                  if (_isSelectionMode)
                    ActionChip(
                      avatar: const Icon(Icons.check, size: 18),
                      label: Text('Confirm (${_selectedSessionIds.length})'),
                      onPressed: _selectedSessionIds.isEmpty
                          ? null
                          : () => _confirmDeleteSelectedSessions(context),
                    ),
                ],
              ),
            ),
          ),
          // 列表
          Expanded(
            child: ListView.separated(
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final s = sessions[i];
                final isSelected = _selectedSessionIds.contains(s.id);
                final totalDishes = s.items.values.fold<int>(
                  0,
                  (sum, v) => sum + v,
                );

                // 取第一個食譜的封面圖
                final firstMenuId = s.items.keys.first;
                final firstRecipe = kRecipeById[firstMenuId];
                final cover = firstRecipe?.cover;

                // 拼所有食譜名字，用 " + " 連接
                final names = s.items.keys
                    .map((id) => kRecipeById[id]?.name ?? id)
                    .join(' + ');

                return InkWell(
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelection(s.id);
                    } else {
                      _openSessionSheet(context, s);
                    }
                  },
                  onLongPress: () {
                    if (_isSelectionMode) {
                      _toggleSelection(s.id);
                    } else {
                      _enterSelectionMode(s.id);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _isSelectionMode && isSelected
                            ? Colors.redAccent
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: glass(
                      padding: EdgeInsets.zero,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(18),
                            ),
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: cover != null
                                  ? Image.asset(cover, fit: BoxFit.cover)
                                  : Container(
                                      color: Colors.white12,
                                      child: const Icon(Icons.restaurant),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    names,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Completed $totalDishes dishes',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    '${s.totalMinutes} minutes',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    _fmtDone(s.completedAt),
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _isSelectionMode
                                ? AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.redAccent
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.redAccent
                                            : Colors.white54,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          )
                                        : null,
                                  )
                                : const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ), // ListView.separated 結尾
          ), // Expanded
        ],
      ); // Column
    }

    // ✅ 冇 sessions：fallback 用單菜 history grid（你原本嗰套）
    final list = context.watch<AppState>().history;
    if (list.isEmpty) {
      return glass(
        child: const Text(
          'No menus completed yet.',
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
          itemCount: list.length,
          itemBuilder: (_, i) {
            final h = list[i];
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
                      child: Image.asset(h.cover, fit: BoxFit.cover),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Finished on ${h.completedAt}',
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

class _SessionDetailSheet extends StatelessWidget {
  final CookSession session;
  final String Function(DateTime) fmtDone;
  const _SessionDetailSheet({required this.session, required this.fmtDone});

  @override
  Widget build(BuildContext context) {
    final totalDishes = session.items.values.fold<int>(0, (s, v) => s + v);

    final entries = session.items.entries.toList(growable: false)
      ..sort((a, b) {
        final an = kRecipeById[a.key]?.name ?? a.key;
        final bn = kRecipeById[b.key]?.name ?? b.key;
        return an.compareTo(bn);
      });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: glass(
            padding: const EdgeInsets.all(14),
            child: ListView(
              controller: controller,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                titleText('Session summary'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    kvPill('✅ Completed', '$totalDishes dishes'),
                    kvPill('⏱️ Total time', '${session.totalMinutes} minutes'),
                    kvPill('📅 Completed at', fmtDone(session.completedAt)),
                  ],
                ),

                const SizedBox(height: 14),
                titleText('Dishes (tap to view recipe)'),
                if (entries.isEmpty)
                  const Text('—', style: TextStyle(color: Colors.white70))
                else
                  ...entries.map((e) {
                    final r = kRecipeById[e.key];
                    final name = r?.name ?? e.key;
                    final cover = r?.cover;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        // ✅ 單按：彈出食譜詳細
                        onTap: r == null
                            ? null
                            : () {
                                showRecipeDetailSheet(
                                  context,
                                  r,
                                  const MatchResult([], []),
                                );
                              },

                        // ✅ 長按：同樣彈出食譜詳細
                        onLongPress: r == null
                            ? null
                            : () {
                                showRecipeDetailSheet(
                                  context,
                                  r,
                                  const MatchResult([], []),
                                );
                              },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 64,
                                  height: 42,
                                  child: cover == null
                                      ? Container(
                                          color: Colors.white12,
                                          child: const Icon(
                                            Icons.restaurant,
                                            size: 18,
                                          ),
                                        )
                                      : Image.asset(cover, fit: BoxFit.cover),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      r == null
                                          ? 'Recipe not found'
                                          : 'Tap to view recipe',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              kvPill('×', '${e.value}'),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
