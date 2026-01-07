// [OOP] Cook Flow：單菜/多菜共用的「一頁完成」烹飪流程畫面（參考你 TS 版 page3 風格）
// - 上方：6 個工具 icon（之後可由 DB 決定邊個要亮/計時；暫時用簡單規則示範）
// - 中間：只顯示 1 個「目前 step」（大字 + 大倒數）
// - 右邊：最多 5 個菜單「圖按鈕」(依照 snapshot 的 menuId) → 彈出該菜 steps（顯示 global Step x/total）
// - 底部：圓形 pull tab → 彈出 Bottom Sheet（顯示全部 global steps）
// - Start 只可按一次；Next step 必須倒數到 0 先可按

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recipes_data.dart';
import '../../../domain/models/recipe.dart';
import '../../../state/app_state.dart';
import '../../widgets/glass.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/ui_helpers.dart';

class CookFlowScreen extends StatefulWidget {
  final Map<String, int> snapshot;
  final int totalPlannedMinutes;

  /// ✅ 可選：單菜時顯示菜名
  final String? singleRecipeTitle;

  const CookFlowScreen({
    super.key,
    required this.snapshot,
    required this.totalPlannedMinutes,
    this.singleRecipeTitle,
  });

  @override
  State<CookFlowScreen> createState() => _CookFlowScreenState();
}

class _FlowStep {
  final String menuId;
  final String menuTitle;
  final int localStepIndex; // 0-based
  final int localTotal;
  final String title;
  final String detail;
  final int seconds;

  const _FlowStep({
    required this.menuId,
    required this.menuTitle,
    required this.localStepIndex,
    required this.localTotal,
    required this.title,
    required this.detail,
    required this.seconds,
  });
}

class _CookFlowScreenState extends State<CookFlowScreen> {
  static const _ink = Color(0xFF0B1220);

  late final List<_FlowStep> _steps;
  late final List<Recipe> _menus;

  /// key = "menuId#localStepIndex" -> globalIndex (0-based)
  late final Map<String, int> _globalIndexByMenuStep;

  int _idx = 0;
  int _left = 0;
  bool _started = false;
  bool _running = false;
  bool _finished = false;
  bool _autoNext = true;

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _menus = widget.snapshot.keys
        .map((id) => kRecipeById[id])
        .whereType<Recipe>()
        .toList(growable: false);

    _steps = _buildSteps();
    _globalIndexByMenuStep = _buildGlobalIndexMap(_steps);

    _left = _steps.isEmpty ? 0 : _steps.first.seconds;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  List<_FlowStep> _buildSteps() {
    // 以 MultiCookScreen 的規則：把每個菜嘅 steps 展開；順序先照 snapshot 展開（之後你可用 DB 規則排程）
    // 為咗保留「多份同一菜 qty」：會重複展開同一菜 steps。

    final timeScale = context.read<AppState>().timeScale;
    final List<_FlowStep> out = [];

    widget.snapshot.forEach((menuId, qty) {
      final r = kRecipeById[menuId];
      if (r == null) return;

      for (int q = 0; q < qty; q++) {
        final localTotal = r.steps.length;
        for (int i = 0; i < r.steps.length; i++) {
          final st = r.steps[i];
          final sec = max(1, st.durationMin * timeScale);
          out.add(
            _FlowStep(
              menuId: menuId,
              menuTitle: r.title,
              localStepIndex: i,
              localTotal: localTotal,
              title: st.title,
              detail: st.detail,
              seconds: sec,
            ),
          );
        }
      }
    });

    return out;
  }

  Map<String, int> _buildGlobalIndexMap(List<_FlowStep> steps) {
    final m = <String, int>{};
    for (int i = 0; i < steps.length; i++) {
      final s = steps[i];
      m['${s.menuId}#${s.localStepIndex}'] ??= i; // 同一菜 qty 重複時，保留第一次（夠用於 UI）
    }
    return m;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_running) return;
      if (_left <= 0) return;

      setState(() {
        _left = max(0, _left - 1);
        if (_left == 0) {
          _running = false;
          _finished = true;

          if (_autoNext && _started && _idx < _steps.length - 1) {
            // 小延遲令 UI 更自然
            Future.delayed(const Duration(milliseconds: 220), () {
              if (!mounted) return;
              if (!_autoNext) return;
              if (!_finished) return;
              _goNext(auto: true);
            });
          }
        }
      });
    });
  }

  void _startOnce() {
    if (_started) return;
    if (_steps.isEmpty) return;
    setState(() {
      _started = true;
      _running = true;
      _finished = false;
      _left = _steps[_idx].seconds;
    });
    _startTicker();
  }

  void _goNext({bool auto = false}) {
    if (_steps.isEmpty) return;
    if (!auto) {
      // ✅ 手動 Next：未到 0 唔俾
      if (!_finished) return;
    }

    if (_idx >= _steps.length - 1) {
      // 最後一步
      setState(() {
        _running = false;
      });
      return;
    }

    setState(() {
      _idx = min(_idx + 1, _steps.length - 1);
      _left = _steps[_idx].seconds;
      _running = _started; // Start 後每步自動計時
      _finished = false;
    });

    if (_started) _startTicker();
  }

  String _fmt(int s) {
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _openAllStepsSheet() async {
    if (_steps.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.25,
          maxChildSize: 0.95,
          builder: (ctx, scrollCtl) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .86),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border.all(color: Colors.white.withValues(alpha: .9)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 54,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtl,
                      itemCount: _steps.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final s = _steps[i];
                        final isCur = i == _idx;
                        final done = i < _idx;

                        return ListTile(
                          dense: true,
                          title: Text(
                            'Step ${i + 1}/${_steps.length} · ${s.menuTitle}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isCur ? _ink : Colors.black.withValues(alpha: .88),
                            ),
                          ),
                          subtitle: Text(
                            s.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _fmt(s.seconds),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done
                                      ? Colors.black.withValues(alpha: .70)
                                      : Colors.black.withValues(alpha: .08),
                                  border: Border.all(color: Colors.black.withValues(alpha: .18)),
                                ),
                                alignment: Alignment.center,
                                child: Text(done ? '✓' : '', style: const TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            if (!_started) {
                              setState(() {
                                _idx = i;
                                _left = _steps[_idx].seconds;
                              });
                            }
                          },
                        );
                      },
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

  void _openMenuQuickList(Recipe r) {
    // ✅ 需求 2.B：顯示「該菜 steps + global step index」（例如 Step 7/18）
    final total = _steps.length;

    // 取出該菜的 local steps，再用 map 找 global index（找不到就跳過）
    final items = <({int globalIdx, RecipeStep st, int localIdx})>[];
    for (int i = 0; i < r.steps.length; i++) {
      final gi = _globalIndexByMenuStep['${r.id}#$i'];
      if (gi == null) continue;
      items.add((globalIdx: gi, st: r.steps[i], localIdx: i));
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          content: SizedBox(
            width: 520,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final it = items[i];
                final label = 'Step ${it.globalIdx + 1}/$total';
                return ListTile(
                  dense: true,
                  title: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(it.st.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text('${it.st.durationMin}m', style: const TextStyle(fontWeight: FontWeight.w800)),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (!_started) {
                      setState(() {
                        _idx = it.globalIdx;
                        _left = _steps[_idx].seconds;
                      });
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Widget _toolIcon({required IconData icon, required String label, required bool active, String? countText}) {
    final border = active ? Colors.white.withValues(alpha: .45) : Colors.white.withValues(alpha: .18);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: active ? .14 : .10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 30, color: Colors.white.withValues(alpha: .95)),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white70)),
              ],
            ),
          ),
          if (countText != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  countText,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _steps.length;
    final cur = total == 0 ? null : _steps[_idx];
    final canNext = total > 0 && _finished;

    final mq = MediaQuery.of(context);
    final isNarrow = mq.size.width < 520;

    // ✅ 簡單示範：秒數 >= 60 視為「可離手（用鍋/電鍋/焗爐）」→ 顯示在第一個 icon 倒數
    final showTopTimer = _started && cur != null && cur.seconds >= 60;
    final topCountText = showTopTimer ? _fmt(_left) : null;

    final rightMenus = _menus.take(5).toList(growable: false); // ✅ 需求 1：最多 5 個

    final headerTitle = widget.singleRecipeTitle ?? (rightMenus.length <= 1 ? 'Cooking' : 'Multi cooking');
    final headerSub = total == 0
        ? 'No steps'
        : (rightMenus.length <= 1
            ? 'Step-by-step · Total $total steps'
            : 'Step-by-step · Total $total steps · ${rightMenus.length} menus');

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        title: Text(headerTitle),
      ),
      body: Stack(
        children: [
          PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(headerTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 4),
                Text(headerSub, style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 12),

                // ✅ Top icons (6)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: .14)),
                  ),
                  child: LayoutBuilder(
                    builder: (_, c) {
                      final cols = c.maxWidth < 360 ? 2 : 3;
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          _toolIcon(
                            icon: Icons.soup_kitchen,
                            label: 'Pot',
                            active: showTopTimer,
                            countText: topCountText,
                          ),
                          _toolIcon(icon: Icons.rice_bowl, label: 'Rice', active: false),
                          _toolIcon(icon: Icons.local_fire_department, label: 'Stove', active: !showTopTimer && _started),
                          _toolIcon(icon: Icons.kitchen, label: 'Oven', active: false),
                          _toolIcon(icon: Icons.handyman, label: 'Prep', active: false),
                          _toolIcon(icon: Icons.front_hand, label: 'Hands', active: !showTopTimer && _started),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 14),

                // ✅ Main row: Step card + right menus
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: Colors.white.withValues(alpha: _finished ? .30 : .16)),
                              ),
                              child: cur == null
                                  ? const Center(
                                      child: Text('No steps', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900)),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: .10),
                                                borderRadius: BorderRadius.circular(999),
                                                border: Border.all(color: Colors.white.withValues(alpha: .14)),
                                              ),
                                              child: Text(
                                                // ✅ 需求 2.B：global Step index
                                                'Step ${_idx + 1}/$total',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  _fmt(_left),
                                                  style: TextStyle(
                                                    color: _finished ? Colors.redAccent : Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 34,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                SizedBox(
                                                  height: 34,
                                                  child: FilledButton.tonal(
                                                    onPressed: _started
                                                        ? null
                                                        : () {
                                                            setState(() => _autoNext = !_autoNext);
                                                          },
                                                    child: Text('Auto Next: ${_autoNext ? 'ON' : 'OFF'}'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        Text(
                                          cur.title,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28, height: 1.1),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          cur.detail,
                                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 16, height: 1.4),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Menu: ${cur.menuTitle} · Local: ${cur.localStepIndex + 1}/${cur.localTotal}',
                                          style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700, fontSize: 12),
                                        ),
                                        const Spacer(),

                                        SizedBox(
                                          height: 54,
                                          child: FilledButton(
                                            onPressed: canNext ? () => _goNext() : null,
                                            child: Text(_idx >= total - 1 ? 'Finish' : 'Next step →', style: const TextStyle(fontWeight: FontWeight.w900)),
                                          ),
                                        ),
                                        const SizedBox(height: 12),

                                        Row(
                                          children: [
                                            Expanded(
                                              child: SizedBox(
                                                height: 54,
                                                child: FilledButton.tonal(
                                                  onPressed: _started || total == 0 ? null : _startOnce,
                                                  child: Text(_started ? 'Started' : 'Start', style: const TextStyle(fontWeight: FontWeight.w900)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          _started
                                              ? (_running ? 'Running…' : (_finished ? 'Done (you can Next)' : 'Idle'))
                                              : 'Press Start once to begin Step 1 timer.',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),

                      if (!isNarrow) ...[
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 64,
                          child: Column(
                            children: [
                              for (final r in rightMenus) ...[
                                GestureDetector(
                                  onTap: () => _openMenuQuickList(r),
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withValues(alpha: .18)),
                                      color: Colors.white.withValues(alpha: .10),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Image.network(
                                      r.cover,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.restaurant_menu, color: Colors.white70),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 底部留位（避免被 pull tab 擋住）
                const SizedBox(height: 74),
              ],
            ),
          ),

          // ✅ pull tab (bottom center)
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: Center(
              child: GestureDetector(
                onTap: _openAllStepsSheet,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .14),
                    border: Border.all(color: Colors.white.withValues(alpha: .22)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .45),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      )
                    ],
                  ),
                  child: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
