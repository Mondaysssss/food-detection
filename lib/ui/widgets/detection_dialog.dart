import 'package:flutter/material.dart';

class DetectionDialog extends StatelessWidget {
  final List<String> detections;
  final VoidCallback onConfirm;

  const DetectionDialog({
    super.key,
    required this.detections,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Detection result'),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final d in detections) Chip(label: Text(d))],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Retake'),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}