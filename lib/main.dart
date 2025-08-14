import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

void main() {
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
  int _counter = 0;
  XFile? _image;
  List? _response;
  Interpreter? _interpreter;
  List<int>? _inputShape;
  List<int>? _outputShape;

  @override
  void initState() {
    super.initState();
    print('initState called');
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model_test.tflite');
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      print('Model input shape: $_inputShape');
      print('Model output shape: $_outputShape');
    } catch (e) {
      print('Model load error: $e');
    }
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  Future<List<List<List<double>>>> preprocessImage(File imageFile, int inputSize) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception('无法解码图片');

    img.Image resized = img.copyResize(image, width: inputSize, height: inputSize);

    // shape: [height][width][3]
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

  Future<void> _openCamera() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    setState(() {
      _image = pickedFile;
    });
    if (pickedFile != null && _interpreter != null && _inputShape != null && _outputShape != null) {
      final image = File(pickedFile.path);

      // 自动获取输入尺寸
      final inputSize = _inputShape![1];

      // 预处理图片
      final input = await preprocessImage(image, inputSize);

      // 构造输入 shape: [1, height, width, 3]
      var inputTensor = [input];

      // 构造输出 shape
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _openCamera,
              child: const Text('open camera'),
            ),
            if (_image != null) ...[
              const SizedBox(height: 20),
              Image.file(
                File(_image!.path),
                width: 200,
                height: 200,
              ),
            ],
            if (true) ...[
              const SizedBox(height: 10),
              Text('Model response: ${_response.toString()}'),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
