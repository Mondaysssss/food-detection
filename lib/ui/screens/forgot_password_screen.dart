// lib/ui/screens/forgot_password_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool _isValidEmail(String s) {
    final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return re.hasMatch(s.trim());
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed to send reset email')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed to send reset email')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _sent ? _buildSentView() : _buildEmailForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.lock_reset, size: 56, color: Colors.white70),
        const SizedBox(height: 12),
        const Text(
          'Reset your password',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter your email and we\'ll send you a link to reset your password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'Please enter email';
              if (!_isValidEmail(s)) return 'Invalid email';
              return null;
            },
            onFieldSubmitted: (_) => _sendReset(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _loading ? null : _sendReset,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: const Text('Send reset link'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to login'),
        ),
      ],
    );
  }

  Widget _buildSentView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: Colors.greenAccent,
        ),
        const SizedBox(height: 12),
        const Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'We sent a password reset link to:\n${_email.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 6),
        const Text(
          'Open the link in your email to set a new password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () {
            setState(() => _sent = false);
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Send again'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.login),
          label: const Text('Back to login'),
        ),
      ],
    );
  }
}
