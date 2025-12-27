// lib/ui/screens/cooking/cooking_screen.dart
// Cooking Screen（單菜逐步烹飪教學）
// 用途：
// - 顯示指定 recipe 的步驟
// - 每步有計時器（durationMin * timeScale）
// - 支援 Start / Pause
// - strictMode 時必須倒數完才能下一步
// - 手動控制 Previous / Next / Finish

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/recipe.dart';
import '../../../state/app_state.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/glass.dart';

class CookingScreen extends StatefulWidget {
  final Recipe recipe;
  const CookingScreen({super.key, required this.recipe});

  @override
  State<CookingScreen> createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen> {
  int index = 0;
  int secondsLeft = 0;
  Timer? _timer;

  AppState get app => context.read<AppState>();

  @override
  void initState() {
    super.initState();
    _loadStep(0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadStep(int i) {
    index = i;
    secondsLeft = widget.recipe.steps[i].durationMin * app.timeScale;
    _timer?.cancel();
    setState(() {});
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  void _pause() => _timer?.cancel();

  @override
  Widget build(BuildContext context) {
    final step = widget.recipe.steps[index];
    final total = widget.recipe.steps.length;
    final canNext = !app.strictMode || secondsLeft == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cooking lesson: ${widget.recipe.name}'),
      ),
      body: PageFrame(
        child: glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 步驟標題
              Text('Step ${index + 1} / $total', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),

              // 步驟說明
              Text(step.text, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),

              // 建議時間說明
              Text(
                'Suggested ${step.durationMin} min (demo scale ${app.timeScale} sec/min)',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),

              // 進度條
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (step.durationMin * app.timeScale - secondsLeft) /
                      (step.durationMin * app.timeScale).clamp(1, double.infinity),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 6),

              // 剩餘時間
              Text('Time left: ${secondsLeft}s', style: const TextStyle(color: Colors.white70)),

              const Spacer(),

              // 操作按鈕
              Wrap(
                spacing: 10,
                children: [
                  ElevatedButton(onPressed: _start, child: const Text('Start')),
                  OutlinedButton(onPressed: _pause, child: const Text('Pause')),
                  OutlinedButton(
                    onPressed: index == 0 ? null : () => setState(() => _loadStep(index - 1)),
                    child: const Text('Previous'),
                  ),
                  ElevatedButton(
                    onPressed: canNext
                        ? () {
                            if (index + 1 < total) {
                              setState(() => _loadStep(index + 1));
                            } else {
                              Navigator.pop(context, true);
                            }
                          }
                        : null,
                    child: Text(index + 1 < total ? 'Next' : 'Finish'),
                  ),
                ],
              ),

              // Strict mode 提示
              if (!canNext)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '(Strict mode: finish current timer before next step)',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}