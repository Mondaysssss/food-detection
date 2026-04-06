/// ✅ Cook Flow Screen（單菜 / 多菜合併版）
///
/// ✅ 兩種計時同時存在：
/// A) Step 倒數（人手時間）：顯示喺 Step 卡右上角；倒數完先可以 Next
/// B) Tile 倒數（器具時間）：顯示喺上面 6 格工具 Tile（scrim + 鬧鐘搖擺 + badge）
///    -> 可離手：你可以去下一步照做；時間到會彈 "is ok"
///
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:provider/provider.dart';
import '../../../state/app_state.dart';

import '../../../data/recipes_data.dart';
import '../../../domain/models/recipe.dart';

// ✅ 供全檔使用（包括 Bottom Sheet / Menu Modal）
String _fmtLeft(int ms) {
  final s = (ms / 1000).ceil();
  return '${max(0, s)}s';
}

/// ✅ 兼容：RecipeStep 內部欄位名可能係 requiredEquipment 或 requiredEq
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

/// ✅ 兼容：RecipeStep 內部欄位名可能係 durationSec / durationSeconds / durationMin ...
/// 需求：一律以「秒」為單位返回（對齊 recipes_data.dart 第二參數，例如 3600=1hr）。
int _readDurationSec(RecipeStep st) {
  final d = st as dynamic;

  // 1) 優先讀「秒」命名
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

  // 2) 退回舊命名（你原本 CookFlowScreen 用緊）
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

enum _ToolKey { pot, stove, electric, electric2, oven, hands, prep }

class _FlowStep {
  final String menuId;
  final String menuName;
  final String? menuCover;

  // ✅ 時間軸資料（ipynb 排程用：秒）
  final int startSec;
  final int endSec;

  final int globalNo; // 1-based
  final int globalTotal;

  final int dishNo; // 1-based within dish（用 stepNumber）
  final int dishTotal;

  final int stepNumber; // 原始 stepNumber（1-based）
  final String requiredEquipment; // 來自 RecipeStep.requiredEquipment（trim 後）
  final bool isContinuous; // 來自 RecipeStep.isContinuous
  final bool isConcurrent; // 來自 RecipeStep.isConcurrent（= 不需要 attention）

  final String text;

  /// ✅ 來源：排程結果（endSec - startSec）
  /// - isConcurrent=true：用作 Tile 倒數（可離手）
  /// - isConcurrent=false：用作 Step 倒數（要做完先 Next）
  final int durationMs;

  final _ToolKey tool;

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
  });
}

/// 器具倒數狀態（Tile）
class _ToolTimerState {
  final int ownerGlobalNo; // ✅ 呢個 timer 屬於邊一個 global step（用嚟決定 ✓）
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

// ---------- ipynb 排程器需要的最小資料結構（只放喺本檔，唔改其他檔案） ----------

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
  final _ToolKey tool; // ✅ 已分配到 6 格 Tile 的其中一格（獨立 timer slot）

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

  // ✅ 真正完成（倒數完成 + 用戶確認/前進）先算 ✓
  final Set<int> _doneGlobalNos = <int>{};

  late Map<int, int> _prevSameRecipe = {};
  // ---------------------------
  // A) Step countdown（人手）
  // ---------------------------
  bool _flowStarted = false;
  bool _running = false;
  bool _finished = false;
  int _leftMs = 0;

  Timer? _tick;
  DateTime? _startAt;
  int _stepMs = 0;

  // ---------------------------
  // B) Tool countdown（器具 Tile）
  // ---------------------------
  final Map<_ToolKey, _ToolTimerState> _toolTimers = {};
  Timer? _toolTick;

  // is ok queue（避免同一刻多個 timer 完成爆 dialog）
  final List<_ToolKey> _okQueue = [];
  bool _okShowing = false;

  // bottom sheet open ratio -> hide right menu threshold
  double _sheetOpenRatio = 0.0;
  bool _hideRightMenus = false;

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
    super.dispose();
  }

  // ---------- data: menus & steps ----------

  List<Recipe> _resolveMenus() {
    // 依 snapshot insertion order
    final out = <Recipe>[];
    widget.snapshot.forEach((menuId, qty) {
      if (qty <= 0) return;
      final r = kRecipeById[menuId];
      if (r != null) out.add(r);
    });

    // fallback：如果 snapshot 冇中任何 recipe
    if (out.isEmpty && kRecipes.isNotEmpty) {
      out.add(kRecipes.first);
    }

    // ✅ 固定 menu 排序（按 menuId: r1,r2,...），令同一批食譜次次排程一致
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

  _ToolKey _inferTool(String text) {
    final t = text.toLowerCase();

    // 超簡單推斷（你將來會由 DB 決定）
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
      return _ToolKey.stove;
    if (t.contains('pot') || t.contains('soup') || t.contains('simmer'))
      return _ToolKey.pot;
    if (t.contains('chop') ||
        t.contains('slice') ||
        t.contains('wash') ||
        t.contains('mix'))
      return _ToolKey.prep;
    return _ToolKey.hands;
  }

  // ---------- ipynb 對齊：從 RecipeStep 取設備/並把「第二參數」視為秒 ----------

  String _normEquipment(String raw) => raw.trim().toLowerCase();

  int _stepDurationSec(RecipeStep st) {
    // ✅ 以 recipes_data.dart 的 RecipeStep "秒" 為準
    return _readDurationSec(st);
  }

  _ToolKey _toolFromRecipeStep(RecipeStep st) {
    final eq = _normEquipment(_readRequiredEquipment(st));

    // 1) 有明確設備：直接映射
    if (eq == 'stove') return _ToolKey.stove;
    if (eq == 'oven') return _ToolKey.oven;
    if (eq == 'pot') return _ToolKey.pot;
    if (eq == 'electric') return _ToolKey.electric;

    // 2) 無設備但可離手：用 electric 當「背景 timer」(不改 UI 結構)
    if (st.isConcurrent) return _ToolKey.electric;

    // 3) 無設備且要 attention：fallback 用文字推斷（盡量不影響舊 recipe）
    return _inferTool(st.text);
  }

  List<_FlowStep> _buildFlowSteps(List<Recipe> menus) {
    // ✅ 新規則（依你最新要求）：
    // 1) 每道菜必須「上一 step 完成」先可以開始下一 step（用 endTime 形成 chain）
    // 2) isConcurrent=true 代表「6 格 Tile 背景計時」，可去做其他食譜 step；但同一食譜下一步要等 timer 完成
    // 3) 排程優先開 Tile timer（盡量減少空窗期），再做需要 attention 的 step
    // 4) 全部仍然按每道菜 step 次序（1->2->3...），UI 版面不變
    if (menus.isEmpty) return const [];

    final stepsByRecipe = <List<RecipeStep>>[];
    for (final r in menus) {
      stepsByRecipe.add(r.steps);
    }

    final n = menus.length;
    final idx = List<int>.filled(n, 0);

    // ✅ 每道菜：下一步最早可開始時間（上一 step 結束後）
    final readyAt = List<int>.filled(n, 0);

    // ✅ 資源用量（cookware/electric/oven + attention）
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
      _ToolKey.prep: 0,
    };

    _ToolKey pickFreeSlot(List<_ToolKey> cands, int startSec) {
      for (final k in cands) {
        if ((slotBusyUntil[k] ?? 0) <= startSec) return k;
      }
      // 理論上唔會發生（cap 已限制），但保底：揀最早釋放
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

      // ✅ 無設備但 isConcurrent=true：當 electric 背景 timer（佔用其中一格）
      if (eqRaw.isEmpty && st.isConcurrent) return 'electric';

      return '';
    }

    bool _canStart({required String group, required bool needsAttention}) {
      if (group.isNotEmpty && useOf(group) >= capOf(group)) return false;
      if (needsAttention && useOf('attention') >= capOf('attention'))
        return false;
      return true;
    }

    // ✅ 事件：用嚟釋放資源 & 推進時間
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
      // A) 收割完成事件（end <= t）
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

      // B) 盡量喺同一個 t 塞得幾多得幾多
      bool scheduledAny = false;
      bool loopAgain = true;

      while (loopAgain) {
        loopAgain = false;

        // (1) 先開 Tile timer：isConcurrent=true
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

          // ✅ 分配 6 格 Tile slot（獨立）
          _ToolKey tool;
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
          } else {
            final eCands = [
              if (_electricCap >= 1) _ToolKey.electric,
              if (_electricCap >= 2) _ToolKey.electric2,
            ];
            tool = pickFreeSlot(eCands, start);
            slotBusyUntil[tool] = max(slotBusyUntil[tool] ?? 0, end);
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

          idx[r] += 1;
          readyAt[r] = end; // ✅ 同一食譜下一步要等完成
          scheduledAny = true;
          loopAgain = true;
        }

        // (2) 再做需要 attention 的 step（一次只會開到 1 個，因為 attention=1）
        if (useOf('attention') < capOf('attention')) {
          for (int r = 0; r < n; r++) {
            if (idx[r] >= stepsByRecipe[r].length) continue;
            if (readyAt[r] > t) continue;

            final st = stepsByRecipe[r][idx[r]];
            if (st.isConcurrent) continue;

            final group = _groupOf(st);
            final needsAttention = true;

            if (!_canStart(group: group, needsAttention: needsAttention))
              continue;

            final dur = _stepDurationSec(st);
            final start = t;
            final end = t + dur;

            final inferred = _toolFromRecipeStep(st);
            final tool = (inferred == _ToolKey.hands)
                ? _ToolKey.prep
                : inferred;

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

            idx[r] += 1;
            readyAt[r] = end;
            scheduledAny = true;
            loopAgain = true;
            break; // attention=1
          }
        }
      }

      // C) 如果呢個時間點完全塞唔到，就跳去下一個最早完成事件
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
    // ✅ 對齊 ipynb：isConcurrent=true => 不需要 attention => 當器具/背景 timer（可離手）
    // （UI 不改：仍然用 Tile timer 呈現，Step timer 就鎖 Next）
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

    // ✅ 允許：prev 就係而家呢一步，而且係「人手步」已倒數完
    // （因為人手步係按 Next 先入 _doneGlobalNos）
    if (prev == cur.globalNo &&
        !_isToolTimerStep(cur) &&
        _isCurrentHumanDone(cur)) {
      return true;
    }

    return false;
  }

  bool _calcCanNext() {
    if (!_flowStarted) return false;
    if (_steps.isEmpty) return false;

    final cur = _steps[_idx];
    final curHumanDone = _isCurrentHumanDone(cur);

    // ✅ 最後一步：必須完成自己先可以結束
    if (_idx >= _steps.length - 1) {
      if (_isToolTimerStep(cur)) {
        return _doneGlobalNos.contains(cur.globalNo);
      }
      return curHumanDone;
    }

    // ✅ 人手步：未倒數完一定唔可以走
    if (!_isToolTimerStep(cur) && !curHumanDone) return false;

    // ✅ 下一步：必須「該食譜」上一個 step 完成
    return _prereqDoneForTargetIndex(_idx + 1, cur);
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

    // human duration=0：當完成（可 Next）
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

      // 少啲 rebuild
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
      // 已經跑緊：唔重開（避免你跳回步驟又 reset）
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

      final anyRunning = _toolTimers.values.any((t) => t.running);
      if (!anyRunning) {
        _toolTick?.cancel();
        _toolTick = null;
      }

      if (needSetState) setState(() {});
    });
  }

  void _enqueueIsOk(_ToolKey k) {
    if (_okQueue.contains(k)) return;
    _okQueue.add(k);
    _drainIsOkQueue();
  }

  Future<void> _drainIsOkQueue() async {
    if (_okShowing || !mounted) return;
    if (_okQueue.isEmpty) return;

    _okShowing = true;
    final k = _okQueue.removeAt(0);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: const Text('is ok'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // ✅ 用戶按 OK = 確認完成 -> Tile reset（鬧鐘/遮罩/數字全部消失）
    final owner = _toolTimers[k]?.ownerGlobalNo;
    _toolTimers.remove(k);

    if (owner != null) {
      _doneGlobalNos.add(owner);
    }

    if (mounted) {
      setState(() {
        // ✅ 任何一個 tile 完成 + OK，都可能令「其他食譜下一步」變得可做
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

    // ✅ 人手倒數：isConcurrent=false
    final humanMs = isTool ? 0 : s.durationMs;

    // ✅ Tile 倒數：isConcurrent=true
    final toolMs = isTool ? s.durationMs : 0;

    _resetToStepHuman(humanMs, startIfFlowStarted: startIfFlowStarted);

    // ✅ 進入 Tile step：flow 已 start 就開 timer（可離手）
    if (startIfFlowStarted && _flowStarted && toolMs > 0) {
      _startOrKeepToolTimer(s.tool, toolMs, ownerGlobalNo: s.globalNo);
    }

    // ✅ Next Step 是否可按：由「目前 step 狀態」+「下一步所屬食譜的上一個 step 是否完成」決定
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

  void _goNext() {
    if (_steps.isEmpty) return;

    final cur = _steps[_idx];
    final isTool = _isToolTimerStep(cur);

    // ✅ 1) non-tool：必須等人手倒數完成先可以 Next
    // ✅ 2) tool：只有「下一步同一 startSec」或「timer 完成+按 OK」先可以 Next
    if (!_finished) return;

    // ✅ 非 tool：按 Next 才算真正完成（出 ✓）
    if (!isTool) {
      _doneGlobalNos.add(cur.globalNo);
    }

    if (_idx >= _steps.length - 1) {
      // ✅ 1) 入 session history（一次 Cook Flow = 一條記錄）
      final app = context.read<AppState>();
      app.addSessionFromCartSnapshot(
        widget.snapshot,
        widget.totalPlannedMinutes,
      );

      // ✅ 2) 返回上一頁
      Navigator.pop(context);
      return;
    }

    setState(() {
      _idx++;
      _applyStep(_idx, startIfFlowStarted: true);
    });
  }

  // ---------- sheet ratio / right menu hide (修 flicker) ----------

  void _onSheetOpenRatio(double ratio) {
    final r = ratio.clamp(0.0, 1.0);

    // throttle：變化細就唔 setState，避免拖少少就閃
    if ((r - _sheetOpenRatio).abs() < 0.03) return;

    _sheetOpenRatio = r;

    // ✅ 唔再因為拉底部 sheet 而隱藏菜單按鈕（避免「拉小小就消失一下」）
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
    return _fmtLeft(t.leftMs);
  }

  int _toolShakeMs(_ToolKey k) {
    final t = _toolTimers[k];
    if (t == null) return 420;
    return _calcShakeMs(
      totalMs: t.totalMs,
      leftMs: t.leftMs,
      finished: t.finished,
    );
  }

  Future<void> _openMenuStepsDialog(Recipe r) async {
    // 找出此菜在 global flow 內所有 steps
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
                        final done = (s.globalNo < curNo);

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

                          // ✅ 菜單步驟：綠色
                          subtitle: Text(
                            s.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: const Color.fromARGB(255, 19, 42, 116),
                            ),
                          ),

                          // ✅ 時間：藍色 + ✓：黑色
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

    final activeToolRaw = step?.tool ?? _ToolKey.prep;
    final activeTool = (activeToolRaw == _ToolKey.hands)
        ? _ToolKey.prep
        : activeToolRaw;
    final title = widget.titleOverride ?? 'Cooking';

    // ✅ Step 卡只顯示「人手倒數」
    final stepTimeText = (_flowStarted && _stepMs > 0)
        ? _fmtLeft(_leftMs)
        : '--';

    // 右邊菜單最多 5 個（已改為上方橫向 Row）
    final menusForRight = _menus.take(5).toList(growable: false);

    final toolItems = <(_ToolKey, IconData)>[
      if (_cookwareCap >= 1) (_ToolKey.pot, Symbols.local_fire_department),
      if (_cookwareCap >= 2) (_ToolKey.stove, Symbols.local_fire_department),
      if (_electricCap >= 1) (_ToolKey.electric, Symbols.electrical_services),
      if (_electricCap >= 2) (_ToolKey.electric2, Symbols.electrical_services),
      if (_ovenCap >= 1) (_ToolKey.oven, Symbols.oven_gen),
      (_ToolKey.prep, Symbols.front_hand),
    ];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _ink,
        title: Text(title),
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
                    // ✅ 菜單「圖按鈕」橫向：放喺 6 個器具 icon 上面
                    _MenuRow(
                      menus: menusForRight,
                      hidden: _hideRightMenus,
                      onTap: _openMenuStepsDialog,
                    ),

                    const SizedBox(height: 12),

                    _ToolIconsFrame(
                      activeTool: activeTool,
                      glowEnabled: _flowStarted,
                      items: toolItems,
                      timerActiveOf: _toolTimerActive,
                      shakeMsOf: _toolShakeMs,
                      countTextOf: _toolCountText,
                    ),

                    const SizedBox(height: 12),

                    _StepCard(
                      step: step,
                      flowStarted: _flowStarted,
                      running: _running,
                      finished: _finished,
                      leftText: stepTimeText,
                      onNext: _goNext,
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
    );
  }
}

// ----------------- widgets -----------------

class _ToolIconsFrame extends StatelessWidget {
  final _ToolKey activeTool;
  final bool glowEnabled;
  final List<(_ToolKey, IconData)> items; // ← 加這行

  final bool Function(_ToolKey) timerActiveOf;
  final int Function(_ToolKey) shakeMsOf;
  final String Function(_ToolKey) countTextOf;

  const _ToolIconsFrame({
    required this.activeTool,
    required this.glowEnabled,
    required this.items, // ← 加這行
    required this.timerActiveOf,
    required this.shakeMsOf,
    required this.countTextOf,
  });

  static const _accent = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: items.length <= 2 ? 2 : 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemBuilder: (_, i) {
          final k = items[i].$1;
          final icon = items[i].$2;

          // 未開始前 glowEnabled=false -> 全部 active=false
          final active = glowEnabled && (k == activeTool);

          final timerActive = timerActiveOf(k);
          final shakeMs = shakeMsOf(k);
          final countText = countTextOf(k);

          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active
                    ? _accent.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.10),
                width: active ? 2 : 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                // 底層：器具 icon
                Center(
                  child: Icon(
                    icon,
                    size: 30,
                    color: Colors.white.withValues(alpha: active ? 0.95 : 0.70),
                  ),
                ),

                // 中層：白色半透明遮罩（scrim）- 只要器具 timer active 就顯示
                if (timerActive)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),

                // 上層：大鬧鐘（置中 + 搖擺）
                if (timerActive)
                  Positioned.fill(child: _AlarmOverlay(shakeMs: shakeMs)),

                // 最上層：倒數 badge（右下）
                if (timerActive && countText.isNotEmpty)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
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
            ),
          );
        },
      ),
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

class _StepCard extends StatelessWidget {
  final _FlowStep? step;
  final bool flowStarted;
  final bool running;
  final bool finished;
  final String leftText;
  final VoidCallback onNext;

  const _StepCard({
    required this.step,
    required this.flowStarted,
    required this.running,
    required this.finished,
    required this.leftText,
    required this.onNext,
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
                  color: finished
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

          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: (flowStarted && finished) ? onNext : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.10),
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
          //started ? 'Step 卡係人手倒數；器具倒數會留喺 Tile（到時彈 is ok）。' : '按 Start 一次開始；人手步驟要等完先 Next。',
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
              : Image.network(
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

                        // ✅ 菜單步驟：綠色
                        subtitle: Text(
                          s.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: const Color.fromARGB(255, 19, 42, 116),
                          ),
                        ),

                        // ✅ 時間：藍色 + ✓：黑色
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
