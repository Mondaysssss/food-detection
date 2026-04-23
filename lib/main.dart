// lib/main.dart
// App entry point: creates Provider(AppState) and launches MyApp (MaterialApp + Theme + initial page)
//
// Any global state added later (e.g. login data, user preferences) can be placed in AppState,
// and the UI reads it via Provider/Selector.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'state/app_state.dart';
import 'app/my_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(create: (_) => AppState(), child: const MyApp()),
  );
}
