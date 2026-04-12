// lib/app/my_app.dart
//  App 最外層 MaterialApp：設定 Theme / Title / 初始頁（IntroStartScreen）
// 你之後要加 route table / i18n / deep link，都係由呢個檔開始擴展。

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../domain/services/auth_service.dart';
import '../ui/screens/intro_start_screen.dart';
import '../ui/screens/home_shell.dart';
import '../ui/screens/persona_wizard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF22C55E);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DishMind (Aiding daily cooking with AI)',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: const _AuthGate(), // was: const IntroStartScreen()
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late Future<Widget> _destination;

  @override
  void initState() {
    super.initState();
    _destination = _resolve();
  }

  Future<Widget> _resolve() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const IntroStartScreen();

    // User is auto-logged-in → load preferences
    final auth = AuthService();
    final data = await auth.loadPreferences(user.uid);
    if (!mounted) return const IntroStartScreen();

    final appState = context.read<AppState>();

    if (data != null && data.containsKey('gender')) {
      // Firestore has preferences → restore them
      if (data.containsKey('birthYear')) {
        appState.setPersona(
          newGender: data['gender'],
          newBirthYear: data['birthYear'],
          newBirthMonth: data['birthMonth'],
          newBirthDay: data['birthDay'],
          newAppliances: Map<String, int>.from(data['appliances'] ?? {}),
        );
      } else {
        // Legacy: convert old 'age' → approximate birthYear
        final oldAge = data['age'] ?? 18;
        final approxBirthYear = DateTime.now().year - (oldAge as int);
        appState.setPersona(
          newGender: data['gender'],
          newBirthYear: approxBirthYear,
          newBirthMonth: 1,
          newBirthDay: 1,
          newAppliances: Map<String, int>.from(data['appliances'] ?? {}),
        );
      }
      appState.setAllergies(Set<String>.from(data['allergies'] ?? []));
      final name = data['username'] ?? user.displayName ?? '';
      if (name.isNotEmpty) appState.userName = name;

      // ✅ Load cook sessions from Firestore (non-fatal if it fails)
      try {
        final sessions = await auth.loadCookSessions(user.uid);
        for (final s in sessions) {
          final ts = s['completedAt'];
          final dt = ts is Timestamp ? ts.toDate() : DateTime.now();
          appState.addSessionFromFirestore(
            id: s['id'] as String,
            items: Map<String, int>.from(s['items'] ?? {}),
            totalMinutes: s['totalMinutes'] ?? 0,
            completedAt: dt,
          );
        }
      } catch (_) {
        // Sessions failed to load — continue without history
      }

      return const HomeShell(initialIndex: 0);
    } else {
      // No preferences → wizard
      final name = data?['username'] ?? user.displayName ?? '';
      if (name.isNotEmpty) appState.userName = name;

      return const PersonaWizardScreen(goHomeAfterFinish: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destination,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || snap.data == null) {
          return const IntroStartScreen();
        }
        return snap.data!;
      },
    );
  }
}
