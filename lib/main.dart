import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:yaml/yaml.dart' show loadYaml;
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'user_management_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  XFile? _image;
  List? _response;
  Interpreter? _interpreter;
  List<int>? _inputShape;
  List<int>? _outputShape;
  List<String> classNames = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    print('initState called');
    loadMetadata().then((_) => loadModel());
  }

  Future<void> loadMetadata() async {
    try {
      final yamlStr = await rootBundle.loadString('assets/model_new/metadata.yaml');
      final yamlMap = loadYaml(yamlStr);
      final namesMap = yamlMap['names'];
      classNames = List.generate(namesMap.length, (i) => namesMap[i].toString());
      print('Loaded class names: $classNames');
    } catch (e) {
      print('Metadata load error: $e');
      classNames = [];
    }
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model_new/best_int8.tflite');
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      print('Model input shape: $_inputShape');
      print('Model output shape: $_outputShape');
    } catch (e) {
      print('Model load error: $e');
    }
  }

  Future<List<List<List<double>>>> preprocessImage(File imageFile, int inputSize) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception('无法解码图片');

    img.Image resized = img.copyResize(image, width: inputSize, height: inputSize);

    return List.generate(
      inputSize,
      (y) => List.generate(
        inputSize,
        (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        },
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    setState(() {
      _image = pickedFile;
    });
    if (pickedFile != null && _interpreter != null && _inputShape != null && _outputShape != null) {
      final image = File(pickedFile.path);
      final inputSize = _inputShape![1];
      final input = await preprocessImage(image, inputSize);
      var inputTensor = [input];
      var output = List.generate(
        _outputShape![0],
        (_) => List.generate(
          _outputShape!.length > 1 ? _outputShape![1] : 1,
          (_) => List.filled(_outputShape!.length > 2 ? _outputShape![2] : 1, 0.0),
        ),
      );

      try {
        _interpreter!.run(inputTensor, output);
        setState(() {
          _response = output;
        });

        print('--- Model Output (Best Score Per Class) ---');
        Map<String, Map<String, dynamic>> bestScores = {};
        final int boxLen = output[0].length;
        final int classProbStart = 4;
        for (int i = 0; i < output[0][0].length; i++) {
          List<double> box = [];
          for (int j = 0; j < boxLen; j++) {
            box.add(output[0][j][i]);
          }
          List<double> classScores = box.sublist(classProbStart, boxLen);
          for (int k = 0; k < classScores.length; k++) {
            double score = classScores[k];
            if (!bestScores.containsKey(classNames[k]) || score > bestScores[classNames[k]]!['score']) {
              bestScores[classNames[k]] = {
                'box': box.sublist(0, 4),
                'score': score
              };
            }
          }
        }
        bestScores.forEach((name, info) {
          print(
            '$name | Box: ${info['box'].map((v) => v.toStringAsFixed(1)).join(', ')} | '
            'Score: ${(info['score'] as double).toStringAsFixed(2)}'
          );
        });
        print('--- End Output ---');
      } catch (e) {
        print('Inference error: $e');
        setState(() {
          _response = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: '模型推論',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: '用戶管理',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedIndex == 0) {
      return _buildModelInferenceScreen();
    } else {
      return const UserManagementScreen();
    }
  }

  Widget _buildModelInferenceScreen() {
    return Center(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _pickImage(ImageSource.camera),
                child: const Text('take photo'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () => _pickImage(ImageSource.gallery),
                child: const Text('choose from gallery'),
              ),
            ],
          ),
          if (_image != null) ...[
            const SizedBox(height: 20),
            Image.file(
              File(_image!.path),
              width: 200,
              height: 200,
            ),
          ],
          if (_response != null && classNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Model response:'),
            ...(() {
              // record the best scores for each class
              Map<String, Map<String, dynamic>> bestScores = {};
              final int boxLen = _response![0].length; // 35
              final int classProbStart = 4;
              final int classCount = classNames.length;
              for (int i = 0; i < _response![0][0].length; i++) {
                List<double> box = [];
                for (int j = 0; j < boxLen; j++) {
                  box.add(_response![0][j][i]);
                }
                List<double> classScores = box.sublist(classProbStart, classProbStart + classCount > boxLen ? boxLen : classProbStart + classCount);
                print('classNames.length: ${classNames.length}, classScores.length: ${classScores.length}');
                for (int k = 0; k < classScores.length; k++) {
                  double score = classScores[k];
                  if (!bestScores.containsKey(classNames[k]) || score > bestScores[classNames[k]]!['score']) {
                    bestScores[classNames[k]] = {
                      'box': box.sublist(0, 4),
                      'score': score
                    };
                  }
                }
              }
              // output the best scores
              return bestScores.entries.map((entry) {
                final name = entry.key;
                final info = entry.value;
                final idx = classNames.indexOf(name);
                return Text(
                  '$name (${idx}) | Box: ${info['box'].map((v) => v.toStringAsFixed(1)).join(', ')} | '
                  'Score: ${(info['score'] as double).toStringAsFixed(2)}'
                );
              }).toList();
            })(),
          ],
        ],
      ),
    );
  }
}
