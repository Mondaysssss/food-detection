// lib/ui/screens/intro_start_screen.dart
// App 開場頁（IntroStartScreen）
// 用途：
// - 首次開 App 時顯示歡迎畫面
// - 提供「開始使用」進入 Persona Wizard，以及「登入」選項

import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'persona_wizard_screen.dart';

class IntroStartScreen extends StatelessWidget {
  const IntroStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 歡迎卡片
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1f2937), Color(0xFF0b1220)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: const [
                        Icon(Icons.fastfood, size: 96, color: Colors.white70),
                        SizedBox(height: 12),
                        Text(
                          'Start your cooking journey',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 開始使用按鈕
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PersonaWizardScreen()),
                      );
                    },
                    child: const Text('Start using'),
                  ),

                  const SizedBox(height: 12),

                  // 登入按鈕
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text('Login'),
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