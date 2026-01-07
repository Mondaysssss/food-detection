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

  // bottom sheet open ratio 用嚟 hide 右邊 icons
  double _sheetOpenRatio = 0.0;

  // quick modal
  String? _quickMenuId;

  @override
  void initState() {
    super.initState();
    _menus = widget.snapshot.keys
        .map((id) => kRecipeById[id])
        .whereType<Recipe>()
        .toList();

    // 最多 5 個
    if (_menus.length > 5) {
      _menus = _menus.take(5).toList();
    }

    final built = _flattenSteps(_menus, widget.snapshot);
    _steps = built.$1;
    _globalIndexByMenuStep = built.$2;

    if (_steps.isNotEmpty) {
      _left = _steps.first.seconds;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  (List<_FlowStep>, Map<String, int>) _flattenSteps(List<Recipe> menus, Map<String, int> snapshot) {
    final List<_FlowStep> out = [];
    final Map<String, int> map = {};
    int g = 0;

    for (final r in menus) {
      final qty = snapshot[r.menuId] ?? 1;
      // qty 暫時：重複 steps
      for (int q = 0; q < max(1, qty); q++) {
        final localTotal = r.steps.length;
        for (int i = 0; i < r.steps.length; i++) {
          final st = r.steps[i];
          final seconds = max(1, st.durationMin * 60);
          final t = _prettyTitle(st.text);
          final d = st.text;

          out.add(
            _FlowStep(
              menuId: r.menuId,
              menuTitle: r.name,
              localStepIndex: i,
              localTotal: localTotal,
              title: t,
              detail: d,
              seconds: seconds,
            ),
          );

          map['${r.menuId}#$i'] = g;
          g++;
        }
      }
    }

    return (out, map);
  }

  String _prettyTitle(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 'Step';
    // 用第一句做 title
    final cut = s.split(RegExp(r'[\n\.]')).first.trim();
    return cut.isEmpty ? 'Step' : cut;
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

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_running) return;

      setState(() {
        _left = max(0, _left - 1);
        if (_left == 0) {
          _running = false;
          _finished = true;

          if (_autoNext && _idx < _steps.length - 1) {
            // 自動下一步：微 delay 模擬 TS flow
            Future.delayed(const Duration(milliseconds: 220), () {
              if (!mounted) return;
              if (!_autoNext) return;
              _goNext();
            });
          }
        }
      });
    });
  }

  void _goNext() {
    if (_steps.isEmpty) return;
    if (!_finished) return;

    if (_idx >= _steps.length - 1) {
      // finish
      setState(() {
        _running = false;
        _finished = true;
      });
      return;
    }

    setState(() {
      _idx++;
      _left = _steps[_idx].seconds;
      _running = _started;
      _finished = false;
    });
  }

  void _goPrev() {
    if (_steps.isEmpty) return;
    if (_idx <= 0) return;

    setState(() {
      _idx--;
      _left = _steps[_idx].seconds;
      _running = false; // 退返上一題先停住，等你按 Start/Next flow
      _finished = false;
    });
  }

  bool get _canNext => _steps.isNotEmpty && _finished;
  bool get _canPrev => _idx > 0;

  // ---- tool icons ----
  static const _toolIcons = <IconData>[
    Icons.soup_kitchen, // 鍋
    Icons.rice_bowl, // 電鍋
    Icons.microwave, // 烤箱/微波（placeholder）
    Icons.skillet, // 平底鍋（placeholder）
    Icons.handyman, // 人手
    Icons.timer, // timer
  ];

  int _activeToolIndexForStep(_FlowStep s) {
    // 暫時：用文字關鍵字估計（之後你 DB 有 data 再改）
    final t = s.detail.toLowerCase();
    if (t.contains('oven') || t.contains('bake')) return 2;
    if (t.contains('rice') || t.contains('cook rice')) return 1;
    if (t.contains('pan') || t.contains('fry')) return 3;
    if (t.contains('wait') || t.contains('rest') || t.contains('timer')) return 5;
    if (t.contains('stir') || t.contains('wash') || t.contains('cut')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final cur = (_steps.isEmpty) ? null : _steps[_idx];
    final total = _steps.length;

    final globalStepNo = (cur == null) ? 0 : _idx + 1;
    final headerTitle = widget.singleRecipeTitle?.trim().isNotEmpty == true
        ? widget.singleRecipeTitle!
        : (total <= 1 ? 'Cooking' : 'Cook Flow');

    final hideRightIcons = _sheetOpenRatio > 0.18 || _quickMenuId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(headerTitle),
        actions: [
          if (total > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '${widget.totalPlannedMinutes} min',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
      body: PageFrame(
        child: LayoutBuilder(
          builder: (_, c) {
            final w = c.maxWidth;
            final isWide = w >= 760;

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // top tools
                      glass(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tools (x6)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            GridView.builder(
                              shrinkWrap: true,
                              primary: false,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1,
                              ),
                              itemCount: 6,
                              itemBuilder: (_, i) {
                                final active = cur != null && _started && _activeToolIndexForStep(cur) == i;
                                final timerActive = active && _running;
                                final countText = timerActive ? _left.toString().padLeft(2, '0') : null;

                                return _ToolTile(
                                  icon: _toolIcons[i],
                                  active: active,
                                  timerText: countText,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // main step card
                      glass(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .10),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white.withValues(alpha: .14)),
                                  ),
                                  child: Text(
                                    'Step $globalStepNo/$total',
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      cur == null ? '--' : _left.toString(),
                                      style: TextStyle(
                                        fontSize: 42,
                                        height: 1.0,
                                        fontWeight: FontWeight.w900,
                                        color: (_finished ? Colors.redAccent : Colors.white),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    FilledButton.tonal(
                                      onPressed: _started ? null : _startOnce,
                                      child: Text(_started ? 'Started' : 'Start'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (cur == null)
                              const Text('No steps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))
                            else ...[
                              Text(
                                cur.title,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cur.detail,
                                style: const TextStyle(fontSize: 16, height: 1.4, color: Colors.white70),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Menu: ${cur.menuTitle} · Local step ${cur.localStepIndex + 1}/${cur.localTotal}',
                                style: const TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w700),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // bottom actions row: <- + Next
                            Row(
                              children: [
                                SizedBox(
                                  width: 46,
                                  height: 46,
                                  child: OutlinedButton(
                                    onPressed: _canPrev ? _goPrev : null,
                                    style: OutlinedButton.styleFrom(
                                      shape: const CircleBorder(),
                                      side: BorderSide(color: Colors.white.withValues(alpha: .18)),
                                    ),
                                    child: const Icon(Icons.arrow_back),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: _canNext ? _goNext : null,
                                      child: Text(_idx >= total - 1 ? 'Finish' : 'Next step'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _started
                                  ? (_running ? 'Running…' : (_finished ? 'Done: you can go Next' : 'Idle'))
                                  : 'Press Start once to begin.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // helper: show current ingredients snapshot
                      if (app.ingredients.isNotEmpty)
                        glass(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Detected ingredients', style: TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 8),
                              Text(app.ingredients.map(prettyName).join(', '), style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                // right menu buttons (max 5)
                if (isWide)
                  Positioned(
                    right: 10,
                    top: 86,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: hideRightIcons ? 0 : 1,
                      child: IgnorePointer(
                        ignoring: hideRightIcons,
                        child: Column(
                          children: [
                            for (final r in _menus)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _MenuIconButton(
                                  title: r.name,
                                  imgUrl: r.coverUrl,
                                  onTap: () => setState(() => _quickMenuId = r.menuId),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // quick modal
                if (_quickMenuId != null)
                  _QuickMenuModal(
                    menuId: _quickMenuId!,
                    menus: _menus,
                    steps: _steps,
                    globalIndexByMenuStep: _globalIndexByMenuStep,
                    onClose: () => setState(() => _quickMenuId = null),
                  ),

                // bottom sheet pull tab
                _StepsBottomSheetDock(
                  steps: _steps,
                  currentIndex: _idx,
                  onOpenRatio: (r) => setState(() => _sheetOpenRatio = r),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String? timerText;

  const _ToolTile({
    required this.icon,
    required this.active,
    this.timerText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: active ? .14 : .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: active ? .22 : .12)),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: .25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                )
              ]
            : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              icon,
              size: 34,
              color: Colors.white.withValues(alpha: active ? .95 : .70),
            ),
          ),
          if (timerText != null)
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black.withValues(alpha: .08)),
                ),
                child: Text(
                  timerText!,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: _CookFlowScreenState._ink),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuIconButton extends StatelessWidget {
  final String title;
  final String imgUrl;
  final VoidCallback onTap;

  const _MenuIconButton({
    required this.title,
    required this.imgUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Material(
        color: Colors.white.withValues(alpha: .12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: .18)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  imgUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.restaurant, color: Colors.white70)),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 24,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: .55),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 4,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickMenuModal extends StatelessWidget {
  final String menuId;
  final List<Recipe> menus;
  final List<_FlowStep> steps;
  final Map<String, int> globalIndexByMenuStep;
  final VoidCallback onClose;

  const _QuickMenuModal({
    required this.menuId,
    required this.menus,
    required this.steps,
    required this.globalIndexByMenuStep,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final r = menus.where((x) => x.menuId == menuId).cast<Recipe?>().firstOrNull;
    final title = r?.name ?? menuId;

    final items = <_FlowStep>[];
    for (final s in steps) {
      if (s.menuId == menuId) items.add(s);
    }

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withValues(alpha: .35),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () {},
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
            child: Material(
              color: Colors.white.withValues(alpha: .78),
              borderRadius: BorderRadius.circular(22),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final it = items[i];
                        final gi = globalIndexByMenuStep['${it.menuId}#${it.localStepIndex}'];
                        final gNo = (gi == null) ? '-' : '${gi + 1}/${steps.length}';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .55),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: .35)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Global Step $gNo',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black54),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      it.title,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black87),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${it.seconds}s · local ${it.localStepIndex + 1}/${it.localTotal}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.chevron_right, color: Colors.black54),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14, top: 8),
                    child: Text(
                      '點空白位／按 X 關閉',
                      style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepsBottomSheetDock extends StatefulWidget {
  final List<_FlowStep> steps;
  final int currentIndex;
  final ValueChanged<double> onOpenRatio;

  const _StepsBottomSheetDock({
    required this.steps,
    required this.currentIndex,
    required this.onOpenRatio,
  });

  @override
  State<_StepsBottomSheetDock> createState() => _StepsBottomSheetDockState();
}

class _StepsBottomSheetDockState extends State<_StepsBottomSheetDock> {
  double _y = 0;
  double _maxY = 0;
  bool _init = false;

  void _notifyRatio() {
    final r = _maxY <= 0 ? 0 : (1 - (_y / _maxY)).clamp(0.0, 1.0);
    widget.onOpenRatio(r);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final h = c.maxHeight;
        _maxY = max(0, h);
        if (!_init) {
          _init = true;
          _y = _maxY; // closed
          WidgetsBinding.instance.addPostFrameCallback((_) => _notifyRatio());
        }

        final isOpen = _y <= 1;

        return Stack(
          children: [
            // pull tab
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: isOpen ? 0 : 1,
                child: IgnorePointer(
                  ignoring: isOpen,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _y = 0);
                        _notifyRatio();
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: .22)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .28),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            )
                          ],
                        ),
                        child: const Icon(Icons.keyboard_arrow_up, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // sheet
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: Transform.translate(
                  offset: Offset(0, _y),
                  child: GestureDetector(
                    onVerticalDragUpdate: (d) {
                      setState(() => _y = (_y + d.delta.dy).clamp(0.0, _maxY));
                      _notifyRatio();
                    },
                    onVerticalDragEnd: (d) {
                      final vy = d.primaryVelocity ?? 0; // px/s
                      setState(() {
                        if (vy > 650) _y = _maxY;
                        else if (vy < -650) _y = 0;
                        else _y = (_y > _maxY * 0.45) ? _maxY : 0;
                      });
                      _notifyRatio();
                    },
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Material(
                          color: Colors.white.withValues(alpha: .58),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          child: SizedBox(
                            height: h,
                            child: Column(
                              children: [
                                Container(
                                  height: 44,
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 56,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: .18),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: widget.steps.length,
                                    itemBuilder: (_, i) {
                                      final s = widget.steps[i];
                                      final isCur = i == widget.currentIndex;

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: isCur ? .70 : .45),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: Colors.white.withValues(alpha: .32)),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Step ${i + 1}/${widget.steps.length}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w900,
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    s.title,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w900,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    s.menuTitle,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              '${s.seconds}s',
                                              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              width: 22,
                                              height: 22,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: .55),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.black.withValues(alpha: .18)),
                                              ),
                                              child: Text(isCur ? '●' : ' '),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

extension _FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
