// lib/ui/screens/cooking/cook_flow_screen.dart
//
// 合併單菜/多菜：一頁完成（上面 6 個 tool icon + 中間單一步驟 + 右邊菜單圖按鈕 + 底部 draggable steps）
//
// ✅ 右邊菜單圖按鈕：最多顯示 5 個
// ✅ Step 顯示：本菜 steps + global step index（例：Dish Step 2/6 · Global 7/18）
//
// ✅ 已按你現有 model 對應欄位：
// Recipe: menuId / name / cover / steps
// RecipeStep: text / durationMin

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/data/recipes_data.dart';
import 'package:flutter_application_1/domain/models/recipe.dart';
import 'package:flutter_application_1/ui/widgets/glass.dart';
import 'package:flutter_application_1/ui/widgets/page_frame.dart';

class CookFlowScreen extends StatefulWidget {
  final Map<String, int> snapshot; // menuId -> qty
  final int totalPlannedMinutes;
  final String? titleOverride;

  const CookFlowScreen({
    super.key,
    required this.snapshot,
    required this.totalPlannedMinutes,
    this.titleOverride,
  });

  @override
  State<CookFlowScreen> createState() => _CookFlowScreenState();
}

class _CookFlowScreenState extends State<CookFlowScreen> {
  // ===== Tool icons（6 個）=====
  static const _toolKeys = <String>['pot', 'electric', 'oven', 'pan', 'knife', 'hands'];
  static const _toolIcons = <IconData>[
    Icons.local_fire_department, // pot
    Icons.electrical_services, // electric cooker
    Icons.outdoor_grill, // oven / grill
    Icons.local_dining, // pan
    Icons.content_cut, // knife
    Icons.pan_tool, // hands
  ];

  // ===== Flow data =====
  late final List<_MenuVm> _menus; // unique menus (for right buttons)
  late final List<_FlowStep> _steps; // expanded by qty (for global steps)
  late final int _globalTotal;

  // ===== Flow state =====
  int _idx = 0;
  bool _autoNext = true;
  bool _flowStarted = false;

  int _leftMs = 0;
  bool _running = false;
  bool _finished = false;

  late List<bool> _done;

  DateTime? _startAt;
  Timer? _ticker;

  // bottom sheet open ratio (0..1)
  double _sheetRatio = 0;

  @override
  void initState() {
    super.initState();

    _menus = _buildMenus(widget.snapshot);
    _steps = _buildSteps(_menus);
    _globalTotal = _steps.length;

    _done = List<bool>.filled(_globalTotal, false);

    final firstMs = _globalTotal > 0 ? _steps[0].durationMs : 0;
    _resetTimer(firstMs);
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  // ===== Build menus =====
  List<_MenuVm> _buildMenus(Map<String, int> snapshot) {
    final list = <_MenuVm>[];

    for (final e in snapshot.entries) {
      final r = kRecipeById[e.key];
      if (r == null) continue;
      final qty = max(1, e.value);
      final totalMin = r.steps.fold<int>(0, (s, st) => s + st.durationMin) * qty;

      list.add(
        _MenuVm(
          menuId: r.menuId,
          name: r.name,
          cover: r.cover,
          qty: qty,
          totalMin: totalMin,
          recipe: r,
        ),
      );
    }

    // 你講「先做最長嗰個」：先按 totalMin 由大到細排
    list.sort((a, b) => b.totalMin.compareTo(a.totalMin));
    return list;
  }

  // ===== Build steps (expanded by qty) =====
  List<_FlowStep> _buildSteps(List<_MenuVm> menus) {
    final out = <_FlowStep>[];
    var g = 0;

    for (final m in menus) {
      for (var inst = 1; inst <= m.qty; inst++) {
        final localTotal = m.recipe.steps.length;

        for (var i = 0; i < localTotal; i++) {
          final st = m.recipe.steps[i];
          final text = st.text.trim();
          final toolKey = _guessToolKey(text);

          out.add(
            _FlowStep(
              globalIndex: g,
              menuId: m.menuId,
              menuName: m.name,
              cover: m.cover,
              menuInstance: inst,
              menuInstanceTotal: m.qty,
              localIndex: i,
              localTotal: localTotal,
              text: text.isEmpty ? '(no text)' : text,
              durationMs: max(0, st.durationMin) * 60 * 1000,
              toolKey: toolKey,
            ),
          );
          g++;
        }
      }
    }

    return out;
  }

  String _guessToolKey(String text) {
    final t = text.toLowerCase();

    bool hasAny(List<String> ks) => ks.any((k) => t.contains(k));

    if (hasAny(['oven', 'bake', 'air fry', 'air-fry', 'roast'])) return 'oven';
    if (hasAny(['rice cooker', 'slow cooker', 'electric', 'pressure cooker'])) return 'electric';
    if (hasAny(['pan', 'fry', 'saute', 'sauté', 'skillet'])) return 'pan';
    if (hasAny(['boil', 'pot', 'soup', 'steam', 'simmer'])) return 'pot';
    if (hasAny(['chop', 'cut', 'slice', 'dice', 'mince'])) return 'knife';
    return 'hands';
  }

  // ===== Timer helpers =====
  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _resetTimer(int ms) {
    _stopTicker();
    _startAt = null;

    setState(() {
      _leftMs = ms;
      _running = false;
      _finished = false;
    });
  }

  void _startTimer(int ms) {
    _stopTicker();
    _startAt = DateTime.now();

    setState(() {
      _leftMs = ms;
      _running = true;
      _finished = false;
    });

    _ticker = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (_startAt == null) return;

      final elapsed = DateTime.now().difference(_startAt!).inMilliseconds;
      final left = max(0, ms - elapsed);

      if (left <= 0) {
        _stopTicker();
        _startAt = null;

        setState(() {
          _leftMs = 0;
          _running = false;
          _finished = true;
          if (_idx >= 0 && _idx < _done.length) _done[_idx] = true;
        });

        if (_autoNext && _flowStarted && _idx < _globalTotal - 1) {
          Future.delayed(const Duration(milliseconds: 220), () {
            if (!mounted) return;
            if (_idx < _globalTotal - 1) _goNext();
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _leftMs = left);
      }
    });
  }

  void _startOnce() {
    if (_flowStarted) return;
    if (_globalTotal == 0) return;

    setState(() => _flowStarted = true);
    _startTimer(_steps[_idx].durationMs);
  }

  void _goNext() {
    if (_globalTotal == 0) return;
    if (!_finished) return; // 未到 0 唔俾 Next

    if (_idx >= _globalTotal - 1) return;

    setState(() => _idx++);
    _resetTimer(_steps[_idx].durationMs);

    if (_flowStarted) {
      Future.delayed(const Duration(milliseconds: 40), () {
        if (!mounted) return;
        _startTimer(_steps[_idx].durationMs);
      });
    }
  }

  String _fmtLeft(int ms) {
    final sec = max(0, (ms / 1000).ceil());
    final mm = sec ~/ 60;
    final ss = sec % 60;
    if (mm <= 0) return '${ss}s';
    return '${mm}m ${ss}s';
  }

  String _fmtTileCount(int ms) {
    final sec = max(0, (ms / 1000).ceil());
    if (sec >= 100) return '${(sec / 60).ceil()}m';
    return sec.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    final cur = _globalTotal > 0 ? _steps[_idx] : null;

    final hideRightMenus = _sheetRatio > 0.22;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titleOverride ?? 'Cook Flow'),
      ),
      body: PageFrame(
        child: Stack(
          children: [
            // ===== Main scroll =====
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 140), // 預留俾 bottom sheet
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.titleOverride ?? (_menus.isNotEmpty ? _menus.first.name : 'Cooking'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${widget.totalPlannedMinutes} min',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ===== Top tools (6 icons) =====
                  glass(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Tools', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 6,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1,
                          ),
                          itemBuilder: (_, i) {
                            final key = _toolKeys[i];
                            final icon = _toolIcons[i];

                            final isActive = _flowStarted && cur != null && cur.toolKey == key;
                            final showCount = isActive && (_running || _finished) && key != 'hands';

                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActive ? Colors.white.withOpacity(0.38) : Colors.white.withOpacity(0.16),
                                ),
                                color: isActive ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.06),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Icon(
                                      icon,
                                      size: 34,
                                      color: isActive ? Colors.white : Colors.white70,
                                    ),
                                  ),
                                  if (showCount)
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.85),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          _fmtTileCount(_leftMs),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black87,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ===== Center step card =====
                  glass(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Step pill
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                                ),
                                child: Text(
                                  cur == null
                                      ? 'Step 0/0'
                                      : 'Global Step ${cur.globalIndex + 1}/$_globalTotal  ·  Dish Step ${cur.localIndex + 1}/${cur.localTotal}'
                                          '${cur.menuInstanceTotal > 1 ? '  (${cur.menuInstance}/${cur.menuInstanceTotal})' : ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Timer + toggle
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _fmtLeft(_leftMs),
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: _finished ? Colors.redAccent : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 34,
                                  child: OutlinedButton(
                                    onPressed: _flowStarted ? null : () => setState(() => _autoNext = !_autoNext),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.white.withOpacity(0.18)),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    child: Text('Auto Next: ${_autoNext ? 'ON' : 'OFF'}'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (cur == null)
                          const Text('No steps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))
                        else ...[
                          Text(
                            cur.menuName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            cur.text,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.18),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Dish Step ${cur.localIndex + 1}/${cur.localTotal} · Global ${cur.globalIndex + 1}/$_globalTotal · Duration ${_fmtLeft(cur.durationMs)}',
                            style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ],

                        const SizedBox(height: 14),

                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: (_globalTotal == 0 || !_finished) ? null : _goNext,
                            child: Text(_idx >= _globalTotal - 1 ? 'Finish' : 'Next step →',
                                style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Start once (outside)
                  glass(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 54,
                          width: 140,
                          child: FilledButton(
                            onPressed: (_flowStarted || _globalTotal == 0) ? null : _startOnce,
                            child: Text(_flowStarted ? 'Started' : 'Start',
                                style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _flowStarted ? '已啟動：每步入場自動計時。' : '按 Start 一次開始 Step1；之後每步自動開始倒數。',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ===== Right menu buttons (max 5) =====
            if (!hideRightMenus)
              Positioned(
                right: 6,
                top: 86,
                child: _RightMenusBar(
                  menus: _menus.take(5).toList(),
                  steps: _steps,
                  done: _done,
                  currentGlobalIndex: _idx,
                  globalTotal: _globalTotal,
                ),
              ),

            // ===== Bottom draggable steps sheet =====
            Positioned.fill(
              child: _StepsSheet(
                steps: _steps,
                done: _done,
                currentIdx: _idx,
                globalTotal: _globalTotal,
                onOpenRatio: (r) => setState(() => _sheetRatio = r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== View Models =====

class _MenuVm {
  final String menuId;
  final String name;
  final String cover;
  final int qty;
  final int totalMin;
  final Recipe recipe;

  _MenuVm({
    required this.menuId,
    required this.name,
    required this.cover,
    required this.qty,
    required this.totalMin,
    required this.recipe,
  });
}

class _FlowStep {
  final int globalIndex;

  final String menuId;
  final String menuName;
  final String cover;

  final int menuInstance; // 1..qty
  final int menuInstanceTotal;

  final int localIndex; // 0-based
  final int localTotal;

  final String text;
  final int durationMs;

  final String toolKey;

  _FlowStep({
    required this.globalIndex,
    required this.menuId,
    required this.menuName,
    required this.cover,
    required this.menuInstance,
    required this.menuInstanceTotal,
    required this.localIndex,
    required this.localTotal,
    required this.text,
    required this.durationMs,
    required this.toolKey,
  });
}

// ===== Right menus =====

class _RightMenusBar extends StatelessWidget {
  final List<_MenuVm> menus;
  final List<_FlowStep> steps;
  final List<bool> done;
  final int currentGlobalIndex;
  final int globalTotal;

  const _RightMenusBar({
    required this.menus,
    required this.steps,
    required this.done,
    required this.currentGlobalIndex,
    required this.globalTotal,
  });

  void _openMenu(BuildContext context, _MenuVm m) {
    final rows = <_FlowStep>[];
    for (final s in steps) {
      if (s.menuId == m.menuId) rows.add(s);
    }

    showDialog<void>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(m.qty > 1 ? '${m.name} ×${m.qty}' : m.name),
          content: SizedBox(
            width: double.maxFinite,
            height: min(520, max(260, rows.length * 56.0)),
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final st = rows[i];
                final isCur = st.globalIndex == currentGlobalIndex;
                final isDone = st.globalIndex >= 0 && st.globalIndex < done.length ? done[st.globalIndex] : false;

                return ListTile(
                  dense: true,
                  title: Text(
                    st.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: isCur ? FontWeight.w900 : FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Dish Step ${st.localIndex + 1}/${st.localTotal} · Global ${st.globalIndex + 1}/$globalTotal',
                  ),
                  trailing: isDone ? const Icon(Icons.check_circle, color: Colors.green) : const SizedBox(width: 18),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final m in menus) ...[
          GestureDetector(
            onTap: () => _openMenu(context, m),
            child: Container(
              width: 54,
              height: 54,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
                color: Colors.white.withOpacity(0.06),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    m.cover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.restaurant, color: Colors.white70)),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        m.qty.toString(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ===== Bottom draggable sheet =====

class _StepsSheet extends StatelessWidget {
  final List<_FlowStep> steps;
  final List<bool> done;
  final int currentIdx;
  final int globalTotal;
  final ValueChanged<double> onOpenRatio;

  const _StepsSheet({
    required this.steps,
    required this.done,
    required this.currentIdx,
    required this.globalTotal,
    required this.onOpenRatio,
  });

  @override
  Widget build(BuildContext context) {
    const minExtent = 0.12;
    const maxExtent = 0.92;

    return Align(
      alignment: Alignment.bottomCenter,
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (n) {
          final ratio = ((n.extent - minExtent) / (maxExtent - minExtent)).clamp(0.0, 1.0);
          onOpenRatio(ratio.toDouble()); // ✅ double
          return false;
        },
        child: DraggableScrollableSheet(
          minChildSize: minExtent,
          maxChildSize: maxExtent,
          initialChildSize: minExtent,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 58,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.30),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                      itemCount: steps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final st = steps[i];
                        final isCur = i == currentIdx;
                        final isDone = i >= 0 && i < done.length ? done[i] : false;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isCur ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(isCur ? 0.22 : 0.14)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Step ${st.globalIndex + 1}/$globalTotal',
                                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      st.text,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: isCur ? FontWeight.w900 : FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${st.menuName} · Dish ${st.localIndex + 1}/${st.localTotal}'
                                      '${st.menuInstanceTotal > 1 ? ' (${st.menuInstance}/${st.menuInstanceTotal})' : ''}',
                                      style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isDone ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                                ),
                                child: Text(isDone ? '✓' : ' ', style: const TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
