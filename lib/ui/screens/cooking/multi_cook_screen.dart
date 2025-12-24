import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recipes_data.dart';
import '../../../state/app_state.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/glass.dart';
import '../../widgets/ui_helpers.dart';
import '../home_shell.dart';

class MultiCookScreen extends StatefulWidget {
  final Map<String, int> snapshot;
  final int totalPlannedMinutes;

  const MultiCookScreen({
    super.key,
    required this.snapshot,
    required this.totalPlannedMinutes,
  });

  @override
  State<MultiCookScreen> createState() => _MultiCookScreenState();
}

enum TaskStatus { waiting, running, paused, done }

class PlanTask {
  final String id;
  final String recipeId;
  final String recipeName;
  final int copyIndex;
  final int stepIndex;
  final String text;
  final int secondsTotal;

  int secondsLeft;
  TaskStatus status;
  Timer? timer;

  PlanTask({
    required this.id,
    required this.recipeId,
    required this.recipeName,
    required this.copyIndex,
    required this.stepIndex,
    required this.text,
    required this.secondsTotal,
  })  : secondsLeft = secondsTotal,
        status = TaskStatus.waiting;
}

class _MultiCookScreenState extends State<MultiCookScreen> {
  final List<PlanTask> _tasks = [];
  bool _allCompletedSnackShown = false;

  AppState get app => context.read<AppState>();
  int get scale => context.read<AppState>().timeScale;

  @override
  void initState() {
    super.initState();
    _buildPlan();
  }

  @override
  void dispose() {
    for (final t in _tasks) {
      t.timer?.cancel();
    }
    super.dispose();
  }

  void _buildPlan() {
    int seq = 0;
    widget.snapshot.forEach((menuId, qty) {
      final r = kRecipeById[menuId]!;
      for (int c = 1; c <= qty; c++) {
        for (int i = 0; i < r.steps.length; i++) {
          final st = r.steps[i];
          final secs = max(1, st.durationMin * scale);
          _tasks.add(
            PlanTask(
              id: 't${seq++}',
              recipeId: r.menuId,
              recipeName: r.name,
              copyIndex: c,
              stepIndex: i,
              text: st.text,
              secondsTotal: secs,
            ),
          );
        }
      }
    });
    setState(() {});
  }

  void _startTask(PlanTask t) {
    if (t.status == TaskStatus.running) return;

    t.timer?.cancel();
    t.status = TaskStatus.running;
    t.timer = Timer.periodic(const Duration(seconds: 1), (tm) {
      if (!mounted) return;

      if (t.secondsLeft <= 0) {
        tm.cancel();
        t.status = TaskStatus.done;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Done: ${t.recipeName} #${t.copyIndex} — Step ${t.stepIndex + 1}')),
        );
        setState(() {});
        _checkAllDone();
      } else {
        setState(() => t.secondsLeft--);
      }
    });

    setState(() {});
  }

  void _pauseTask(PlanTask t) {
    if (t.status != TaskStatus.running) return;
    t.timer?.cancel();
    t.status = TaskStatus.paused;
    setState(() {});
  }

  void _resetTask(PlanTask t) {
    t.timer?.cancel();
    t.secondsLeft = t.secondsTotal;
    t.status = TaskStatus.waiting;
    setState(() {});
  }

  void _completeTask(PlanTask t) {
    t.timer?.cancel();
    t.secondsLeft = 0;
    t.status = TaskStatus.done;
    setState(() {});
    _checkAllDone();
  }

  void _checkAllDone() {
    if (_tasks.every((t) => t.status == TaskStatus.done)) {
      if (_allCompletedSnackShown) return;
      _allCompletedSnackShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All steps complete! Tap "Finish cooking" to end this session.')),
      );
    }
  }

  int get _runningCount => _tasks.where((t) => t.status == TaskStatus.running).length;
  int get _waitingCount => _tasks.where((t) => t.status == TaskStatus.waiting).length;
  int get _doneCount => _tasks.where((t) => t.status == TaskStatus.done).length;

  Future<void> _finishAndSaveHistory() async {
    app.addSessionFromCartSnapshot(widget.snapshot, widget.totalPlannedMinutes);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 0)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _tasks.where((t) => t.status == TaskStatus.waiting).toList();
    final running = _tasks.where((t) => t.status == TaskStatus.running || t.status == TaskStatus.paused).toList();
    final done = _tasks.where((t) => t.status == TaskStatus.done).toList();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Cooking guide'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                'Wait:$_waitingCount | Run:$_runningCount | Done:$_doneCount',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
      body: PageFrame(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Help', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text(
                      'You can run multiple timers. When any timer completes, you will be notified.\n'
                      'When all steps are done, tap "Finish cooking" to end.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (running.isNotEmpty) ...[
                titleText('Running'),
                const SizedBox(height: 6),
                for (final t in running) _taskCard(t, running: true),
                const SizedBox(height: 12),
              ],

              titleText('Waiting'),
              const SizedBox(height: 6),
              if (waiting.isEmpty)
                glass(child: const Text('No steps waiting to start', style: TextStyle(color: Colors.white70)))
              else
                for (final t in waiting) _taskCard(t),

              const SizedBox(height: 12),

              if (done.isNotEmpty) ...[
                titleText('Done'),
                const SizedBox(height: 6),
                for (final t in done) _taskCard(t, done: true),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: _tasks.isNotEmpty && _tasks.every((t) => t.status == TaskStatus.done)
              ? _finishAndSaveHistory
              : null,
          icon: const Icon(Icons.flag),
          label: const Text('Finish cooking'),
        ),
      ),
    );
  }

  Widget _taskCard(PlanTask t, {bool running = false, bool done = false}) {
    Color barColor;
    if (done) barColor = Colors.greenAccent;
    else if (running) barColor = Colors.amber;
    else barColor = Colors.white24;

    final progress = 1 - (t.secondsLeft / max(1, t.secondsTotal));

    return glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${t.recipeName} #${t.copyIndex} | Step ${t.stepIndex + 1}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(t.text),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress, minHeight: 8, color: barColor),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Left: ${t.secondsLeft}s', style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              if (!running && !done)
                ElevatedButton.icon(
                  onPressed: () => _startTask(t),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
              if (running && !done) ...[
                IconButton.filledTonal(
                  onPressed: () => _pauseTask(t),
                  icon: const Icon(Icons.pause),
                  tooltip: 'Pause',
                ),
                IconButton.filledTonal(
                  onPressed: () => _resetTask(t),
                  icon: const Icon(Icons.replay),
                  tooltip: 'Reset',
                ),
                IconButton.filled(
                  onPressed: () => _completeTask(t),
                  icon: const Icon(Icons.check),
                  tooltip: 'Finish',
                ),
              ],
              if (done) const Icon(Icons.check_circle, color: Colors.greenAccent),
            ],
          ),
        ],
      ),
    );
  }
}