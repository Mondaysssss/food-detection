/// ✅ Cook Flow Screen (single dish / multi-dish unified version)
///
/// ✅ Two concurrent timers:
/// A) Step countdown (manual time): shown in the top-right of the Step card; must reach 0 before Next
/// B) Tile countdown (appliance time): shown in the 6 equipment tiles above (scrim + alarm shake + badge)
///    -> Hands-free: you can proceed to the next step; alerts "is ok" when time is up
///
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../../../state/app_state.dart';

import '../../../data/recipes_data.dart';
import '../../../domain/models/recipe.dart';
import '../../../domain/services/auth_service.dart';
import '../../widgets/cooking_gantt_chart.dart';
import '../home_shell.dart';

// ✅ Used throughout the file (including Bottom Sheet / Menu Modal)
String _fmtLeft(int ms) {
  final s = (ms / 1000).ceil();
  return '${max(0, s)}s';
}

/// ✅ Compatibility: RecipeStep internal field name may be requiredEquipment or requiredEq
String _readRequiredEquipment(RecipeStep st) {
  final d = st as dynamic;
  try {
    final v = d.requiredEquipment;
    if (v is String) return v;
  } catch (_) {}
  try {
    final v = d.requiredEq;
    if (v is String) return v;
  } catch (_) {}
  return '';
}

/// ✅ Compatibility: RecipeStep internal field name may be durationSec / durationSeconds / durationMin ...
/// Requirement: always return duration in seconds (aligned to recipes_data.dart 2nd arg, e.g. 3600=1hr).
int _readDurationSec(RecipeStep st) {
  final d = st as dynamic;

  // 1) Prefer "seconds" field name
  try {
    final v = d.durationSec;
    if (v is int) return v < 0 ? 0 : v;
    if (v is double) return v < 0 ? 0 : v.round();
  } catch (_) {}
  try {
    final v = d.durationSeconds;
    if (v is int) return v < 0 ? 0 : v;
    if (v is double) return v < 0 ? 0 : v.round();
  } catch (_) {}

  // 2) Fall back to old field name (originally used in CookFlowScreen)
  try {
    final v = d.durationMin;
    if (v is int) return v < 0 ? 0 : v;
    if (v is double) return v < 0 ? 0 : v.round();
  } catch (_) {}

  return 0;
}

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

enum _ToolKey { pot, stove, electric, electric2, oven }

// Hand timers: keyed by globalNo (unique per step)

class _FlowStep {
  final String menuId;
  final String menuName;
  final String? menuCover;

  // ✅ Timeline data (ipynb scheduling: seconds)
  final int startSec;
  final int endSec;

  final int globalNo; // 1-based
  final int globalTotal;

  final int dishNo; // 1-based within dish (using stepNumber)
  final int dishTotal;

  final int stepNumber; // original stepNumber (1-based)
  final String requiredEquipment; // from RecipeStep.requiredEquipment (trimmed)
  final bool isContinuous; // from RecipeStep.isContinuous
  final bool isConcurrent; // from RecipeStep.isConcurrent (= no attention needed)
  final bool isPrep;

  final String text;

  /// ✅ Source: scheduling result (endSec - startSec)
  /// - isConcurrent=true: used as Tile countdown (hands-free)
  /// - isConcurrent=false: used as Step countdown (must complete before Next)
  final int durationMs;

  final _ToolKey? tool;

  const _FlowStep({
    required this.menuId,
    required this.menuName,
    required this.menuCover,
    required this.startSec,
    required this.endSec,
    required this.globalNo,
    required this.globalTotal,
    required this.dishNo,
    required this.dishTotal,
    required this.stepNumber,
    required this.requiredEquipment,
    required this.isContinuous,
    required this.isConcurrent,
    required this.text,
    required this.durationMs,
    required this.tool,

    required this.isPrep,
  });

  bool get isHandStep => isConcurrent && tool == null;
}

/// Equipment countdown state (Tile)
class _ToolTimerState {
  final int ownerGlobalNo; // ✅ which global step this timer belongs to (used to determine ✓)
  final int totalMs;
  final DateTime startAt;
  int leftMs;
  bool running;
  bool finished;
  bool notified;

  _ToolTimerState({
    required this.ownerGlobalNo,
    required this.totalMs,
    required this.startAt,
    required this.leftMs,
    required this.running,
    required this.finished,
    required this.notified,
  });
}

// ---------- Minimal data structures needed by ipynb scheduler (kept in this file only, no other files modified) ----------

class _IpynbEvent {
  final int recipeIndex;
  final int stepIndex;
  final int startSec;
  final int endSec;
  final String equipment; // '' / 'stove' / 'oven' ...
  final bool needsAttention;

  _IpynbEvent({
    required this.recipeIndex,
    required this.stepIndex,
    required this.startSec,
    required this.endSec,
    required this.equipment,
    required this.needsAttention,
  });
}

class _IpynbSched {
  final int recipeIndex;
  final int stepIndex;
  final int startSec;
  final int endSec;
  final _ToolKey? tool; // null = hand/no-equipment concurrent step

  _IpynbSched({
    required this.recipeIndex,
    required this.stepIndex,
    required this.startSec,
    required this.endSec,
    required this.tool,
  });
}

class _CookFlowScreenState extends State<CookFlowScreen> {
  // theme-ish
  static const _bg = Color(0xFF0A0F18);
  static const _ink = Colors.white;

  // flow
  late final List<Recipe> _menus = _resolveMenus();
  late List<_FlowStep> _steps = const [];
  late int _cookwareCap;
  late int _electricCap;
  late int _ovenCap;

  int _idx = 0;

  // ✅ Truly complete (countdown done + user confirmed/advanced) counts as ✓
  final Set<int> _doneGlobalNos = <int>{};

  late Map<int, int> _prevSameRecipe = {};
  // ---------------------------
  // A) Step countdown (manual/hand)
  // ---------------------------
  bool _flowStarted = false;
  bool _running = false;
  bool _finished = false;
  int _leftMs = 0;
  bool _stepTimerStarted = false; // ✅ true only after user manually presses Start Timer
  bool _stepManuallyCompleted = false; // ✅ true only after user presses Complete
  // _ToolKey? _peekedTool; // ✅ currently peeked tile (null = no peek mode)
  Object? _peekedTile; // either _ToolKey or int (hand globalNo), or null

  Timer? _tick;
  DateTime? _startAt;
  int _stepMs = 0;

  // ---------------------------
  // B) Tool countdown (equipment Tile)
  // ---------------------------
  final Map<_ToolKey, _ToolTimerState> _toolTimers = {};
  Timer? _toolTick;
  final Map<int, _ToolTimerState> _handTimers = {}; // keyed by globalNo
  // is ok queue (prevents multiple simultaneous timer completions from flooding dialogs)
  //final List<_ToolKey> _okQueue = [];
  final List<Object> _okQueue = []; // _ToolKey, int (hand globalNo), or 'human'
  bool _okShowing = false;
  static const String _humanTimerKey = 'human';

  // bottom sheet open ratio -> hide right menu threshold
  double _sheetOpenRatio = 0.0;
  bool _hideRightMenus = false;

  // Gantt chart color map (built once on first open, reused afterwards)
  Map<String, Color>? _ganttColorMap;

  @override
  void initState() {
    super.initState();

    final app = context.read<AppState>();
    final a = app.appliances;
    _cookwareCap = min(a['cookware'] ?? 1, a['stove'] ?? 1);
    _electricCap = a['electric'] ?? 0;
    _ovenCap = a['bake'] ?? 0;

    _steps = _buildFlowSteps(_menus);
    _prevSameRecipe = _buildPrevSameRecipeMap(_steps);

    if (_steps.isNotEmpty) {
      _applyStep(_idx, startIfFlowStarted: false);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _toolTick?.cancel();
    _stopVibrationLoop();
    _audioPlayer.dispose();
    super.dispose();
  }

  List<GanttStep> _toGanttSteps() => _steps
      .map(
        (s) => GanttStep(
          menuId: s.menuId,
          menuName: s.menuName,
          stepNumber: s.stepNumber,
          startSec: s.startSec,
          endSec: s.endSec,
          isConcurrent: s.isConcurrent,
          isPrep: s.isPrep,
          text: s.text,
        ),
      )
      .toList();

  void _showGanttChart() {
    final ganttSteps = _toGanttSteps();
    _ganttColorMap ??= buildGanttColorMap(ganttSteps);
    final colorMap = _ganttColorMap!;
    debugPrint(ganttStepsToString(ganttSteps));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: CookingGanttCharts(steps: ganttSteps, colorMap: colorMap),
        ),
      ),
    );
  }
  // ---------- data: menus & steps ----------

  List<Recipe> _resolveMenus() {
    // by snapshot insertion order
    final out = <Recipe>[];
    widget.snapshot.forEach((menuId, qty) {
      if (qty <= 0) return;
      final r = kRecipeById[menuId];
      if (r != null) out.add(r);
    });

    // fallback: if snapshot matches no recipe
    if (out.isEmpty && kRecipes.isNotEmpty) {
      out.add(kRecipes.first);
    }

    // ✅ Fixed menu order (by menuId: r1,r2,...), ensures consistent scheduling for the same recipe set
    int _menuOrderKey(String id) {
      final m = RegExp(r'^r(\d+)$').firstMatch(id.trim());
      if (m == null) return 1 << 30;
      return int.tryParse(m.group(1)!) ?? (1 << 30);
    }

    out.sort((a, b) {
      final ka = _menuOrderKey(a.menuId);
      final kb = _menuOrderKey(b.menuId);
      if (ka != kb) return ka.compareTo(kb);
      return a.menuId.compareTo(b.menuId);
    });

    return out;
  }

  _ToolKey? _inferTool(String text) {
    final t = text.toLowerCase();
    if (t.contains('oven') || t.contains('bake') || t.contains('roast'))
      return _ToolKey.oven;
    if (t.contains('electric') ||
        t.contains('rice cooker') ||
        t.contains('slow cooker'))
      return _ToolKey.electric;
    if (t.contains('stove') ||
        t.contains('boil') ||
        t.contains('fry') ||
        t.contains('pan'))
      return _cookwareCap >= 2 ? _ToolKey.stove : _ToolKey.pot;
    if (t.contains('pot') || t.contains('soup') || t.contains('simmer'))
      return _ToolKey.pot;
    return null; // no equipment — human/hand step
  }

  // ---------- ipynb alignment: get equipment from RecipeStep, treat second parameter as seconds ----------

  String _normEquipment(String raw) => raw.trim().toLowerCase();

  int _stepDurationSec(RecipeStep st) {
    // ✅ Use the RecipeStep seconds from recipes_data.dart
    return _readDurationSec(st);
  }

  _ToolKey? _toolFromRecipeStep(RecipeStep st) {
    final eq = _normEquipment(_readRequiredEquipment(st));

    if (eq == 'stove') return _cookwareCap >= 2 ? _ToolKey.stove : _ToolKey.pot;
    if (eq == 'oven') return _ToolKey.oven;
    if (eq == 'pot') return _ToolKey.pot;
    if (eq == 'electric') return _ToolKey.electric;

    // No equipment + concurrent → hand (null = dynamic hand timer)
    if (st.isConcurrent) return null;

    // No equipment + attention → infer from text (may still be null)
    return _inferTool(st.text);
  }

  List<_FlowStep> _buildFlowSteps(List<Recipe> menus) {
    // ✅ New rules (based on latest requirements):
    // 1) Each dish must wait for the previous step to complete before starting the next (chain via endTime)
    // 2) isConcurrent=true means "6-tile background timer"; can do other recipe steps, but next step in same recipe waits for timer
    // 3) Scheduling prioritises opening Tile timers (minimise idle gaps), then handles attention steps
    // 4) All steps still follow each dish's step order (1->2->3...), UI layout unchanged
    if (menus.isEmpty) return const [];

    final stepsByRecipe = <List<RecipeStep>>[];
    for (final r in menus) {
      stepsByRecipe.add(r.steps);
    }

    final n = menus.length;
    final idx = List<int>.filled(n, 0);

    // ✅ Per dish: earliest start time for next step (after previous step ends)
    final readyAt = List<int>.filled(n, 0);

    // ✅ LRPT: pre-compute remaining prep / cook time (seconds) per dish
    final remainingPrepSec = List<int>.filled(n, 0);
    final remainingCookSec = List<int>.filled(n, 0);
    for (int r = 0; r < n; r++) {
      for (final st in stepsByRecipe[r]) {
        final dur = _stepDurationSec(st);
        if (st.isPrep) {
          remainingPrepSec[r] += dur;
        } else {
          remainingCookSec[r] += dur;
        }
      }
    }

    // ✅ Resource usage (cookware/electric/oven + attention)
    final usage = <String, int>{};

    int capOf(String res) {
      switch (res) {
        case 'cookware':
          return max(1, _cookwareCap);
        case 'electric':
          return max(0, _electricCap);
        case 'oven':
          return max(0, _ovenCap);
        case 'attention':
          return 1;
        case 'hand':
          return 9999;
        default:
          return 9999;
      }
    }

    int useOf(String res) => usage[res] ?? 0;

    final slotBusyUntil = <_ToolKey, int>{
      if (_cookwareCap >= 1) _ToolKey.pot: 0,
      if (_cookwareCap >= 2) _ToolKey.stove: 0,
      if (_electricCap >= 1) _ToolKey.electric: 0,
      if (_electricCap >= 2) _ToolKey.electric2: 0,
      if (_ovenCap >= 1) _ToolKey.oven: 0,
    };

    _ToolKey pickFreeSlot(List<_ToolKey> cands, int startSec) {
      for (final k in cands) {
        if ((slotBusyUntil[k] ?? 0) <= startSec) return k;
      }
      // Should not happen (cap already enforced), but fallback: pick earliest release
      _ToolKey best = cands.first;
      int bestEnd = slotBusyUntil[best] ?? 0;
      for (final k in cands.skip(1)) {
        final e = slotBusyUntil[k] ?? 0;
        if (e < bestEnd) {
          best = k;
          bestEnd = e;
        }
      }
      return best;
    }

    String _groupOf(RecipeStep st) {
      final eqRaw = _normEquipment(_readRequiredEquipment(st));
      final eq = (eqRaw == 'pot') ? 'cookware' : eqRaw;

      if (eq == 'stove' || eq == 'cookware') return 'cookware';
      if (eq == 'electric') return 'electric';
      if (eq == 'oven') return 'oven';

      if (eqRaw.isEmpty && st.isConcurrent) return 'hand';

      return '';
    }

    bool _canStart({required String group, required bool needsAttention}) {
      if (group.isNotEmpty && useOf(group) >= capOf(group)) return false;
      if (needsAttention && useOf('attention') >= capOf('attention'))
        return false;
      return true;
    }

    // ✅ Events: used to release resources & advance time
    final eventQ = <_IpynbEvent>[];
    int peekMinEnd() {
      int best = eventQ[0].endSec;
      for (int i = 1; i < eventQ.length; i++) {
        best = min(best, eventQ[i].endSec);
      }
      return best;
    }

    _IpynbEvent popMinEvent() {
      int bestI = 0;
      int bestEnd = eventQ[0].endSec;
      for (int i = 1; i < eventQ.length; i++) {
        final e = eventQ[i];
        if (e.endSec < bestEnd) {
          bestEnd = e.endSec;
          bestI = i;
        }
      }
      return eventQ.removeAt(bestI);
    }

    bool hasRemaining() {
      for (int r = 0; r < n; r++) {
        if (idx[r] < stepsByRecipe[r].length) return true;
      }
      return false;
    }

    final schedule = <_IpynbSched>[];
    int t = 0;

    while (hasRemaining()) {
      // A) Process completed events (end <= t)
      while (eventQ.isNotEmpty) {
        final minEnd = peekMinEnd();
        if (minEnd > t) break;

        final done = popMinEvent();
        if (done.equipment.isNotEmpty) {
          usage[done.equipment] = useOf(done.equipment) - 1;
        }
        if (done.needsAttention) {
          usage['attention'] = useOf('attention') - 1;
        }
      }

      // B) Pack as many steps as possible at the same time t
      bool scheduledAny = false;
      bool loopAgain = true;

      while (loopAgain) {
        loopAgain = false;

        // (1) Open Tile timers first: isConcurrent=true
        for (int r = 0; r < n; r++) {
          if (idx[r] >= stepsByRecipe[r].length) continue;
          if (readyAt[r] > t) continue;

          final st = stepsByRecipe[r][idx[r]];
          if (!st.isConcurrent) continue;

          final group = _groupOf(st);
          final needsAttention = false;

          if (!_canStart(group: group, needsAttention: needsAttention))
            continue;

          final dur = _stepDurationSec(st);
          final start = t;
          final end = t + dur;

          _ToolKey? tool;
          if (group == 'cookware') {
            final cands = [
              if (_cookwareCap >= 1) _ToolKey.pot,
              if (_cookwareCap >= 2) _ToolKey.stove,
            ];
            tool = pickFreeSlot(cands, start);
            slotBusyUntil[tool] = max(slotBusyUntil[tool] ?? 0, end);
          } else if (group == 'electric') {
            final eCands = [
              if (_electricCap >= 1) _ToolKey.electric,
              if (_electricCap >= 2) _ToolKey.electric2,
            ];
            tool = pickFreeSlot(eCands, start);
            slotBusyUntil[tool] = max(slotBusyUntil[tool] ?? 0, end);
          } else if (group == 'oven') {
            tool = _ToolKey.oven;
            slotBusyUntil[tool] = max(slotBusyUntil[tool] ?? 0, end);
          } else if (group == 'hand') {
            tool = null;
          } else {
            tool = null;
          }

          schedule.add(
            _IpynbSched(
              recipeIndex: r,
              stepIndex: idx[r],
              startSec: start,
              endSec: end,
              tool: tool,
            ),
          );

          eventQ.add(
            _IpynbEvent(
              recipeIndex: r,
              stepIndex: idx[r],
              startSec: start,
              endSec: end,
              equipment: group,
              needsAttention: needsAttention,
            ),
          );

          if (group.isNotEmpty) {
            usage[group] = useOf(group) + 1;
          }

          // ✅ LRPT: deduct remaining time
          if (st.isPrep) {
            remainingPrepSec[r] -= dur;
          } else {
            remainingCookSec[r] -= dur;
          }

          idx[r] += 1;
          readyAt[r] = end;
          scheduledAny = true;
          loopAgain = true;
        }

        // (2) Then handle attention steps (at most 1 at a time, since attention=1)
        //     ✅ Prioritise isPrep=true steps (prep steps go first)
        //     ✅ LRPT: among same type (both prep or both cook), pick recipe with longest remaining time
        if (useOf('attention') < capOf('attention')) {
          int bestR = -1;
          bool bestIsPrep = false;
          int bestRemaining = -1;
          for (int r = 0; r < n; r++) {
            if (idx[r] >= stepsByRecipe[r].length) continue;
            if (readyAt[r] > t) continue;

            final st = stepsByRecipe[r][idx[r]];
            if (st.isConcurrent) continue;

            final group = _groupOf(st);
            if (!_canStart(group: group, needsAttention: true)) continue;

            // LRPT: prep uses remainingPrepSec, cook uses remainingCookSec
            final rem = st.isPrep ? remainingPrepSec[r] : remainingCookSec[r];

            // Prioritise isPrep=true; same priority uses LRPT (longest remaining time first)
            if (bestR == -1 ||
                (st.isPrep && !bestIsPrep) ||
                (st.isPrep == bestIsPrep && rem > bestRemaining)) {
              bestR = r;
              bestIsPrep = st.isPrep;
              bestRemaining = rem;
            }
          }

          if (bestR >= 0) {
            final r = bestR;
            final st = stepsByRecipe[r][idx[r]];
            final group = _groupOf(st);
            final needsAttention = true;

            final dur = _stepDurationSec(st);
            final start = t;
            final end = t + dur;

            final tool = _toolFromRecipeStep(st);

            schedule.add(
              _IpynbSched(
                recipeIndex: r,
                stepIndex: idx[r],
                startSec: start,
                endSec: end,
                tool: tool,
              ),
            );

            eventQ.add(
              _IpynbEvent(
                recipeIndex: r,
                stepIndex: idx[r],
                startSec: start,
                endSec: end,
                equipment: group,
                needsAttention: needsAttention,
              ),
            );

            if (group.isNotEmpty) {
              usage[group] = useOf(group) + 1;
            }
            usage['attention'] = useOf('attention') + 1;

            // ✅ LRPT: deduct remaining time
            if (st.isPrep) {
              remainingPrepSec[r] -= dur;
            } else {
              remainingCookSec[r] -= dur;
            }

            idx[r] += 1;
            readyAt[r] = end;
            scheduledAny = true;
            loopAgain = true;
          }
        }
      }

      // C) If nothing can be scheduled at this time, advance to next earliest completion event
      if (!scheduledAny) {
        if (eventQ.isNotEmpty) {
          t = peekMinEnd();
        } else {
          break;
        }
      }
    }

    schedule.sort((a, b) {
      final c = a.startSec.compareTo(b.startSec);
      if (c != 0) return c;
      final cr = a.recipeIndex.compareTo(b.recipeIndex);
      if (cr != 0) return cr;
      return a.stepIndex.compareTo(b.stepIndex);
    });

    final total = schedule.length;
    if (total == 0) return const [];

    final out = <_FlowStep>[];
    for (int g = 0; g < schedule.length; g++) {
      final s = schedule[g];
      final r = menus[s.recipeIndex];
      final st = r.steps[s.stepIndex];

      final startSec = s.startSec;
      final endSec = s.endSec;
      final durMs = max(0, (endSec - startSec) * 1000);

      final stepNo = (st.stepNumber <= 0) ? (s.stepIndex + 1) : st.stepNumber;
      final dishTotal = r.steps.length;
      final eq = _normEquipment(_readRequiredEquipment(st));

      out.add(
        _FlowStep(
          menuId: r.menuId,
          menuName: r.name,
          menuCover: r.cover,
          startSec: startSec,
          endSec: endSec,
          globalNo: g + 1,
          globalTotal: total,
          dishNo: stepNo,
          dishTotal: dishTotal,
          stepNumber: stepNo,
          requiredEquipment: eq,
          isContinuous: st.isContinuous,
          isConcurrent: st.isConcurrent,
          isPrep: st.isPrep,
          text: st.text,
          durationMs: durMs,
          tool: s.tool,
        ),
      );
    }

    return out;
  }

  // ---------- rules: human vs tool ----------

  bool _isToolTimerStep(_FlowStep s) {
    // ✅ ipynb alignment: isConcurrent=true => no attention needed => runs as equipment/background timer (hands-free)
    // (UI unchanged: still displayed as Tile timer, Step timer locks Next)
    return s.isConcurrent;
  }

  Map<int, int> _buildPrevSameRecipeMap(List<_FlowStep> steps) {
    final last = <String, int>{};
    final out = <int, int>{};
    for (final s in steps) {
      final prev = last[s.menuId] ?? 0;
      out[s.globalNo] = prev;
      last[s.menuId] = s.globalNo;
    }
    return out;
  }

  bool _isCurrentHumanDone(_FlowStep cur) {
    if (_isToolTimerStep(cur)) return true;
    if (_stepMs <= 0) return true;
    return _leftMs <= 0;
  }

  bool _prereqDoneForTargetIndex(int targetIndex, _FlowStep cur) {
    if (targetIndex < 0 || targetIndex >= _steps.length) return false;
    final target = _steps[targetIndex];

    final prev = _prevSameRecipe[target.globalNo] ?? 0;
    if (prev == 0) return true;

    if (_doneGlobalNos.contains(prev)) return true;

    // ✅ Allowed: prev is the current step and it is a "hand step" that has finished countdown
    // (because hand steps are added to _doneGlobalNos only after pressing Next)
    if (prev == cur.globalNo &&
        !_isToolTimerStep(cur) &&
        _isCurrentHumanDone(cur)) {
      return true;
    }

    return false;
  }

  // ---------- equipment contention helpers ----------

  /// Returns the equipment group that a _ToolKey belongs to (consistent with scheduler)
  String _equipmentGroupOf(_ToolKey k) {
    switch (k) {
      case _ToolKey.pot:
      case _ToolKey.stove:
        return 'cookware';
      case _ToolKey.electric:
      case _ToolKey.electric2:
        return 'electric';
      case _ToolKey.oven:
        return 'oven';
      default:
        return ''; // prep / hands: no equipment, no resource use
    }
  }

  int _equipmentCap(String group) {
    switch (group) {
      case 'cookware':
        return 2;
      case 'electric':
        return 2;
      case 'oven':
        return 1;
      default:
        return 9999;
    }
  }

  String _equipmentDisplayName(String group) {
    switch (group) {
      case 'cookware':
        return 'stove / pot';
      case 'electric':
        return 'electric cooker';
      case 'oven':
        return 'oven';
      default:
        return group;
    }
  }

  /// Returns a hint string if the current tile step's required equipment is full; null if available
  String? _startTimerBlockReason() {
    if (_steps.isEmpty) return null;
    final cur = _steps[_idx];
    // ✅ Same recipe has a preceding tile timer running: all steps must wait (concurrent or non-concurrent)
    if (_hasPrecedingRunningTileTimer()) return 'Waiting for previous step…';
    if (!_isToolTimerStep(cur)) return null; // human step: not subject to equipment constraints

    // Hand step: no equipment contention
    if (cur.tool == null) return null;

    final group = _equipmentGroupOf(cur.tool!);
    if (group.isEmpty) return null; // no equipment: no blocking

    // Count running timers belonging to the same equipment group
    int running = 0;
    _toolTimers.forEach((k, t) {
      if (t.running && _equipmentGroupOf(k) == group) running++;
    });

    if (running >= _equipmentCap(group)) {
      final name = _equipmentDisplayName(group);
      return 'Waiting for $name to be free…';
    }
    return null;
  }

  /// Returns true if a preceding tile timer from the same recipe is still running (Next should be blocked)
  bool _hasPrecedingRunningTileTimer() {
    if (_steps.isEmpty) return false;
    final cur = _steps[_idx];

    // Check equipment timers
    for (final entry in _toolTimers.entries) {
      final t = entry.value;
      if (!t.running && !t.finished) continue;
      final ownerIdx = t.ownerGlobalNo - 1;
      if (ownerIdx < 0 || ownerIdx >= _steps.length) continue;
      final ownerStep = _steps[ownerIdx];
      if (ownerStep.menuId == cur.menuId && ownerStep.globalNo < cur.globalNo) {
        return true;
      }
    }

    // Check hand timers (same logic)
    for (final entry in _handTimers.entries) {
      final t = entry.value;
      if (!t.running && !t.finished) continue;
      final ownerIdx = t.ownerGlobalNo - 1;
      if (ownerIdx < 0 || ownerIdx >= _steps.length) continue;
      final ownerStep = _steps[ownerIdx];
      if (ownerStep.menuId == cur.menuId && ownerStep.globalNo < cur.globalNo) {
        return true;
      }
    }

    return false;
  }

  bool _calcCanNext() {
    if (!_flowStarted) return false;
    if (_steps.isEmpty) return false;
    if (_peekedTile != null) return false;

    final cur = _steps[_idx];

    // ✅ Same recipe has preceding tile timer still running: Next locked
    if (_hasPrecedingRunningTileTimer()) return false;

    if (_isToolTimerStep(cur)) {
      // ✅ Concurrent step: can proceed to Next after timer starts
      if (_idx >= _steps.length - 1) {
        // Last step: requires Complete or natural countdown finish (OK dialog)
        return _stepManuallyCompleted || _doneGlobalNos.contains(cur.globalNo);
      }
      return _stepTimerStarted || _stepManuallyCompleted;
    } else {
      // ✅ Non-concurrent step: Next is only allowed after pressing Complete
      return _stepManuallyCompleted;
    }
  }

  // ---------- A) Step countdown control (human) ----------

  void _stopTick() {
    _tick?.cancel();
    _tick = null;
  }

  void _resetToStepHuman(int ms, {required bool startIfFlowStarted}) {
    _stopTick();

    _stepMs = ms;
    _leftMs = ms;
    _running = false;
    _finished = false;
    _startAt = null;

    // human duration=0: considered complete (can Next)
    if (ms <= 0) {
      _finished = true;
      _leftMs = 0;
      return;
    }

    if (startIfFlowStarted && _flowStarted) {
      _startCountdownHuman(ms);
    }
  }

  void _startCountdownHuman(int ms) {
    _stopTick();

    _stepMs = ms;
    _leftMs = ms;
    _running = true;
    _finished = false;
    _startAt = DateTime.now();

    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final start = _startAt;
      if (start == null) return;

      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final left = max(0, _stepMs - elapsed);

      // minimise rebuilds
      if ((left - _leftMs).abs() >= 180 || left == 0) {
        setState(() => _leftMs = left);
      }

      if (left <= 0) {
        _stopTick();
        setState(() {
          _leftMs = 0;
          _running = false;
          _finished = _calcCanNext();
        });
        _enqueueIsOk(_humanTimerKey);
      }
    });
  }

  // ---------- B) Tool countdown control (tile) ----------

  void _startOrKeepToolTimer(
    _ToolKey tool,
    int ms, {
    required int ownerGlobalNo,
  }) {
    if (ms <= 0) return;

    final existing = _toolTimers[tool];
    if (existing != null && existing.running) {
      // Already running: do not restart (prevents reset when navigating back to step)
      return;
    }

    _toolTimers[tool] = _ToolTimerState(
      ownerGlobalNo: ownerGlobalNo,
      totalMs: ms,
      startAt: DateTime.now(),
      leftMs: ms,
      running: true,
      finished: false,
      notified: false,
    );

    _ensureToolTick();

    if (mounted) setState(() {});
  }

  void _startOrKeepHandTimer(int globalNo, int ms) {
    if (ms <= 0) return;
    final existing = _handTimers[globalNo];
    if (existing != null && existing.running) return;

    _handTimers[globalNo] = _ToolTimerState(
      ownerGlobalNo: globalNo,
      totalMs: ms,
      startAt: DateTime.now(),
      leftMs: ms,
      running: true,
      finished: false,
      notified: false,
    );

    _ensureToolTick();
    if (mounted) setState(() {});
  }

  void _ensureToolTick() {
    if (_toolTick != null) return;

    _toolTick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;

      bool needSetState = false;
      final now = DateTime.now();

      _toolTimers.forEach((k, t) {
        if (!t.running) return;

        final elapsed = now.difference(t.startAt).inMilliseconds;
        final left = max(0, t.totalMs - elapsed);

        if ((left - t.leftMs).abs() >= 180 || left == 0) {
          t.leftMs = left;
          needSetState = true;
        }

        if (left <= 0) {
          t.leftMs = 0;
          t.running = false;
          t.finished = true;

          if (!t.notified) {
            t.notified = true;
            _enqueueIsOk(k);
            needSetState = true;
          }
        }
      });

      _handTimers.forEach((gNo, t) {
        if (!t.running) return;
        final elapsed = now.difference(t.startAt).inMilliseconds;
        final left = max(0, t.totalMs - elapsed);
        if ((left - t.leftMs).abs() >= 180 || left == 0) {
          t.leftMs = left;
          needSetState = true;
        }
        if (left <= 0) {
          t.leftMs = 0;
          t.running = false;
          t.finished = true;
          if (!t.notified) {
            t.notified = true;
            _enqueueIsOk(gNo); // int, not _ToolKey
            needSetState = true;
          }
        }
      });

      final anyRunning =
          _toolTimers.values.any((t) => t.running) ||
          _handTimers.values.any((t) => t.running);
      if (!anyRunning) {
        _toolTick?.cancel();
        _toolTick = null;
      }

      if (needSetState)
        setState(() {
          // ✅ On equipment release / timer completion, sync Next button and Start Timer state
          _finished = _calcCanNext();
        });
    });
  }

  // ---------- vibration helpers ----------
  Timer? _vibrationTimer;
  bool _vibrating = false;
  final _audioPlayer = AudioPlayer();

  void _startVibrationLoop() {
    if (_vibrating) return;
    _vibrating = true;
    Vibration.vibrate(duration: 500);
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (!_vibrating) return;
      Vibration.vibrate(duration: 500);
    });
  }

  void _stopVibrationLoop() {
    _vibrating = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    Vibration.cancel();
    _audioPlayer.stop();
  }

  // ---------- timer-finished message builder (Approach C) ----------

  String _buildTimerMsg(Object k) {
    if (k == _humanTimerKey) {
      final s = _steps[_idx];
      return 'Step timer done! (${s.menuName})';
    }
    if (k is _ToolKey) {
      final t = _toolTimers[k];
      final gNo = t?.ownerGlobalNo ?? 0;
      final s = _steps.cast<_FlowStep?>().firstWhere(
        (s) => s!.globalNo == gNo,
        orElse: () => null,
      );
      final recipeName = s?.menuName ?? '';
      final label = _equipmentLabel(k);
      return '$label timer done! ($recipeName)';
    }
    if (k is int) {
      // hand timer — keyed by globalNo
      final s = _steps.cast<_FlowStep?>().firstWhere(
        (s) => s!.globalNo == k,
        orElse: () => null,
      );
      final recipeName = s?.menuName ?? '';
      return 'Background task done! ($recipeName)';
    }
    return 'Timer done!';
  }

  String _equipmentLabel(_ToolKey k) {
    switch (k) {
      case _ToolKey.pot:
      case _ToolKey.stove:
        return 'Stove';
      case _ToolKey.oven:
        return 'Oven';
      case _ToolKey.electric:
      case _ToolKey.electric2:
        return 'Electric cooker';
    }
  }

  // ---------- ok-queue ----------

  void _enqueueIsOk(Object k) {
    if (_okQueue.contains(k)) return;
    _okQueue.add(k);
    _drainIsOkQueue();
  }

  Future<void> _drainIsOkQueue() async {
    if (_okShowing || !mounted) return;
    if (_okQueue.isEmpty) return;

    _okShowing = true;
    final k = _okQueue.removeAt(0);

    HapticFeedback.heavyImpact();
    _startVibrationLoop();

    final msg = _buildTimerMsg(k);
    final isHuman = k == _humanTimerKey;
    final hint = isHuman
        ? 'Press Complete to move on.'
        : 'Tap the tile above then press Complete to dismiss it.';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(msg),
        content: Text(hint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // stop vibration only when no more queued alerts
    if (_okQueue.isEmpty) {
      _stopVibrationLoop();
    }

    if (mounted) {
      setState(() {
        _finished = _calcCanNext();
      });
    }

    _okShowing = false;

    if (mounted && _okQueue.isNotEmpty) {
      _drainIsOkQueue();
    }
  }

  // ---------- step switching ----------

  void _applyStep(int index, {required bool startIfFlowStarted}) {
    if (_steps.isEmpty) return;
    final s = _steps[index];

    final isTool = _isToolTimerStep(s);

    // ✅ Manual countdown: isConcurrent=false — never auto-starts, waits for user to press Start Timer
    final humanMs = isTool ? 0 : s.durationMs;
    _resetToStepHuman(humanMs, startIfFlowStarted: false);

    // ✅ Tile step: does not auto-start timer; but if tile is already running (or done, awaiting Complete),
    //    set _stepTimerStarted = true so the button shows Complete
    if (isTool) {
      if (s.tool != null) {
        // Equipment tile
        final existing = _toolTimers[s.tool!];
        _stepTimerStarted =
            existing != null &&
            existing.ownerGlobalNo == s.globalNo &&
            (existing.running || existing.finished);
      } else {
        // Hand tile
        final existing = _handTimers[s.globalNo];
        _stepTimerStarted =
            existing != null && (existing.running || existing.finished);
      }
    } else {
      _stepTimerStarted = false;
    }

    // ✅ Reset manually-completed and peek state when switching steps
    _stepManuallyCompleted = s.durationMs <= 0; // zero-duration steps auto-complete
    _peekedTile = null;

    // ✅ Whether Next Step button is enabled
    _finished = _calcCanNext();
  }

  void _startOnce() {
    if (_flowStarted) return;
    if (_steps.isEmpty) return;

    setState(() {
      _flowStarted = true;
      _applyStep(_idx, startIfFlowStarted: true);
    });
  }

  // ✅ User manually presses "Start Timer": starts the current step's timer
  void _startStepTimer() {
    if (!_flowStarted || _stepTimerStarted) return;
    if (_steps.isEmpty) return;
    if (_hasPrecedingRunningTileTimer()) return; // ✅ preceding tile still running: cannot start

    final s = _steps[_idx];
    final isTool = _isToolTimerStep(s);

    setState(() {
      _stepTimerStarted = true;
      _stepManuallyCompleted = false; // ✅ reset complete state when restarting timer
      _doneGlobalNos.remove(s.globalNo); // ✅ undo accidental complete
      if (isTool) {
        if (s.durationMs > 0) {
          if (s.tool != null) {
            _startOrKeepToolTimer(
              s.tool!,
              s.durationMs,
              ownerGlobalNo: s.globalNo,
            );
          } else {
            _startOrKeepHandTimer(s.globalNo, s.durationMs);
          }
        }
      } else {
        if (s.durationMs > 0) {
          _startCountdownHuman(s.durationMs);
        }
      }
      _finished = _calcCanNext();
    });
  }

  // ---------- new: complete / peek helpers ----------

  void _doCompleteEquipmentTile(_ToolKey tool) {
    final owner = _toolTimers[tool]?.ownerGlobalNo;
    _toolTimers.remove(tool);
    if (owner != null) _doneGlobalNos.add(owner);
    if (_peekedTile is _ToolKey && _peekedTile == tool) _peekedTile = null;
  }

  void _doCompleteHandTile(int globalNo) {
    _handTimers.remove(globalNo); // ← tile disappears entirely
    _doneGlobalNos.add(globalNo);
    if (_peekedTile is int && _peekedTile == globalNo) _peekedTile = null;
  }

  void _completeCurrentStep() {
    if (!_flowStarted || _steps.isEmpty) return;

    // Peek mode
    if (_peekedTile != null) {
      setState(() {
        if (_peekedTile is _ToolKey) {
          _doCompleteEquipmentTile(_peekedTile as _ToolKey);
        } else if (_peekedTile is int) {
          _doCompleteHandTile(_peekedTile as int);
        }
        _peekedTile = null;
        _finished = _calcCanNext();
      });
      return;
    }

    final s = _steps[_idx];
    final isTool = _isToolTimerStep(s);

    setState(() {
      _stepManuallyCompleted = true;
      _stepTimerStarted = false;

      if (isTool) {
        if (s.tool != null) {
          _doCompleteEquipmentTile(s.tool!);
        } else {
          _doCompleteHandTile(s.globalNo);
        }
      } else {
        _stopTick();
        _running = false;
        _doneGlobalNos.add(s.globalNo);
      }
      _finished = _calcCanNext();
    });
  }

  void _togglePeekEquipment(_ToolKey tool) {
    // Don't peek the tile if it belongs to the current step
    final currentGNo = _steps.isEmpty ? -1 : _steps[_idx].globalNo;
    if (_toolTimers[tool]?.ownerGlobalNo == currentGNo) return;
    setState(() {
      _peekedTile = (_peekedTile == tool) ? null : tool;
      _finished = _calcCanNext();
    });
  }

  void _togglePeekHand(int globalNo) {
    // Don't peek the tile if it belongs to the current step
    final currentGNo = _steps.isEmpty ? -1 : _steps[_idx].globalNo;
    if (_handTimers[globalNo]?.ownerGlobalNo == currentGNo) return;
    setState(() {
      _peekedTile = (_peekedTile == globalNo) ? null : globalNo;
      _finished = _calcCanNext();
    });
  }

  _FlowStep? _stepForPeeked(Object key) {
    int? ownerNo;
    if (key is _ToolKey) {
      ownerNo = _toolTimers[key]?.ownerGlobalNo;
    } else if (key is int) {
      ownerNo = _handTimers[key]?.ownerGlobalNo;
    }
    if (ownerNo == null) return null;
    for (final s in _steps) {
      if (s.globalNo == ownerNo) return s;
    }
    return null;
  }

  Future<void> _goNext() async {
    if (!_flowStarted || _steps.isEmpty) return;

    final cur = _steps[_idx];
    final isTool = _isToolTimerStep(cur);

    // ✅ Last step + tile: still needs to wait for OK (button enabled state controlled by _finished / _calcCanNext)
    if (!_finished) return;

    // ✅ Complete current step (regardless of timer state, pressing Next counts as done)
    if (!isTool) {
      _doneGlobalNos.add(cur.globalNo);
    }

    if (_idx >= _steps.length - 1) {
      final app = context.read<AppState>();
      final auth = AuthService();
      final user = auth.currentUser;
      final completedAt = DateTime.now();

      try {
        String sessionId = completedAt.microsecondsSinceEpoch.toString();

        if (user != null) {
          sessionId = await auth.saveCookSession(
            uid: user.uid,
            completedAt: completedAt,
            items: Map<String, int>.from(widget.snapshot),
            totalMinutes: widget.totalPlannedMinutes,
          );
        }

        app.addSessionFromCartSnapshot(
          id: sessionId,
          snapshot: widget.snapshot,
          totalMinutes: widget.totalPlannedMinutes,
          completedAt: completedAt,
        );

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 1)),
          (_) => false,
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save history. Please try again.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _idx++;
      _applyStep(_idx, startIfFlowStarted: true);
    });
  }

  void _goPrev() {
    if (!_flowStarted || _idx <= 0) return;

    setState(() {
      // ✅ Leaving current step: remove "completed" mark
      _doneGlobalNos.remove(_steps[_idx].globalNo);
      _idx--;
      // ✅ Going back to previous step: also remove its "completed" mark (hides ✓, allows redo)
      _doneGlobalNos.remove(_steps[_idx].globalNo);
      _applyStep(_idx, startIfFlowStarted: true);
    });
  }

  // ---------- sheet ratio / right menu hide (fix flicker) ----------

  void _onSheetOpenRatio(double ratio) {
    final r = ratio.clamp(0.0, 1.0);

    // throttle: skip setState for small changes to avoid flickering on slight drag
    if ((r - _sheetOpenRatio).abs() < 0.03) return;

    _sheetOpenRatio = r;

    // ✅ No longer hide menu buttons when pulling bottom sheet (avoids briefly disappearing on slight drag)
    if (_hideRightMenus) {
      setState(() => _hideRightMenus = false);
    }
  }

  // ---------- UI helpers ----------

  String _fmtLeftLocal(int ms) => _fmtLeft(ms);

  int _calcShakeMs({
    required int totalMs,
    required int leftMs,
    required bool finished,
  }) {
    if (finished) return 160;

    int base;
    if (totalMs >= 60 * 1000) {
      base = 520;
    } else if (totalMs >= 30 * 1000) {
      base = 420;
    } else if (totalMs >= 10 * 1000) {
      base = 340;
    } else {
      base = 300;
    }

    if (leftMs > 0 && leftMs <= 5000) {
      base = max(200, (base * 0.6).round());
    }
    return base;
  }

  bool _toolTimerActive(_ToolKey k) {
    final t = _toolTimers[k];
    return _flowStarted && t != null && (t.running || t.finished);
  }

  String _toolCountText(_ToolKey k) {
    final t = _toolTimers[k];
    if (t == null) return '';
    if (t.finished) return 'Done!';
    return _fmtLeft(t.leftMs);
  }

  int _toolShakeMs(_ToolKey k) {
    final t = _toolTimers[k];
    if (t == null) return 420;
    // ✅ Alarm keeps ringing after Tile naturally completes (reminds user to peek → Complete)
    if (t.finished) return 500;
    return _calcShakeMs(
      totalMs: t.totalMs,
      leftMs: t.leftMs,
      finished: t.finished,
    );
  }

  bool _toolTimerFinished(_ToolKey k) {
    return _toolTimers[k]?.finished ?? false;
  }

  bool _handTimerActive(int gNo) {
    final t = _handTimers[gNo];
    return _flowStarted && t != null && (t.running || t.finished);
  }

  String _handCountText(int gNo) {
    final t = _handTimers[gNo];
    if (t == null) return '';
    if (t.finished) return 'Done!';
    return _fmtLeft(t.leftMs);
  }

  int _handShakeMs(int gNo) {
    final t = _handTimers[gNo];
    if (t == null) return 420;
    if (t.finished) return 500;
    return _calcShakeMs(
      totalMs: t.totalMs,
      leftMs: t.leftMs,
      finished: t.finished,
    );
  }

  bool _handTimerFinished(int gNo) {
    return _handTimers[gNo]?.finished ?? false;
  }

  Future<void> _openMenuStepsDialog(Recipe r) async {
    // Find all steps for this dish within the global flow
    final items = <_FlowStep>[];
    for (final s in _steps) {
      if (s.menuId == r.menuId) items.add(s);
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Theme(
            data: Theme.of(context).copyWith(
              brightness: Brightness.light,
              textTheme: Theme.of(context).textTheme.apply(
                bodyColor: Colors.black87,
                displayColor: Colors.black87,
              ),
              iconTheme: const IconThemeData(color: Colors.black87),
            ),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 520),
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color.fromARGB(255, 19, 42, 116),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final s = items[i];

                        final curNo = _steps[_idx].globalNo;
                        final isCurrent = s.globalNo == curNo;
                        final done = _doneGlobalNos.contains(s.globalNo);

                        return ListTile(
                          dense: true,
                          title: Text(
                            'Step ${s.globalNo}/${s.globalTotal}  ·  ${s.menuName} ${s.dishNo}/${s.dishTotal}',
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: isCurrent
                                  ? Colors.black
                                  : Colors.black.withValues(alpha: 0.8),
                            ),
                          ),

                          // ✅ Menu step: green
                          subtitle: Text(
                            s.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: const Color.fromARGB(255, 19, 42, 116),
                            ),
                          ),

                          // ✅ Time: blue + ✓: black
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s.durationMs <= 0
                                    ? '-'
                                    : _fmtLeft(s.durationMs),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                done ? '✓' : '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          onTap: null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final step = _steps.isEmpty ? null : _steps[_idx];

    // Green border: only the exact current tool tile should glow.
    final _ToolKey? activeTool =
        (_stepTimerStarted && !_stepManuallyCompleted && step?.tool != null)
        ? step!.tool
        : null;
    final title = widget.titleOverride ?? 'Cooking';

    // ✅ Step card countdown text
    final bool isCurrTool = step != null && _isToolTimerStep(step);
    String stepTimeText;
    if (_stepManuallyCompleted) {
      stepTimeText = '0s';
    } else if (isCurrTool) {
      // Concurrent step: read from tile timer, or show full duration before start
      if (_stepTimerStarted) {
        if (step!.tool != null) {
          final t = _toolTimers[step.tool];
          stepTimeText = (t != null)
              ? (t.finished ? '0s' : _fmtLeft(t.leftMs))
              : '0s';
        } else {
          final t = _handTimers[step!.globalNo];
          stepTimeText = (t != null)
              ? (t.finished ? '0s' : _fmtLeft(t.leftMs))
              : '0s';
        }
      } else {
        // Before pressing Start: show the full duration
        stepTimeText = step!.durationMs > 0 ? _fmtLeft(step.durationMs) : '--';
      }
    } else if (_flowStarted && _stepMs > 0) {
      stepTimeText = _fmtLeft(_leftMs);
    } else {
      stepTimeText = '--';
    }

    final peekedStep = _peekedTile == null
        ? null
        : _stepForPeeked(_peekedTile!);
    final isPeeking = _peekedTile != null;

    // Current tile finished (equipment OR hand)
    final currentTileFinished =
        !isPeeking &&
        step != null &&
        _isToolTimerStep(step) &&
        (step.tool != null
            ? (_toolTimers[step.tool]?.finished ?? false)
            : (_handTimers[step.globalNo]?.finished ?? false));

    // Display timer text for peek
    String _peekedCountText() {
      if (_peekedTile is _ToolKey)
        return _toolCountText(_peekedTile as _ToolKey);
      if (_peekedTile is int) return _handCountText(_peekedTile as int);
      return '';
    }

    bool _peekedFinished() {
      if (_peekedTile is _ToolKey)
        return _toolTimerFinished(_peekedTile as _ToolKey);
      if (_peekedTile is int) return _handTimerFinished(_peekedTile as int);
      return false;
    }

    final displayTimerText = isPeeking
        ? _peekedCountText()
        : currentTileFinished
        ? 'Done!'
        : stepTimeText;
    final displayCountdownDone = isPeeking
        ? _peekedFinished()
        : currentTileFinished || (_stepMs > 0 && _leftMs <= 0);
    // Max 5 right-side menus (changed to horizontal Row at top)
    final menusForRight = _menus.take(5).toList(growable: false);

    final toolItems = <(_ToolKey, IconData)>[
      if (_cookwareCap >= 1) (_ToolKey.pot, Symbols.local_fire_department),
      if (_cookwareCap >= 2) (_ToolKey.stove, Symbols.local_fire_department),
      if (_electricCap >= 1) (_ToolKey.electric, Symbols.electrical_services),
      if (_electricCap >= 2) (_ToolKey.electric2, Symbols.electrical_services),
      if (_ovenCap >= 1) (_ToolKey.oven, Symbols.oven_gen),
    ];
    final handItems = _handTimers.keys
        .toList(); // List<int> of active globalNos
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Leave cooking?'),
            content: const Text('Your cooking progress will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 0)),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: _bg,
          foregroundColor: _ink,
          title: Text(title),
          actions: [
            // ← add this
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Schedule',
              onPressed: _showGanttChart,
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ✅ Menu image buttons horizontal: placed above the 6 equipment icons
                      _MenuRow(
                        menus: menusForRight,
                        hidden: _hideRightMenus,
                        onTap: _openMenuStepsDialog,
                      ),

                      const SizedBox(height: 12),

                      _ToolIconsFrame(
                        activeTool: activeTool,
                        permanentHandActive:
                            _flowStarted &&
                            _stepTimerStarted &&
                            !_stepManuallyCompleted &&
                            step != null &&
                            !step.isConcurrent &&
                            step.tool == null,
                        permanentHandFinished:
                            _flowStarted &&
                            _stepTimerStarted &&
                            !_running &&
                            !_stepManuallyCompleted &&
                            step != null &&
                            !step.isConcurrent &&
                            step.tool == null,
                        glowEnabled: _flowStarted,
                        items: toolItems,
                        handItems: handItems,
                        timerActiveOf: _toolTimerActive,
                        finishedOf: _toolTimerFinished,
                        shakeMsOf: _toolShakeMs,
                        countTextOf: _toolCountText,
                        handTimerActiveOf: _handTimerActive,
                        handFinishedOf: _handTimerFinished,
                        handShakeMsOf: _handShakeMs,
                        handCountTextOf: _handCountText,
                        peekedTile: _peekedTile,
                        onEquipmentTileTap: _togglePeekEquipment,
                        onHandTileTap: _togglePeekHand,
                      ),

                      const SizedBox(height: 12),

                      _StepCard(
                        step: isPeeking ? _stepForPeeked(_peekedTile!) : step,
                        flowStarted: _flowStarted,
                        running: _running,
                        canNext: _finished,
                        countdownDone: displayCountdownDone,
                        canPrev: _idx > 0,
                        timerStarted: isPeeking ? true : _stepTimerStarted,
                        // ✅ If timer has started, show Complete, do not revert to "Waiting for area"
                        startTimerBlockReason: (_stepTimerStarted || isPeeking)
                            ? null
                            : _startTimerBlockReason(),
                        leftText: displayTimerText,
                        isPeeking: isPeeking,
                        stepManuallyCompleted: _stepManuallyCompleted,
                        onNext: _goNext,
                        onPrev: _goPrev,
                        onStartTimer:
                            ((isPeeking ? _stepForPeeked(_peekedTile!) : step)
                                        ?.durationMs ??
                                    0) >
                                0
                            ? (isPeeking ? null : _startStepTimer)
                            : null,
                        onComplete: _completeCurrentStep,
                      ),

                      const SizedBox(height: 12),

                      _StartOnceBar(started: _flowStarted, onStart: _startOnce),
                    ],
                  ),
                ),
              ),

              _CookStepsSheet(
                steps: _steps,
                currentGlobalNo: step?.globalNo ?? 0,
                currentFinished: _finished,
                isDone: (g) => _doneGlobalNos.contains(g),
                onOpenRatio: _onSheetOpenRatio,
                onJumpToGlobalIndex: (globalNo) {
                  if (globalNo <= 0 || globalNo > _steps.length) return;
                  setState(() {
                    _idx = globalNo - 1;
                    _applyStep(_idx, startIfFlowStarted: true);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------- widgets -----------------

class _ToolIconsFrame extends StatelessWidget {
  final _ToolKey? activeTool; // exact current tool tile, if any
  final bool glowEnabled;
  final List<(_ToolKey, IconData)> items; // equipment tiles
  final List<int> handItems; // active hand tile globalNos

  // Equipment callbacks
  final bool Function(_ToolKey) timerActiveOf;
  final bool Function(_ToolKey) finishedOf;
  final int Function(_ToolKey) shakeMsOf;
  final String Function(_ToolKey) countTextOf;

  // Hand callbacks
  final bool Function(int) handTimerActiveOf;
  final bool Function(int) handFinishedOf;
  final int Function(int) handShakeMsOf;
  final String Function(int) handCountTextOf;

  // Permanent hand tile: green when non-concurrent step timer is running
  final bool permanentHandActive;
  // Golden pulse when non-concurrent step timer finished
  final bool permanentHandFinished;

  // Peek: Object? (either _ToolKey or int)
  final Object? peekedTile;
  final void Function(_ToolKey)? onEquipmentTileTap;
  final void Function(int)? onHandTileTap;

  const _ToolIconsFrame({
    required this.activeTool,
    required this.permanentHandActive,
    required this.permanentHandFinished,
    required this.glowEnabled,
    required this.items,
    required this.handItems,
    required this.timerActiveOf,
    required this.finishedOf,
    required this.shakeMsOf,
    required this.countTextOf,
    required this.handTimerActiveOf,
    required this.handFinishedOf,
    required this.handShakeMsOf,
    required this.handCountTextOf,
    this.peekedTile,
    this.onEquipmentTileTap,
    this.onHandTileTap,
  });

  static const _accent = Color(0xFF16A34A);
  static const _peekAccent = Color(0xFFFBBF24);
  static const _finishedAccent = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    // +1 for the permanent hand tile (always visible)
    final totalCount = items.length + 1 + handItems.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: GridView.builder(
        itemCount: totalCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: totalCount <= 2 ? 2 : 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemBuilder: (_, i) {
          if (i < items.length) {
            return _buildEquipmentTile(items[i].$1, items[i].$2);
          } else if (i == items.length) {
            return _buildPermanentHandTile();
          } else {
            final gNo = handItems[i - items.length - 1];
            return _buildHandTile(gNo);
          }
        },
      ),
    );
  }

  Widget _buildEquipmentTile(_ToolKey k, IconData icon) {
    final isPeeked = peekedTile is _ToolKey && peekedTile == k;

    final timerActive = timerActiveOf(k);
    final isFinished = finishedOf(k);
    final shakeMs = shakeMsOf(k);
    final countText = countTextOf(k);

    // Green when: running bg timer, OR this exact tool is the current step tool.
    final active =
        glowEnabled && !isFinished && (timerActive || activeTool == k);

    final borderColor = isFinished
        ? _finishedAccent.withValues(alpha: 0.90)
        : isPeeked
        ? _peekAccent.withValues(alpha: 0.85)
        : active
        ? _accent.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.10);
    final borderWidth = (isFinished || isPeeked || active) ? 2.5 : 1.0;
    final shadows = isFinished
        ? [
            BoxShadow(
              color: _finishedAccent.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 4),
            ),
          ]
        : isPeeked
        ? [
            BoxShadow(
              color: _peekAccent.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ]
        : active
        ? [
            BoxShadow(
              color: _accent.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ]
        : null;

    return GestureDetector(
      onTap: timerActive ? () => onEquipmentTileTap?.call(k) : null,
      child: SizedBox(
        width: 90,
        height: 90,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows,
          ),
          child: _tileStack(
            icon: icon,
            active: active,
            isPeeked: isPeeked,
            timerActive: timerActive,
            isFinished: isFinished,
            shakeMs: shakeMs,
            countText: countText,
          ),
        ),
      ),
    );
  }

  Widget _buildPermanentHandTile() {
    final finished = permanentHandFinished;
    final active = permanentHandActive && !finished;

    final borderColor = finished
        ? _finishedAccent.withValues(alpha: 0.90)
        : active
        ? _accent.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.10);
    final borderWidth = (finished || active) ? 2.5 : 1.0;
    final shadows = finished
        ? [
            BoxShadow(
              color: _finishedAccent.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 4),
            ),
          ]
        : active
        ? [
            BoxShadow(
              color: _accent.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ]
        : null;

    return SizedBox(
      width: 90,
      height: 90,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: shadows,
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Symbols.front_hand,
                size: 30,
                color: Colors.white.withValues(
                  alpha: (finished || active) ? 0.95 : 0.70,
                ),
              ),
            ),
            if (finished)
              Positioned.fill(
                child: _FinishedPulseOverlay(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandTile(int gNo) {
    final isPeeked = peekedTile is int && peekedTile == gNo;

    final timerActive = handTimerActiveOf(gNo);
    final isFinished = handFinishedOf(gNo);
    final shakeMs = handShakeMsOf(gNo);
    final countText = handCountTextOf(gNo);

    // Green when running (not finished)
    final active = glowEnabled && timerActive && !isFinished;

    final borderColor = isFinished
        ? _finishedAccent.withValues(alpha: 0.90)
        : isPeeked
        ? _peekAccent.withValues(alpha: 0.85)
        : active
        ? _accent.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.10);
    final borderWidth = (isFinished || isPeeked || active) ? 2.5 : 1.0;
    final shadows = isFinished
        ? [
            BoxShadow(
              color: _finishedAccent.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 4),
            ),
          ]
        : isPeeked
        ? [
            BoxShadow(
              color: _peekAccent.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ]
        : null;

    return GestureDetector(
      onTap: timerActive ? () => onHandTileTap?.call(gNo) : null,
      child: SizedBox(
        width: 90,
        height: 90,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows,
          ),
          child: _tileStack(
            icon: Symbols.front_hand,
            active: active,
            isPeeked: isPeeked,
            timerActive: timerActive,
            isFinished: isFinished,
            shakeMs: shakeMs,
            countText: countText,
          ),
        ),
      ),
    );
  }

  Widget _tileStack({
    required IconData icon,
    required bool active,
    required bool isPeeked,
    required bool timerActive,
    required bool isFinished,
    required int shakeMs,
    required String countText,
  }) {
    return Stack(
      children: [
        Center(
          child: Icon(
            icon,
            size: 30,
            color: Colors.white.withValues(alpha: active ? 0.95 : 0.70),
          ),
        ),
        if (timerActive)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        if (isPeeked)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: _peekAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        if (isFinished)
          Positioned.fill(
            child: _FinishedPulseOverlay(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        if (timerActive)
          Positioned.fill(child: _AlarmOverlay(shakeMs: shakeMs)),
        if (timerActive && countText.isNotEmpty)
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Text(
                countText,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AlarmOverlay extends StatefulWidget {
  final int shakeMs;

  const _AlarmOverlay({required this.shakeMs});

  @override
  State<_AlarmOverlay> createState() => _AlarmOverlayState();
}

class _AlarmOverlayState extends State<_AlarmOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late Animation<double> _rot;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.shakeMs),
    )..repeat();

    _rot = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.22), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.22, end: 0.22), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.22, end: -0.16), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.16, end: 0.16), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.16, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctl, curve: Curves.linear));
  }

  @override
  void didUpdateWidget(covariant _AlarmOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shakeMs != widget.shakeMs) {
      _ctl.duration = Duration(milliseconds: widget.shakeMs);
      _ctl
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedBuilder(
            animation: _rot,
            builder: (_, child) =>
                Transform.rotate(angle: _rot.value, child: child),
            child: Opacity(
              opacity: 0.85,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Icon(
                  Icons.alarm,
                  size: 96,
                  color: Colors.black.withValues(alpha: 0.80),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ✅ Pulsing orange edge glow — reminds user that tile is done but not yet Completed
class _FinishedPulseOverlay extends StatefulWidget {
  final BorderRadius borderRadius;

  const _FinishedPulseOverlay({required this.borderRadius});

  @override
  State<_FinishedPulseOverlay> createState() => _FinishedPulseOverlayState();
}

class _FinishedPulseOverlayState extends State<_FinishedPulseOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.10,
      end: 0.45,
    ).animate(CurvedAnimation(parent: _ctl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: const Color(
                0xFFF59E0B,
              ).withValues(alpha: _opacity.value * 2),
              width: 2.5,
            ),
            color: const Color(0xFFF59E0B).withValues(alpha: _opacity.value),
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final _FlowStep? step;
  final bool flowStarted;
  final bool running;
  final bool canNext; // ✅ Next/Finish button enabled
  final bool countdownDone; // ✅ countdown reached zero (color turns red)
  final bool canPrev;
  final bool timerStarted; // ✅ timer for current step has started
  final String? startTimerBlockReason; // ✅ non-null = equipment full, disabled + show reason
  final String leftText;
  final bool isPeeking; // ✅ currently peeking a background tile
  final bool stepManuallyCompleted; // ✅ user has pressed Complete
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback? onStartTimer; // null = this step has no duration, hide button
  final VoidCallback onComplete; // ✅ Complete button callback

  const _StepCard({
    required this.step,
    required this.flowStarted,
    required this.running,
    required this.canNext,
    required this.countdownDone,
    required this.canPrev,
    required this.timerStarted,
    this.startTimerBlockReason,
    required this.leftText,
    required this.isPeeking,
    required this.stepManuallyCompleted,
    required this.onNext,
    required this.onPrev,
    this.onStartTimer,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (step == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: const Text(
          'No steps',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      );
    }

    final s = step!;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step ${s.globalNo}/${s.globalTotal}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.menuName}  ${s.dishNo}/${s.dishTotal}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                flowStarted ? leftText : '--',
                style: TextStyle(
                  color: countdownDone
                      ? const Color(0xFFEF4444)
                      : Colors.white.withValues(alpha: running ? 0.95 : 0.65),
                  fontWeight: FontWeight.w900,
                  fontSize: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s.text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // ✅ Peek mode hint banner
          if (isPeeking) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.40),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.remove_red_eye_outlined,
                    color: Color(0xFFFBBF24),
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Background step — Tap tile again to return',
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ✅ Timer button area (three mutually exclusive states)
          // Display condition: has duration, and (peek mode OR this step has an operable timer)
          if (onStartTimer != null || isPeeking) ...[
            SizedBox(
              height: 48,
              child: startTimerBlockReason != null && !isPeeking
                  // ── State 1: preceding step not done / equipment full → disabled amber button
                  ? FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.hourglass_empty, size: 18),
                      label: Text(
                        startTimerBlockReason!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF7C3A00,
                        ).withValues(alpha: 0.30),
                        foregroundColor: const Color(0xFFFBBF24),
                        disabledBackgroundColor: const Color(
                          0xFF7C3A00,
                        ).withValues(alpha: 0.30),
                        disabledForegroundColor: const Color(0xFFFBBF24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(
                            color: Color(0xFFFBBF24),
                            width: 1,
                          ),
                        ),
                      ),
                    )
                  : timerStarted
                  // ── State 2: timer started (or peeking) → "Complete" green button
                  ? FilledButton.icon(
                      onPressed: flowStarted ? onComplete : null,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text(
                        'Complete',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(
                          0xFF16A34A,
                        ).withValues(alpha: 0.40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    )
                  // ── State 3: not yet started → "Start Timer" button
                  : FilledButton.icon(
                      onPressed: flowStarted ? onStartTimer : null,
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      label: const Text(
                        'Start Timer',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white.withValues(
                          alpha: 0.08,
                        ),
                        disabledForegroundColor: Colors.white.withValues(
                          alpha: 0.40,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
          ],

          // ✅ Navigation bar: ← Last step | Next step →
          SizedBox(
            height: 54,
            child: Row(
              children: [
                // ← Last step
                Expanded(
                  flex: 1,
                  child: FilledButton(
                    onPressed: (flowStarted && canPrev && !isPeeking)
                        ? onPrev
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withValues(
                        alpha: 0.06,
                      ),
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.25,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '← Last',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Next step → / Finish
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: (flowStarted && canNext) ? onNext : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withValues(
                        alpha: 0.10,
                      ),
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.35,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      (s.globalNo >= s.globalTotal) ? 'Finish' : 'Next step →',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StartOnceBar extends StatelessWidget {
  final bool started;
  final VoidCallback onStart;

  const _StartOnceBar({required this.started, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: started ? null : onStart,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.90),
              foregroundColor: const Color(0xFF0B1220),
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              started ? 'Started' : 'Start',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          started ? ' ' : ' ',
          //started ? 'Step card is a manual countdown; equipment countdown stays in Tile (will pop ok dialog when done).' : 'Press Start once to begin; manual steps must finish before Next.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MenuIconButton extends StatelessWidget {
  final String title;
  final String? imgUrl;
  final VoidCallback onTap;

  const _MenuIconButton({
    required this.title,
    required this.imgUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            color: Colors.white.withValues(alpha: 0.10),
          ),
          clipBehavior: Clip.antiAlias,
          child: imgUrl == null
              ? Icon(
                  Icons.restaurant_menu,
                  color: Colors.white.withValues(alpha: 0.85),
                )
              : Image.asset(
                  imgUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.restaurant_menu,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final List<Recipe> menus;
  final bool hidden;
  final Future<void> Function(Recipe r) onTap;

  const _MenuRow({
    required this.menus,
    required this.hidden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (menus.isEmpty) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: hidden ? 0 : 1,
      duration: const Duration(milliseconds: 140),
      child: IgnorePointer(
        ignoring: hidden,
        child: SizedBox(
          height: 66,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: menus.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final r = menus[i];
              return _MenuIconButton(
                title: r.name,
                imgUrl: r.cover.isEmpty ? null : r.cover,
                onTap: () => onTap(r),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CookStepsSheet extends StatefulWidget {
  final List<_FlowStep> steps;
  final int currentGlobalNo; // 1-based
  final bool currentFinished;
  final bool Function(int globalNo) isDone;
  final ValueChanged<double> onOpenRatio;
  final ValueChanged<int> onJumpToGlobalIndex;

  const _CookStepsSheet({
    required this.steps,
    required this.currentGlobalNo,
    required this.currentFinished,
    required this.isDone,
    required this.onOpenRatio,
    required this.onJumpToGlobalIndex,
  });

  @override
  State<_CookStepsSheet> createState() => _CookStepsSheetState();
}

class _CookStepsSheetState extends State<_CookStepsSheet> {
  final _ctl = DraggableScrollableController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        final minSize = 0.12;
        final maxSize = 0.92;
        final ratio = ((n.extent - minSize) / (maxSize - minSize)).clamp(
          0.0,
          1.0,
        );
        widget.onOpenRatio(ratio);
        setState(() {});
        return false;
      },
      child: DraggableScrollableSheet(
        controller: _ctl,
        minChildSize: 0.12,
        initialChildSize: 0.12,
        maxChildSize: 0.92,
        snap: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.58),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 26,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 58,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Text(
                        'All steps',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Total: ${widget.steps.length}',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: _ctl.isAttached && _ctl.size > 0.5
                            ? 'Close'
                            : 'Open',
                        onPressed: () {
                          if (_ctl.isAttached && _ctl.size > 0.5) {
                            _ctl.animateTo(
                              0.12,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            );
                          } else {
                            _ctl.animateTo(
                              0.92,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                        icon: Icon(
                          _ctl.isAttached && _ctl.size > 0.5
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: widget.steps.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = widget.steps[i];

                      final isCurrent = s.globalNo == widget.currentGlobalNo;
                      final done = widget.isDone(s.globalNo);

                      return ListTile(
                        dense: true,
                        title: Text(
                          'Step ${s.globalNo}/${s.globalTotal}  ·  ${s.menuName} ${s.dishNo}/${s.dishTotal}',
                          style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.w900
                                : FontWeight.w800,
                            color: isCurrent
                                ? Colors.black
                                : Colors.black.withValues(alpha: 0.85),
                          ),
                        ),

                        // ✅ Menu step: green
                        subtitle: Text(
                          s.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: const Color.fromARGB(255, 19, 42, 116),
                          ),
                        ),

                        // ✅ Time: blue + ✓: black
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              s.durationMs <= 0 ? '-' : _fmtLeft(s.durationMs),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              done ? '✓' : '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        onTap: null,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
