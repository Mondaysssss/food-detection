import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:yaml/yaml.dart' show loadYaml;

class FoodDetector {
  Interpreter? _interpreter;
  List<int>? _inputShape;
  List<int>? _outputShape;
  List<String> classNames = [];

  bool get isReady => _interpreter != null && classNames.isNotEmpty;

  /// Load metadata.yaml to get class names
  Future<void> loadMetadata() async {
    final yamlStr = await rootBundle.loadString(
      'assets/model_new/metadata.yaml',
    );
    final yamlMap = loadYaml(yamlStr);
    final namesMap = yamlMap['names'];
    classNames = List.generate(namesMap.length, (i) => namesMap[i].toString());
  }

  /// Load the TFLite model
  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/model_new/best_int8.tflite',
    );
    _inputShape = _interpreter!.getInputTensor(0).shape;
    _outputShape = _interpreter!.getOutputTensor(0).shape;
  }

  /// Initialize both metadata and model
  Future<void> init() async {
    await loadMetadata();
    await loadModel();
  }

  /// Preprocess image: resize + normalize to [0,1]
  Future<List<List<List<double>>>> _preprocessImage(File imageFile) async {
    final inputSize = _inputShape![1];
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception('Cannot decode image');

    img.Image resized = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
    );

    return List.generate(
      inputSize,
      (y) => List.generate(inputSize, (x) {
        final pixel = resized.getPixel(x, y);
        return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
      }),
    );
  }

  /// Run detection on an image file. Returns list of detected class names
  /// (filtered by confidence threshold).
  /// Note: This runs on the main thread but yields periodically to keep UI responsive
  Future<List<String>> detect(File imageFile, {double threshold = 0.25}) async {
    if (!isReady) throw StateError('FoodDetector not initialized');

    // Allow UI to update before starting heavy computation
    await Future.delayed(Duration.zero);

    try {
      return await _detectInternal(imageFile, threshold: threshold);
    } catch (e) {
      rethrow;
    }
  }

  /// Internal detection logic
  Future<List<String>> _detectInternal(
    File imageFile, {
    double threshold = 0.25,
  }) async {
    if (!isReady) throw StateError('FoodDetector not initialized');

    final input = [await _preprocessImage(imageFile)];

    var output = List.generate(
      _outputShape![0],
      (_) => List.generate(
        _outputShape!.length > 1 ? _outputShape![1] : 1,
        (_) =>
            List.filled(_outputShape!.length > 2 ? _outputShape![2] : 1, 0.0),
      ),
    );

    // Run interpreter
    _interpreter!.run(input, output);

    // Parse YOLO output: find best score per class
    Map<String, double> bestScores = {};
    final int classProbStart = 4;
    final int classCount = classNames.length;
    final int boxLen = output[0].length;

    for (int i = 0; i < output[0][0].length; i++) {
      List<double> box = [];
      for (int j = 0; j < boxLen; j++) {
        box.add(output[0][j][i]);
      }
      List<double> classScores = box.sublist(
        classProbStart,
        classProbStart + classCount > boxLen
            ? boxLen
            : classProbStart + classCount,
      );
      for (int k = 0; k < classScores.length; k++) {
        double score = classScores[k];
        if (!bestScores.containsKey(classNames[k]) ||
            score > bestScores[classNames[k]]!) {
          bestScores[classNames[k]] = score;
        }
      }
    }

    // Return names above threshold
    return bestScores.entries
        .where((e) => e.value >= threshold)
        .map((e) => e.key)
        .toList();
  }

  void dispose() {
    _interpreter?.close();
  }
}
