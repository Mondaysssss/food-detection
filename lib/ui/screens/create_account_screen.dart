// lib/ui/screens/create_account_screen.dart
// [OOP] 建立帳號頁：純 UI + 基本表單驗證（暫無後端）。
// Create account screen: UI + basic form validation (no backend yet).

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // add
import 'home_shell.dart';
import '../../domain/services/auth_service.dart'; // add
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import 'persona_wizard_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService(); // add
  bool _loading = false; // add

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _agree = true; // 你想要條款 checkbox 就保留；唔要就可以刪

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 0)),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept terms to continue')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.signUp(
        email: _email.text,
        password: _password.text,
        username: _name.text,
      );

      // ── save persona wizard preferences to Firestore ──
      final user = _auth.currentUser;
      if (user != null && mounted) {
        final appState = context.read<AppState>();
        appState.userName = _name.text.trim();

        if (appState.gender != null) {
          // 已做過 Wizard → 存 Firestore → 去首頁
          await _auth.savePreferences(
            uid: user.uid,
            gender: appState.gender,
            age: appState.age,
            appliances: Map<String, int>.from(appState.appliances),
            allergies: appState.allergies.toList(),
          );
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Account created!')));
            _goHome();
          }
        } else {
          // 沒做過 Wizard → 去 Wizard（完成後存 Firestore + 去首頁）
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Account created!')));
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const PersonaWizardScreen(goHomeAfterFinish: true),
              ),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? 'Sign up failed')));
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? 'Sign up failed')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.person_add_alt_1,
                    size: 56,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Create account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _name,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                          obscureText: _obscure1,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure1 = !_obscure1),
                              icon: Icon(
                                _obscure1
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              tooltip: _obscure1 ? 'Show' : 'Hide',
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Please enter password';
                            if (v.length < 6) return 'At least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirm,
                          obscureText: _obscure2,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon: const Icon(Icons.lock_reset),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure2 = !_obscure2),
                              icon: Icon(
                                _obscure2
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              tooltip: _obscure2 ? 'Show' : 'Hide',
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Please confirm password';
                            if (v != _password.text)
                              return 'Password does not match';
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  SwitchListTile.adaptive(
                    value: _agree,
                    onChanged: (v) => setState(() => _agree = v),
                    title: const Text('I agree to the terms'),
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 8),

                  ElevatedButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Create account'),
                  ),

                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Already have an account? Log in'),
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
