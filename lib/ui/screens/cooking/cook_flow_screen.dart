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
  final int totalMs;
  final DateTime startAt;
  int leftMs;
  bool running;
  bool finished;
  bool notified;

  _ToolTimerState({
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

  _IpynbSched({
    required this.recipeIndex,
    required this.stepIndex,
    required this.startSec,
    required this.endSec,
  });
}

class _CookFlowScreenState extends State<CookFlowScreen> {
  // theme-ish
  static const _bg = Color(0xFF0A0F18);
  static const _ink = Colors.white;

  // flow
  late final List<Recipe> _menus = _resolveMenus();
  late final List<_FlowStep> _steps = _buildFlowSteps(_menus);

  int _idx = 0;

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

    if (_steps.isNotEmpty) {
      // 未開始：只設定 Step 顯示（唔自動開始）
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
    // ✅ 改成 ipynb 版：資源容量 + 事件佇列（離散事件模擬）
    // UI 完全唔改，只係改「步驟排序/時間軸」同「Step vs Tile timer 規則」
    if (menus.isEmpty) return const [];

    final stepsByRecipe = <List<RecipeStep>>[];
    for (final r in menus) {
      stepsByRecipe.add(r.steps);
    }

    final numRecipes = menus.length;
    final currentIdx = List<int>.filled(numRecipes, 0);

    // ipynb: capacity.get(res, 1)
    int capOf(String res) {
      switch (res) {
        case 'stove':
          return 2;
        case 'electric':
          return 2;
        case 'oven':
          return 1;
        case 'attention':
          return 1;
        default:
          return 1;
      }
    }

    int usageOf(Map<String, int> usage, String res) => usage[res] ?? 0;

    final usage = <String, int>{}; // 'stove'/'oven'/'attention'
    final eventQueue = <_IpynbEvent>[];
    final schedule = <_IpynbSched>[];

    int currentTime = 0;

    bool hasRemaining() {
      for (int r = 0; r < numRecipes; r++) {
        if (currentIdx[r] < stepsByRecipe[r].length) return true;
      }
      return false;
    }

    // 取出 eventQueue 入面 endSec 最細嗰個（O(n)，步驟數通常唔大）
    _IpynbEvent popMinEvent() {
      int best = 0;
      int bestEnd = eventQueue[0].endSec;
      for (int i = 1; i < eventQueue.length; i++) {
        final e = eventQueue[i];
        if (e.endSec < bestEnd) {
          bestEnd = e.endSec;
          best = i;
        }
      }
      return eventQueue.removeAt(best);
    }

    int peekMinEnd() {
      int bestEnd = eventQueue[0].endSec;
      for (int i = 1; i < eventQueue.length; i++) {
        bestEnd = min(bestEnd, eventQueue[i].endSec);
      }
      return bestEnd;
    }

    while (hasRemaining()) {
      // 1) 收割完成事件（end <= currentTime），釋放資源
      while (eventQueue.isNotEmpty) {
        // 找到最早完成嘅 event；如果佢都未到 currentTime，就停
        int minEnd = peekMinEnd();
        if (minEnd > currentTime) break;

        final done = popMinEvent();
        schedule.add(
          _IpynbSched(
            recipeIndex: done.recipeIndex,
            stepIndex: done.stepIndex,
            startSec: done.startSec,
            endSec: done.endSec,
          ),
        );

        if (done.equipment.isNotEmpty) {
          usage[done.equipment] = usageOf(usage, done.equipment) - 1;
        }
        if (done.needsAttention) {
          usage['attention'] = usageOf(usage, 'attention') - 1;
        }
      }

      // 2) 嘗試喺「同一個 currentTime」繼續塞下一步（ipynb 行為：只要今輪有排到，就唔跳時間）
      bool scheduledAny = false;

      for (int r = 0; r < numRecipes; r++) {
        if (currentIdx[r] >= stepsByRecipe[r].length) continue;

        final st = stepsByRecipe[r][currentIdx[r]];
        final eqRaw = _normEquipment(_readRequiredEquipment(st));
        // ✅ 資源名（同時也對齊 6 個 Tile slot）：
        // - stove/pot => 'stove'（兩格 Cookware）
        // - electric => 'electric'（兩格 Electric）
        // - oven => 'oven'（一格）
        // - 無設備但可離手 => 當 'electric'（佔用其中一格 Electric 作背景 timer）
        final eq = (eqRaw == 'pot')
            ? 'stove'
            : (eqRaw.isEmpty && st.isConcurrent)
            ? 'electric'
            : eqRaw;
        final needsAttention = !st.isConcurrent;

        bool can = true;

        if (eq.isNotEmpty) {
          if (usageOf(usage, eq) >= capOf(eq)) can = false;
        }
        if (needsAttention) {
          if (usageOf(usage, 'attention') >= capOf('attention')) can = false;
        }

        if (can) {
          final dur = _stepDurationSec(st);
          final start = currentTime;
          final end = currentTime + dur;

          eventQueue.add(
            _IpynbEvent(
              recipeIndex: r,
              stepIndex: currentIdx[r],
              startSec: start,
              endSec: end,
              equipment: eq,
              needsAttention: needsAttention,
            ),
          );

          if (eq.isNotEmpty) {
            usage[eq] = usageOf(usage, eq) + 1;
          }
          if (needsAttention) {
            usage['attention'] = usageOf(usage, 'attention') + 1;
          }

          currentIdx[r] += 1;
          scheduledAny = true;
        }
      }

      // 3) 如果今輪冇任何一步可排，就跳到下一個最早完成時間
      if (!scheduledAny && eventQueue.isNotEmpty) {
        currentTime = peekMinEnd();
      } else if (!scheduledAny && eventQueue.isEmpty) {
        break;
      }
    }

    // 4) 把剩餘事件全部收割（按 endSec 先後）
    while (eventQueue.isNotEmpty) {
      final done = popMinEvent();
      schedule.add(
        _IpynbSched(
          recipeIndex: done.recipeIndex,
          stepIndex: done.stepIndex,
          startSec: done.startSec,
          endSec: done.endSec,
        ),
      );
    }

    // 5) ipynb 最後係按 start_time 排序輸出時間軸
    schedule.sort((a, b) {
      final c = a.startSec.compareTo(b.startSec);
      if (c != 0) return c;
      // 同一時間開始：保持 recipe 順序，再保持 stepIndex
      final cr = a.recipeIndex.compareTo(b.recipeIndex);
      if (cr != 0) return cr;
      return a.stepIndex.compareTo(b.stepIndex);
    });

    final total = schedule.length;
    if (total <= 0) return const [];

    final out = <_FlowStep>[];

    // ✅ 將「同類設備」分配到 6 個 Tile slot（兩個 Cookware / 兩個 Electric / 一個 Oven / 一個 Hands-Prep）
    // 目標：同一時間如果有兩個 stove/cookware 任務，就會各自佔用 pot + stove 兩格（圖標一樣但 timer 獨立）
    // 注意：Hands Tile 已合併到 prep；hands 只作內部分類，顯示一律用 prep。
    final slotBusyUntil = <_ToolKey, int>{
      _ToolKey.pot: 0,
      _ToolKey.stove: 0,
      _ToolKey.electric: 0,
      _ToolKey.electric2: 0,
      _ToolKey.oven: 0,
      _ToolKey.prep: 0,
    };

    _ToolKey pickFreeSlot(List<_ToolKey> candidates, int startSec) {
      // 先揀已空閒的；如果都唔空閒（理論上唔應該，因為排程容量已限制），就揀最早釋放嗰個
      for (final k in candidates) {
        if ((slotBusyUntil[k] ?? 0) <= startSec) return k;
      }
      _ToolKey best = candidates.first;
      int bestEnd = slotBusyUntil[best] ?? 0;
      for (final k in candidates.skip(1)) {
        final end = slotBusyUntil[k] ?? 0;
        if (end < bestEnd) {
          bestEnd = end;
          best = k;
        }
      }
      return best;
    }

    String _eqGroup(String eqNorm) {
      if (eqNorm == 'stove' || eqNorm == 'pot') return 'cookware';
      if (eqNorm == 'electric') return 'electric';
      if (eqNorm == 'oven') return 'oven';
      return '';
    }

    for (int g = 0; g < schedule.length; g++) {
      final it = schedule[g];
      final r = menus[it.recipeIndex];
      final st = r.steps[it.stepIndex];
      final dishTotal = r.steps.length;

      final stepNo = st.stepNumber; // 1-based
      final eq = _normEquipment(_readRequiredEquipment(st));

      final startSec = it.startSec;
      final endSec = it.endSec;
      final durMs = max(0, (endSec - startSec) * 1000);

      // 以設備/可離手性決定 tile slot
      final group = _eqGroup(eq);
      _ToolKey tool;
      if (group == 'cookware') {
        tool = pickFreeSlot(const [_ToolKey.pot, _ToolKey.stove], startSec);
        slotBusyUntil[tool] = max(slotBusyUntil[tool] ?? 0, endSec);
      } else if (group == 'electric') {
        tool = pickFreeSlot(const [
          _ToolKey.electric,
          _ToolKey.electric2,
        ], startSec);
        slotBusyUntil[tool] = max(slotBusyUntil[tool] ?? 0, endSec);
      } else if (group == 'oven') {
        tool = _ToolKey.oven;
        slotBusyUntil[tool] = max(slotBusyUntil[tool] ?? 0, endSec);
      } else if (st.isConcurrent) {
        // 無設備但可離手：用 Electric slot 當背景 timer（兩格可同時跑）
        tool = pickFreeSlot(const [
          _ToolKey.electric,
          _ToolKey.electric2,
        ], startSec);
        slotBusyUntil[tool] = max(slotBusyUntil[tool] ?? 0, endSec);
      } else {
        // 需要人手：用文字推斷（最後顯示一律落到 prep tile）
        final inferred = _inferTool(st.text);
        tool = (inferred == _ToolKey.hands) ? _ToolKey.prep : inferred;
      }

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
          tool: tool,
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
          _finished = true;
        });
      }
    });
  }

  // ---------- B) Tool countdown control (tile) ----------

  void _startOrKeepToolTimer(_ToolKey tool, int ms) {
    if (ms <= 0) return;

    final existing = _toolTimers[tool];
    if (existing != null && existing.running) {
      // 已經跑緊：唔重開（避免你跳回步驟又 reset）
      return;
    }

    _toolTimers[tool] = _ToolTimerState(
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
    _toolTimers.remove(k);
    if (mounted) setState(() {});

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

    // ✅ 人手倒數：只喺 hands/prep（或你將來更精準規則）
    final humanMs = isTool ? 0 : s.durationMs;

    // ✅ 器具倒數：只喺 pot/stove/electric/oven
    final toolMs = isTool ? s.durationMs : 0;

    _resetToStepHuman(humanMs, startIfFlowStarted: startIfFlowStarted);

    // ✅ 器具 timer：只要 flow 已 start，進入器具 step 即開（可離手）
    if (startIfFlowStarted && _flowStarted && toolMs > 0) {
      _startOrKeepToolTimer(s.tool, toolMs);
    }
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

    // 人手倒數未完：唔俾 next
    if (!_finished) return;

    if (_idx >= _steps.length - 1) {
      // ✅ 1) 入 session history（一次 Cook Flow = 一條記錄）
      final app = context.read<AppState>();
      app.addSessionFromCartSnapshot(
        widget.snapshot,
        widget.totalPlannedMinutes,
      );

      // （可選）如果你 Finish 之後想清空購物車：
      // app.clearCart();

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
                        final done =
                            (s.globalNo < curNo) ||
                            (s.globalNo == curNo && _finished);

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
                              color: Colors.green.shade700,
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
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _idx = s.globalNo - 1;
                              _applyStep(_idx, startIfFlowStarted: true);
                            });
                          },
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

  final bool Function(_ToolKey) timerActiveOf;
  final int Function(_ToolKey) shakeMsOf;
  final String Function(_ToolKey) countTextOf;

  const _ToolIconsFrame({
    required this.activeTool,
    required this.glowEnabled,
    required this.timerActiveOf,
    required this.shakeMsOf,
    required this.countTextOf,
  });

  static const _accent = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    final items = const [
      (_ToolKey.pot, Symbols.local_fire_department), // Cookware slot 1
      (_ToolKey.stove, Symbols.local_fire_department), // Cookware slot 2
      (_ToolKey.electric, Symbols.electrical_services), // Electric slot 1
      (_ToolKey.electric2, Symbols.electrical_services), // Electric slot 2
      (_ToolKey.oven, Symbols.oven_gen), // Baking / air frying
      (_ToolKey.prep, Symbols.front_hand), // Hands / Prep
    ];

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
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
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
          started ? ' ' : ' ', //在Started按鈕下面的字
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
  final ValueChanged<double> onOpenRatio;
  final ValueChanged<int> onJumpToGlobalIndex;

  const _CookStepsSheet({
    required this.steps,
    required this.currentGlobalNo,
    required this.currentFinished,
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
                        tooltip: 'Open',
                        onPressed: () => _ctl.animateTo(
                          0.92,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                        icon: const Icon(Icons.keyboard_arrow_up),
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
                      final done =
                          (s.globalNo < widget.currentGlobalNo) ||
                          (s.globalNo == widget.currentGlobalNo &&
                              widget.currentFinished);

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
                            color: Colors.green.shade700,
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

                        onTap: () => widget.onJumpToGlobalIndex(s.globalNo),
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
