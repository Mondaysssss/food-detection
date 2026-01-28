// lib/ui/screens/forgot_password_screen.dart
// [OOP] 忘記密碼：同一個 UI 內三步驟
// Step 1: 輸入 Email → 顯示 8 位數驗證碼輸入框
// Step 2: 輸入 8 位數驗證碼 → 進入輸入新密碼
// Step 3: 輸入新密碼 → 顯示成功（demo）

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _ResetStep { email, code, newPassword }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _ResetStep _step = _ResetStep.email;

  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _pwFormKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;

  // demo：顯示用（真實情況應由後端發送）
  String? _demoSentCode;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool _isValidEmail(String s) {
    final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return re.hasMatch(s.trim());
  }

  String _generate8DigitCode() {
    // 不用 random 套件：用時間戳最後 8 位做 demo
    final ms = DateTime.now().millisecondsSinceEpoch.toString();
    return ms.substring(ms.length - 8);
  }

  void _sendEmail() {
    if (!_emailFormKey.currentState!.validate()) return;

    // demo：生成 8 位數 code + 進入 code step
    final code = _generate8DigitCode();
    setState(() {
      _demoSentCode = code;
      _step = _ResetStep.code;
      _code.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reset code sent (demo)')));
  }

  void _backToEmail() {
    setState(() {
      _step = _ResetStep.email;
      _demoSentCode = null;
      _code.clear();
      _newPassword.clear();
      _confirmPassword.clear();
    });
  }

  void _verifyCode() {
    if (!_codeFormKey.currentState!.validate()) return;

    // 暫時：當用戶輸入一定正確（你要求）
    setState(() {
      _step = _ResetStep.newPassword;
      _newPassword.clear();
      _confirmPassword.clear();
    });
  }

  void _backToCode() {
    setState(() {
      _step = _ResetStep.code;
      _newPassword.clear();
      _confirmPassword.clear();
    });
  }

  void _resetPassword() {
    if (!_pwFormKey.currentState!.validate()) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password updated (demo)')));

    // 完成：返回 login
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _ResetStep.email => 'Forgot password',
      _ResetStep.code => 'Enter verification code',
      _ResetStep.newPassword => 'Set new password',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // AppBar 左上角：
            // email step -> pop 回 login
            // code step -> 回 email step
            // newPassword step -> 回 code step
            if (_step == _ResetStep.email) {
              Navigator.pop(context);
            } else if (_step == _ResetStep.code) {
              _backToEmail();
            } else {
              _backToCode();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: switch (_step) {
                _ResetStep.email => _buildEmailStep(),
                _ResetStep.code => _buildCodeStep(),
                _ResetStep.newPassword => _buildNewPasswordStep(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
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
          'Enter your email to receive an 8-digit code.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 16),
        Form(
          key: _emailFormKey,
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
            onFieldSubmitted: (_) => _sendEmail(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _sendEmail,
          icon: const Icon(Icons.send),
          label: const Text('Send code'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to login'),
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.verified_outlined, size: 56, color: Colors.white70),
        const SizedBox(height: 12),
        const Text(
          'Enter 8-digit code',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'We sent a code to: ${_email.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 10),

        // // demo code 顯示（你之後接後端可以刪）
        // if (_demoSentCode != null)
        //   Padding(
        //     padding: const EdgeInsets.only(bottom: 10),
        //     child: Text(
        //       'Demo code: $_demoSentCode',
        //       textAlign: TextAlign.center,
        //       style: const TextStyle(fontSize: 13, color: Colors.white70),
        //     ),
        //   ),
        Form(
          key: _codeFormKey,
          child: TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Verification code (8 digits)',
              prefixIcon: Icon(Icons.key_outlined),
              border: OutlineInputBorder(),
              counterText: '', // 隱藏 counter
            ),
            maxLength: 8,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'Please enter code';
              if (s.length != 8) return 'Code must be exactly 8 digits';
              // 暫時不比對 _demoSentCode，你要求「當正確」
              return null;
            },
            onFieldSubmitted: (_) => _verifyCode(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _verifyCode,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Next'),
        ),
        const SizedBox(height: 8),

        // 你要求：可重新輸入 email 的按鈕
        OutlinedButton.icon(
          onPressed: _backToEmail,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Re-enter email'),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.lock_outline, size: 56, color: Colors.white70),
        const SizedBox(height: 12),
        const Text(
          'Set a new password',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter your new password below.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 16),

        Form(
          key: _pwFormKey,
          child: Column(
            children: [
              TextFormField(
                controller: _newPassword,
                obscureText: _obscure1,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'New password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                    icon: Icon(
                      _obscure1 ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (v) {
                  final s = (v ?? '');
                  if (s.isEmpty) return 'Please enter new password';
                  if (s.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPassword,
                obscureText: _obscure2,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: const Icon(Icons.lock_reset),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                    icon: Icon(
                      _obscure2 ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (v) {
                  final s = (v ?? '');
                  if (s.isEmpty) return 'Please confirm password';
                  if (s != _newPassword.text) return 'Password does not match';
                  return null;
                },
                onFieldSubmitted: (_) => _resetPassword(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _resetPassword,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Update password'),
        ),
        const SizedBox(height: 8),

        // 你要求：可以返回上一頁（即 code step）
        OutlinedButton.icon(
          onPressed: _backToCode,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back'),
        ),
      ],
    );
  }
}
