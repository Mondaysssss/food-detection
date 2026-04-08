// [OOP] 相機/偵測頁：模擬 AI 偵測食材，寫入 AppState，並顯示結果。

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/ingredients_meta.dart';
import '../../domain/services/food_detector.dart';
import '../../state/app_state.dart';
import '../widgets/detection_dialog.dart';
import '../widgets/food_list_panel.dart';
import '../widgets/glass.dart';
import '../widgets/ui_helpers.dart';

class AiCameraPage extends StatefulWidget {
  const AiCameraPage({super.key});

  @override
  State<AiCameraPage> createState() => _AiCameraPageState();
}

class _AiCameraPageState extends State<AiCameraPage> {
  final FoodDetector _detector = FoodDetector();
  File? _imageFile;
  bool _isLoading = false;
  String _statusText = 'Initializing model...';

  @override
  void initState() {
    super.initState();
    _detector
        .init()
        .then((_) {
          setState(() => _statusText = 'Ready — take or pick a photo');
        })
        .catchError((e) {
          setState(() => _statusText = 'Model load failed: $e');
        });
  }

  @override
  void dispose() {
    _detector.dispose();
    super.dispose();
  }

  Future<void> _pickAndDetect(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _imageFile = file;
      _isLoading = true;
      _statusText = 'Detecting...';
    });

    try {
      // Add timeout to prevent hanging
      final results = await _detector
          .detect(file)
          .timeout(Duration(seconds: 30), onTimeout: () {
        throw TimeoutException('Detection took too long');
      });

      // filter out seasonings (same logic as your existing mock)
      final filtered = results
          .where((x) => !kSeasoningKeys.contains(x))
          .toList();

      setState(() {
        _isLoading = false;
        _statusText = 'Done — ${filtered.length} items found';
      });

      if (filtered.isNotEmpty && mounted) {
        final app = context.read<AppState>();
        showDialog(
          context: context,
          builder: (_) => DetectionDialog(
            detections: filtered,
            onConfirm: () {
              app.addIngredients(filtered);
              Navigator.pop(context);
            },
          ),
        );
      } else if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('No ingredients detected'),
            content: const Text(
              'We could not identify any ingredients in this photo. '
              'Please try again with a clearer image or different angle.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on TimeoutException catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = 'Detection timeout: ${e.message}. Try a smaller image.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = 'Detection error: $e';
      });
      print('Detection error details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    const cardAspect = 4 / 5;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleText('Camera'),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: cardAspect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: _cameraInner(app),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FoodListPanel(app: app),
        ],
      ),
    );
  }

  Widget _cameraInner(AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black26,
              border: Border.all(color: Colors.white24),
            ),
            child: _imageFile != null
                ? Image.file(_imageFile!, fit: BoxFit.cover)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image, size: 48, color: Colors.white30),
                      const SizedBox(height: 6),
                      Text(
                        _statusText,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),

        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _pickAndDetect(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Take Photo'),
            ),

            FilledButton.tonalIcon(
              onPressed: _isLoading
                  ? null
                  : () => _pickAndDetect(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Upload Photo'),
            ),

            Visibility(
              visible: _imageFile != null,
              child: OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                          _imageFile = null;
                          _statusText = 'Ready — take or pick a photo';
                        }),
                icon: const Icon(Icons.refresh),
                label: const Text('Retake'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
