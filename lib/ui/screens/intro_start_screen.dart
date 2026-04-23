import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'persona_wizard_screen.dart';

/// This file:
/// App's Start / Welcome screen (based on the welcome_login_mobile_ui.jsx style provided)
/// - Top: random Hong Kong food cover image
/// - Bottom: title + intro + two buttons (Start using / Login)
/// - Button behaviour: Start using -> PersonaWizardScreen; Login -> LoginScreen
class IntroStartScreen extends StatefulWidget {
  const IntroStartScreen({super.key});

  @override
  State<IntroStartScreen> createState() => _IntroStartScreenState();
}

class _IntroStartScreenState extends State<IntroStartScreen> {
  static const _bg = Color(0xFFE8EFEA);
  static const _ink = Color(0xFF2F3A4A);
  static const Duration _fadeDur = Duration(milliseconds: 1000);
  int _heroIndex = 0;
  Timer? _heroTimer;

  String get _heroUrl => _heroUrls[_heroIndex % _heroUrls.length];

  // Use "Hong Kong food" cover image
  static const List<String> _heroUrls = [
    'assets/images/recipes/r2.jpg',
    'assets/images/recipes/r7.jpg',
    'assets/images/recipes/r9.jpg',
    'assets/images/recipes/r11.jpg',
    'assets/images/recipes/r13.jpg',
    'assets/images/recipes/r15.jpg',
    'assets/images/recipes/r16.jpg',
  ];

  /// When Hero image fails to load / not yet loaded, use a food icon as fallback.
  Widget _heroFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: .04),
            Colors.black.withValues(alpha: .10),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.lunch_dining,
        size: 120,
        color: _ink.withValues(alpha: .38),
      ),
    );
  }

  void _goStartUsing(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonaWizardScreen()),
    );
  }

  void _goLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _heroIndex = rng.nextInt(_heroUrls.length); // random start
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        int next;
        do {
          next = rng.nextInt(_heroUrls.length);
        } while (next == _heroIndex && _heroUrls.length > 1);
        _heroIndex = next;
      });
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final h = mq.size.height;

    // Reference JSX: top image approx 56% height
    final imageH = max(260.0, h * 0.56);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                // Top cover image
                SizedBox(
                  height: min(imageH, h * 0.62),
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    child: AnimatedSwitcher(
                      duration: _fadeDur,
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: SizedBox.expand(
                        key: ValueKey(_heroUrl),
                        child: Image.asset(
                          _heroUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom content (title + two buttons)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Glass card (similar to JSX bottom white panel)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .78),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .9),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .08),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Start your cooking journey',
                                style: TextStyle(
                                  fontSize: 28,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Scan what you have, get recommended recipes, and cook step-by-step.',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  height: 1.35,
                                  color: Color(0xFF4B5563),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Start using (primary button) — text forced white ✅
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _ink,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => _goStartUsing(context),
                            child: const Text(
                              'Start using',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Login (secondary button)
                        SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: BorderSide(
                                color: _ink.withValues(alpha: .22),
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: .65,
                              ),
                            ),
                            onPressed: () => _goLogin(context),
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                          ),
                        ),

                        // Bottom small text (reference JSX footer)
                        const SizedBox(height: 12),
                        const Text(
                          'By continuing, you agree to our Terms & Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
