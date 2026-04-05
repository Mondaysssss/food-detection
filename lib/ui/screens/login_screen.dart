// [OOP] 登入頁：示範用的登入流程/跳過，進入主頁。

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // add

import 'home_shell.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';
import '../../domain/services/auth_service.dart'; // add

import 'package:provider/provider.dart';
import '../../state/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  final _auth = AuthService(); // add
  bool _loading = false; // add

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 0)),
    );
  }

  void _comingSoon(String what) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what — coming soon')));
  }

  Future<void> _doLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await _auth.login(
        email: _email.text,
        password: _password.text,
      );
      // ── load cloud preferences ──
      if (user != null && mounted) {
        final appState = context.read<AppState>();
        final data = await _auth.loadPreferences(user.uid);

        if (data != null && data.containsKey('gender')) {
          // Firestore has preferences → cloud wins
          appState.setPersona(
            newGender: data['gender'],
            newAge: data['age'],
            newAppliances: Map<String, int>.from(data['appliances'] ?? {}),
          );
          appState.setAllergies(Set<String>.from(data['allergies'] ?? []));
        } else {
          // Firestore has NO preferences → save local wizard data up
          await _auth.savePreferences(
            uid: user.uid,
            gender: appState.gender,
            age: appState.age,
            appliances: Map<String, int>.from(appState.appliances),
            allergies: appState.allergies.toList(),
          );
        }

        // Always set username from Firestore or Firebase Auth displayName
        final name = data?['username'] ?? user.displayName ?? '';
        if (name.isNotEmpty) appState.userName = name;
      }
      if (mounted) _goHome();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? 'Login failed')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doGoogleLogin() async {
    setState(() => _loading = true);
    try {
      final user = await _auth.signInWithGoogle();
      // ── load cloud preferences (returning Google user) ──
      if (user != null && mounted) {
        final appState = context.read<AppState>();
        final data = await _auth.loadPreferences(user.uid);

        if (data != null && data.containsKey('gender')) {
          // Firestore has preferences → cloud wins
          appState.setPersona(
            newGender: data['gender'],
            newAge: data['age'],
            newAppliances: Map<String, int>.from(data['appliances'] ?? {}),
          );
          appState.setAllergies(Set<String>.from(data['allergies'] ?? []));
        } else {
          // Firestore has NO preferences → save local wizard data up
          await _auth.savePreferences(
            uid: user.uid,
            gender: appState.gender,
            age: appState.age,
            appliances: Map<String, int>.from(appState.appliances),
            allergies: appState.allergies.toList(),
          );
        }

        // Always set username from Firestore or Firebase Auth displayName
        final name = data?['username'] ?? user.displayName ?? '';
        if (name.isNotEmpty) appState.userName = name;

        if (mounted) _goHome();
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Google sign-in failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // save persona wizard preferences to Firestore
  Future<void> _savePersonaPreferences() async {
    final user = _auth.currentUser;
    if (user != null) {
      final appState = context.read<AppState>();
      await _auth.savePreferences(
        uid: user.uid,
        gender: appState.gender,
        age: appState.age,
        appliances: Map<String, int>.from(appState.appliances),
        allergies: appState.allergies.toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.restaurant_menu,
                    size: 72,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'DishMind',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Welcome',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Please enter email';
                            final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                            if (!re.hasMatch(v.trim())) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              tooltip: _obscure ? 'Show' : 'Hide',
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 4)
                              ? 'At least 4 characters'
                              : null,
                          onFieldSubmitted: (_) => _doLogin(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: _loading
                        ? null
                        : _doLogin, // disabled while loading
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Log in'),
                  ),
                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: _loading ? null : _doGoogleLogin,
                    icon: const Icon(Icons.account_circle),
                    label: const Text('Continue with Google'),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateAccountScreen(),
                            ),
                          );
                        },
                        child: const Text('Create new account'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: const Text('Forgot password'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
