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

class CookFlowScreen extends StatefulWidget {
  /// 多菜：來自 cart 的 snapshot（menuId -> qty）
  final Map<String, int> snapshot;

  /// 多菜總時間（你之前 CartScreen 計出嚟嗰個）
  final int totalPlannedMinutes;

  const CookFlowScreen({
    super.key,
    required this.snapshot,
    required this.totalPlannedMinutes,
  });

  @override
  State<CookFlowScreen> createState() => _CookFlowScreenState();
}

class _CookFlowScreenState extends State<CookFlowScreen> {
  // ======== UI theme (match TS dark glass vibe) ========
  static const _bg = Color(0xFF0B0F14);
  static const _ink = Colors.white;
  static const _muted = Color(0xB3FFFFFF);

  // ======== flow state ========
  bool _started = false;

  int _globalIndex = 0; // 0-based
  late final List<_GlobalStep> _globalSteps;
  late final int _totalGlobalSteps;

  // 倒數
  int _leftSec = 0;
  Timer? _ticker;

  // 右邊 quick menu list（最多 5）
  String? _quickOpenMenuId;

  // 底部 sheet
  final DraggableScrollableController _sheetCtl = DraggableScrollableController();
  bool _sheetOpen = false;

  // ======== build mapping: (menuId#stepIndex) -> globalIndex ========
  late final Map<String, int> _globalIndexByMenuStep;

  @override
  void initState() {
    super.initState();

    _globalSteps = _buildGlobalSteps(widget.snapshot);
    _totalGlobalSteps = _globalSteps.length;

    _globalIndexByMenuStep = {};
    for (int gi = 0; gi < _globalSteps.length; gi++) {
      final gs = _globalSteps[gi];
      _globalIndexByMenuStep['${gs.menuId}#${gs.stepIndex}'] = gi;
    }

    // 初始 leftSec（未 start 都顯示該 step 時間）
    _leftSec = _globalSteps.isNotEmpty ? _globalSteps[0].durationSec : 0;

    _sheetCtl.addListener(() {
      // sheet 只要一開到 0.25+ 就當開，會隱藏右邊 icons
      final s = _sheetCtl.size;
      final open = s >= 0.25;
      if (open != _sheetOpen) setState(() => _sheetOpen = open);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sheetCtl.dispose();
    super.dispose();
  }

  // ======== rules ========
  bool get _isLast => _globalIndex >= _totalGlobalSteps - 1;
  bool get _canNext => _started && _leftSec <= 0;

  _GlobalStep? get _cur => _globalSteps.isEmpty ? null : _globalSteps[_globalIndex];

  void _startOnce() {
    if (_started) return;
    if (_globalSteps.isEmpty) return;

    setState(() => _started = true);
    _restartCountdownForCurrent();
  }

  void _restartCountdownForCurrent() {
    _ticker?.cancel();

    final cur = _cur;
    final sec = cur?.durationSec ?? 0;

    setState(() => _leftSec = sec);

    // 即時 tick 一次，然後每秒 tick
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _leftSec = max(0, _leftSec - 1);
      });
    });
  }

  void _goNext() {
    if (!_canNext) return;
    if (_globalSteps.isEmpty) return;

    if (_isLast) {
      // finish
      _ticker?.cancel();
      setState(() => _leftSec = 0);
      _showFinishedDialog();
      return;
    }

    setState(() => _globalIndex++);
    _restartCountdownForCurrent();
  }

  void _showFinishedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Done'),
        content: const Text('All steps finished.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ======== global steps builder ========
  List<_GlobalStep> _buildGlobalSteps(Map<String, int> snapshot) {
    // 展開為 menuIds（同 menu qty 次）
    final List<String> menuIds = [];
    snapshot.forEach((menuId, qty) {
      for (int i = 0; i < qty; i++) {
        menuIds.add(menuId);
      }
    });

    // 取食譜
    final recipes = <Recipe>[];
    for (final id in menuIds) {
      final r = kRecipeById[id];
      if (r != null) recipes.add(r);
    }

    // 合併規則（暫時簡化）：
    // - 先按「最長總時間」排序：長嘅菜先做（你描述：先做最長嗰個）
    recipes.sort((a, b) => _recipeTotalMin(b).compareTo(_recipeTotalMin(a)));

    // 先照排序串連 steps 變 global steps
    final out = <_GlobalStep>[];
    for (final r in recipes) {
      for (int si = 0; si < r.steps.length; si++) {
        final st = r.steps[si];

        out.add(_GlobalStep(
          menuId: r.menuId,
          menuTitle: r.menuTitle,
          stepIndex: si,
          title: st.titleText,
          detail: st.detailText,
          durationSec: max(1, st.durationMin) * 60,
          tool: _guessTool(st),
        ));
      }
    }

    return out;
  }

  int _recipeTotalMin(Recipe r) {
    return r.steps.fold<int>(0, (s, st) => s + st.durationMin);
  }

  // 工具 icon（之後你會用 DB 決定；暫時用字眼猜）
  _ToolKind _guessTool(RecipeStep st) {
    final t = ('${st.titleText} ${st.detailText}').toLowerCase();
    if (t.contains('oven') || t.contains('bake')) return _ToolKind.oven;
    if (t.contains('rice') || t.contains('electric') || t.contains('pot')) return _ToolKind.electricPot;
    if (t.contains('wok') || t.contains('pan') || t.contains('fry')) return _ToolKind.pan;
    if (t.contains('steam')) return _ToolKind.steamer;
    if (t.contains('mix') || t.contains('cut') || t.contains('stir')) return _ToolKind.hand;
    return _ToolKind.hand;
  }

  // ======== UI pieces ========
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final cur = _cur;
    final hideRightMenus = _sheetOpen || _quickOpenMenuId != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Cooking'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: PageFrame(
        child: Stack(
          children: [
            // main scroll
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(app),
                  const SizedBox(height: 12),

                  _toolIcons(cur),
                  const SizedBox(height: 14),

                  _stepCard(cur),
                  const SizedBox(height: 12),

                  _startOnceHint(),
                ],
              ),
            ),

            // right vertical menu buttons
            Positioned(
              top: 110,
              right: 0,
              child: AnimatedOpacity(
                opacity: hideRightMenus ? 0 : 1,
                duration: const Duration(milliseconds: 160),
                child: IgnorePointer(
                  ignoring: hideRightMenus,
                  child: _rightMenuButtons(),
                ),
              ),
            ),

            // quick menu popup
            if (_quickOpenMenuId != null) _quickMenuDialog(),

            // bottom pull-sheet
            _bottomSheet(),

            // bottom actions (Start / Next)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                minimum: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed: _started ? null : _startOnce,
                          child: Text(_started ? 'Started' : 'Start'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: FilledButton.tonal(
                          onPressed: _canNext ? _goNext : null,
                          child: Text(_isLast ? 'Finish' : 'Next step'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppState app) {
    final totalMin = widget.totalPlannedMinutes;
    final total = _totalGlobalSteps;
    final curNo = total == 0 ? 0 : (_globalIndex + 1);

    return glass(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cook Flow',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Global Step $curNo/$total · Planned ${totalMin}min',
                  style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _bigSecBox(_leftSec),
        ],
      ),
    );
  }

  Widget _bigSecBox(int sec) {
    final txt = sec.toString().padLeft(2, '0');
    final danger = _started && sec <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Text(
        txt,
        style: TextStyle(
          color: danger ? const Color(0xFFEF4444) : _ink,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      ),
    );
  }

  Widget _toolIcons(_GlobalStep? cur) {
    final tool = cur?.tool;

    // 6 icons: pan, electric pot, oven, steamer, hand, timer
    final items = <_ToolItem>[
      _ToolItem(_ToolKind.pan, Icons.local_fire_department, 'Pan'),
      _ToolItem(_ToolKind.electricPot, Icons.soup_kitchen, 'Pot'),
      _ToolItem(_ToolKind.oven, Icons.outdoor_grill, 'Oven'),
      _ToolItem(_ToolKind.steamer, Icons.water_drop, 'Steam'),
      _ToolItem(_ToolKind.hand, Icons.back_hand, 'Hand'),
      _ToolItem(_ToolKind.timer, Icons.alarm, 'Timer'),
    ];

    return glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tools', style: TextStyle(color: _ink, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (_, c) {
              final w = c.maxWidth;
              final cols = w >= 420 ? 3 : 2;
              const gap = 10.0;
              final tileW = (w - (cols - 1) * gap) / cols;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final it in items)
                    SizedBox(
                      width: tileW,
                      child: _toolTile(
                        it,
                        active: _started && (it.kind == tool || it.kind == _ToolKind.timer),
                        finished: _started && _leftSec <= 0 && it.kind == _ToolKind.timer,
                        countText: (it.kind == _ToolKind.timer && _started) ? _leftSec.toString().padLeft(2, '0') : null,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _toolTile(_ToolItem it, {required bool active, required bool finished, String? countText}) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: active ? .10 : .06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: active ? .22 : .12)),
        boxShadow: active
            ? [
                BoxShadow(
                  color: (finished ? const Color(0xFFEF4444) : const Color(0xFF22C55E)).withValues(alpha: .25),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(it.icon, color: Colors.white.withValues(alpha: .92), size: 34),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Text(
              it.label,
              style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          if (countText != null)
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .85),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  countText,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepCard(_GlobalStep? cur) {
    if (cur == null) {
      return glass(
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No steps', style: TextStyle(color: _muted)),
        ),
      );
    }

    final total = _totalGlobalSteps;
    final curNo = _globalIndex + 1;

    return glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: .14)),
                ),
                child: Text(
                  'Step $curNo/$total',
                  style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
              const Spacer(),
              Text(
                '${cur.durationSec ~/ 60}m',
                style: const TextStyle(color: _muted, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            cur.title,
            style: const TextStyle(color: _ink, fontSize: 28, height: 1.15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            cur.detail,
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 17, height: 1.45, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            _started
                ? (_leftSec > 0 ? 'Running...' : 'Done. You can go next.')
                : 'Press Start once to begin Step1 countdown.',
            style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _startOnceHint() {
    return Center(
      child: Text(
        _started ? 'Started: each step starts countdown automatically.' : 'Start only once. Next step is locked until timer reaches 0.',
        style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ======== right menu buttons (最多 5) ========
  Widget _rightMenuButtons() {
    final menuIds = widget.snapshot.keys.toList();
    final limited = menuIds.take(5).toList();

    return Column(
      children: [
        for (final id in limited) ...[
          _menuIconButton(menuId: id),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _menuIconButton({required String menuId}) {
    final r = kRecipeById[menuId];
    final title = r?.menuTitle ?? menuId;

    return SizedBox(
      width: 56,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.white.withValues(alpha: .10),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        onPressed: () => setState(() => _quickOpenMenuId = menuId),
        child: Center(
          child: Text(
            title.characters.take(2).toString().toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  // ======== quick menu dialog (顯示該菜 steps + global Step x/total) ========
  Widget _quickMenuDialog() {
    final menuId = _quickOpenMenuId!;
    final r = kRecipeById[menuId];
    final steps = r?.steps ?? const <RecipeStep>[];

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _quickOpenMenuId = null),
        child: Container(
          color: Colors.black.withValues(alpha: .40),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: () {}, // stop
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
              child: Material(
                color: Colors.white.withValues(alpha: .82),
                borderRadius: BorderRadius.circular(22),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              r?.menuTitle ?? menuId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _quickOpenMenuId = null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: steps.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final st = steps[i];
                          final gi = _globalIndexByMenuStep['$menuId#$i'];
                          final globalLabel = (gi == null) ? '' : 'Step ${gi + 1}/$_totalGlobalSteps';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .60),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black.withValues(alpha: .08)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        globalLabel,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF374151)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        st.titleText,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${st.durationMin}m',
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4B5563)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: SizedBox(
                        height: 46,
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => setState(() => _quickOpenMenuId = null),
                          child: const Text('Close'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ======== bottom draggable sheet (all global steps) ========
  Widget _bottomSheet() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: DraggableScrollableSheet(
        controller: _sheetCtl,
        initialChildSize: 0.10,
        minChildSize: 0.10,
        maxChildSize: 0.92,
        snap: true,
        snapSizes: const [0.10, 0.92],
        builder: (ctx, scrollCtl) {
          final showPull = !_sheetOpen && _quickOpenMenuId == null;

          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .55),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: .20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .35),
                      blurRadius: 40,
                      offset: const Offset(0, -18),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // grab bar
                    Container(
                      height: 44,
                      alignment: Alignment.center,
                      child: Container(
                        width: 56,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtl,
                        padding: const EdgeInsets.all(12),
                        itemCount: _globalSteps.length,
                        itemBuilder: (_, i) {
                          final it = _globalSteps[i];
                          final isCur = i == _globalIndex;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: isCur ? .65 : .42),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: .26)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Step ${i + 1}/$_totalGlobalSteps',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF6B7280)),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        it.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        it.menuTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${it.durationSec ~/ 60}m',
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4B5563)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // pull tab button（開 sheet）
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: AnimatedOpacity(
                  opacity: showPull ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: IgnorePointer(
                    ignoring: !showPull,
                    child: Center(
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            elevation: 0,
                            backgroundColor: Colors.white.withValues(alpha: .18),
                            foregroundColor: Colors.black.withValues(alpha: .85),
                          ),
                          onPressed: () {
                            // snap to open
                            _sheetCtl.animateTo(
                              0.92,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            );
                          },
                          child: const Icon(Icons.keyboard_arrow_up, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ======== internal models ========

enum _ToolKind { pan, electricPot, oven, steamer, hand, timer }

class _ToolItem {
  final _ToolKind kind;
  final IconData icon;
  final String label;
  _ToolItem(this.kind, this.icon, this.label);
}

class _GlobalStep {
  final String menuId;
  final String menuTitle;
  final int stepIndex; // index inside that recipe
  final String title;
  final String detail;
  final int durationSec;
  final _ToolKind tool;

  _GlobalStep({
    required this.menuId,
    required this.menuTitle,
    required this.stepIndex,
    required this.title,
    required this.detail,
    required this.durationSec,
    required this.tool,
  });
}
