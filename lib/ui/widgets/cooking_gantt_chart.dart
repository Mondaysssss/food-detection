// lib/ui/widgets/cooking_gantt_chart.dart

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Public data class for the chart.
class GanttStep {
  final String menuId;
  final String menuName;
  final int stepNumber;
  final int startSec;
  final int endSec;
  final bool isConcurrent;
  final bool isPrep;
  final String text;

  const GanttStep({
    required this.menuId,
    required this.menuName,
    required this.stepNumber,
    required this.startSec,
    required this.endSec,
    required this.isConcurrent,
    required this.isPrep,
    required this.text,
  });
}

// ─── color helpers ───

Color _recipeColor(int index, int totalRecipes) {
  final hue = (index * 360.0 / max(1, totalRecipes)) % 360.0;
  return HSLColor.fromAHSL(1.0, hue, 0.65, 0.52).toColor();
}

const _prepColor = Color(0xFF66BB6A);
const _cookColor = Color(0xFFFF7043);

// ─── widget ───

class CookingGanttCharts extends StatelessWidget {
  final List<GanttStep> steps;

  const CookingGanttCharts({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chartHeader(
          context,
          'Prep vs Cook',
          _ColorMode.prepCook,
          topPadding: 12,
        ),
        _legend1(),
        _chart(mode: _ColorMode.prepCook),
        const Divider(height: 24),
        _chartHeader(context, 'By Recipe', _ColorMode.recipe),
        _legend2(),
        _chart(mode: _ColorMode.recipe),
      ],
    );
  }

  Widget _chartHeader(
    BuildContext context,
    String title,
    _ColorMode mode, {
    double topPadding = 0,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: 16, top: topPadding, bottom: 4, right: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.share, size: 20),
            tooltip: 'Share $title chart',
            onPressed: () => _onShare(context, mode, title),
          ),
        ],
      ),
    );
  }

  Future<void> _onShare(BuildContext ctx, _ColorMode mode, String label) async {
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(const SnackBar(content: Text('Exporting chart…')));
    try {
      final bytes = await _exportChart(steps, mode);
      if (bytes == null) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(const SnackBar(content: Text('Export failed')));
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/gantt_${label.replaceAll(' ', '_')}_'
        '${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Gantt Chart – $label');
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    }
  }

  Widget _legend1() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _chip(_prepColor, 'Prep'),
          const SizedBox(width: 12),
          _chip(_cookColor, 'Cook'),
        ],
      ),
    );
  }

  Widget _legend2() {
    final recipeIds = <String>[];
    for (final s in steps) {
      if (!recipeIds.contains(s.menuId)) recipeIds.add(s.menuId);
    }
    final chips = <Widget>[];
    for (int i = 0; i < recipeIds.length; i++) {
      final name = steps.firstWhere((s) => s.menuId == recipeIds[i]).menuName;
      chips.add(_chip(_recipeColor(i, recipeIds.length), name));
      chips.add(const SizedBox(width: 10));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(spacing: 4, runSpacing: 4, children: chips),
    );
  }

  Widget _chip(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _chart({required _ColorMode mode}) {
    final totalSec = steps.map((s) => s.endSec).reduce(max);
    final chartWidth = min(8000.0, max(600.0, totalSec * 1.0));
    final (bgLanes, bgLaneMap) = _assignBgLanes(steps);
    final height = _chartHeight(bgLanes);

    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CustomPaint(
          size: Size(chartWidth, height),
          painter: _GanttPainter(
            steps: steps,
            totalSec: totalSec,
            mode: mode,
            bgLanes: bgLanes,
            bgLaneMap: bgLaneMap,
          ),
        ),
      ),
    );
  }
}

// ─── layout constants ───

const _handsOnH = 66.0;
const _bgLaneH = 50.0;
const _trackGap = 8.0;
const _axisHeight = 28.0;
const _labelWidth = 90.0;

double _chartHeight(int bgLanes) =>
    _handsOnH + _trackGap + (max(1, bgLanes) * _bgLaneH) + _axisHeight;

/// Assign each concurrent step to a background sub-lane (greedy).
(int, Map<int, int>) _assignBgLanes(List<GanttStep> steps) {
  final bgEntries = <(int, GanttStep)>[];
  for (int i = 0; i < steps.length; i++) {
    if (steps[i].isConcurrent) bgEntries.add((i, steps[i]));
  }
  if (bgEntries.isEmpty) return (1, {});

  bgEntries.sort((a, b) => a.$2.startSec.compareTo(b.$2.startSec));
  final laneEnds = <int>[];
  final assignment = <int, int>{};

  for (final (idx, s) in bgEntries) {
    int lane = -1;
    for (int l = 0; l < laneEnds.length; l++) {
      if (laneEnds[l] <= s.startSec) {
        lane = l;
        break;
      }
    }
    if (lane >= 0) {
      laneEnds[lane] = s.endSec;
    } else {
      lane = laneEnds.length;
      laneEnds.add(s.endSec);
    }
    assignment[idx] = lane;
  }
  return (max(1, laneEnds.length), assignment);
}

enum _ColorMode { prepCook, recipe }

// ─── painter ───

class _GanttPainter extends CustomPainter {
  final List<GanttStep> steps;
  final int totalSec;
  final _ColorMode mode;
  final int bgLanes;
  final Map<int, int> bgLaneMap;

  _GanttPainter({
    required this.steps,
    required this.totalSec,
    required this.mode,
    required this.bgLanes,
    required this.bgLaneMap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final recipeIds = <String>[];
    for (final s in steps) {
      if (!recipeIds.contains(s.menuId)) recipeIds.add(s.menuId);
    }
    final chartLeft = _labelWidth;
    final chartWidth = size.width - _labelWidth;
    final pxPerSec = chartWidth / totalSec;
    final bgTotalH = bgLanes * _bgLaneH;
    final bgY0 = _handsOnH + _trackGap;

    // ── track labels (white, larger for dark backgrounds) ──
    _drawText(
      canvas,
      'Hands-on',
      Offset(0, _handsOnH / 2 - 9),
      width: _labelWidth - 8,
      fontSize: 15,
      bold: true,
      color: Colors.white,
    );
    _drawText(
      canvas,
      'Background',
      Offset(0, bgY0 + bgTotalH / 2 - 9),
      width: _labelWidth - 8,
      fontSize: 15,
      bold: true,
      color: Colors.white,
    );

    // ── track backgrounds ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(chartLeft, 0, chartWidth, _handsOnH),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0x0A000000),
    );
    for (int l = 0; l < bgLanes; l++) {
      final ly = bgY0 + l * _bgLaneH;
      final shade = l.isEven
          ? const Color(0x0A000000)
          : const Color(0x06000000);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(chartLeft, ly, chartWidth, _bgLaneH),
          const Radius.circular(4),
        ),
        Paint()..color = shade,
      );
    }

    // ── bars ──
    for (int i = 0; i < steps.length; i++) {
      final s = steps[i];
      final x = chartLeft + s.startSec * pxPerSec;
      final w = (s.endSec - s.startSec) * pxPerSec;

      double y;
      double barTrackH;
      if (s.isConcurrent) {
        final lane = bgLaneMap[i] ?? 0;
        y = bgY0 + lane * _bgLaneH;
        barTrackH = _bgLaneH;
      } else {
        y = 0;
        barTrackH = _handsOnH;
      }

      Color color;
      switch (mode) {
        case _ColorMode.prepCook:
          color = s.isPrep ? _prepColor : _cookColor;
          break;
        case _ColorMode.recipe:
          color = _recipeColor(recipeIds.indexOf(s.menuId), recipeIds.length);
          break;
      }

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y + 2, w - 1, barTrackH - 4),
        const Radius.circular(4),
      );

      canvas.drawRRect(rect, Paint()..color = color);
      canvas.drawRRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      if (w > 36) {
        _drawText(
          canvas,
          s.menuName,
          Offset(x + 5, y + 6),
          width: w - 10,
          fontSize: 16,
          color: Colors.white,
          bold: true,
        );
        _drawText(
          canvas,
          'Step ${s.stepNumber}',
          Offset(x + 5, y + 24),
          width: w - 10,
          fontSize: 16,
          color: const Color(0xDDFFFFFF),
        );
      }
    }

    // ── time axis ──
    final axisY = _handsOnH + _trackGap + bgTotalH + 4;
    final axisPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(chartLeft, axisY),
      Offset(size.width, axisY),
      axisPaint,
    );

    final tickInterval = totalSec > 1200 ? 600 : 60;
    for (int t = 0; t <= totalSec; t += tickInterval) {
      final tx = chartLeft + t * pxPerSec;
      canvas.drawLine(Offset(tx, axisY), Offset(tx, axisY + 6), axisPaint);
      final min = t ~/ 60;
      final sec = t % 60;
      final label = sec == 0 ? '${min}m' : '${min}m${sec}s';
      _drawText(
        canvas,
        label,
        Offset(tx - 14, axisY + 9),
        width: 50,
        fontSize: 16,
        color: Colors.grey,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    double width = 100,
    double fontSize = 10,
    Color color = Colors.black,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _GanttPainter old) =>
      old.steps != steps || old.mode != mode || old.bgLanes != bgLanes;
}

// ─── PictureRecorder export ───

/// Convert Gantt steps to a readable text timeline.
String ganttStepsToString(List<GanttStep> steps) {
  if (steps.isEmpty) return '(no steps)';

  final sorted = [...steps]..sort((a, b) => a.startSec.compareTo(b.startSec));
  final buf = StringBuffer();

  buf.writeln('═══ Cooking Timeline ═══');
  buf.writeln(
    '${'Time'.padRight(14)}'
    '${'Track'.padRight(13)}'
    '${'Type'.padRight(7)}'
    '${'Recipe'.padRight(22)}'
    'Step',
  );
  buf.writeln('─' * 70);

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return s == 0 ? '${m}m' : '${m}m${s.toString().padLeft(2, '0')}s';
  }

  for (final s in sorted) {
    final time = '${_fmt(s.startSec)}-${_fmt(s.endSec)}'.padRight(14);
    final track = (s.isConcurrent ? 'Background' : 'Hands-on').padRight(13);
    final type = (s.isPrep ? 'Prep' : 'Cook').padRight(7);
    final recipe = s.menuName.padRight(22);
    buf.writeln('$time$track$type$recipe${s.stepNumber}');
  }

  buf.writeln('─' * 70);
  final total = steps.map((s) => s.endSec).reduce(max);
  buf.writeln('Total wall-clock: ${_fmt(total)}');
  return buf.toString();
}

Future<Uint8List?> _exportChart(List<GanttStep> steps, _ColorMode mode) async {
  final totalSec = steps.map((s) => s.endSec).reduce(max);
  final fullWidth = min(8000.0, max(600.0, totalSec * 1.0));
  final (bgLanes, bgLaneMap) = _assignBgLanes(steps);
  final height = _chartHeight(bgLanes);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, fullWidth, height),
    Paint()..color = const Color(0xFF2C2C2C),
  );
  _GanttPainter(
    steps: steps,
    totalSec: totalSec,
    mode: mode,
    bgLanes: bgLanes,
    bgLaneMap: bgLaneMap,
  ).paint(canvas, Size(fullWidth, height));

  final picture = recorder.endRecording();
  final image = await picture.toImage(fullWidth.ceil(), height.ceil());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}
