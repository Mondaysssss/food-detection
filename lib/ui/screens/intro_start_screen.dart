import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'persona_wizard_screen.dart';

/// 這個檔案：
/// App 的「開始 / 歡迎」畫面（對應你提供的 welcome_login_手機_ui.jsx 風格）
/// - 上方：隨機香港食物封面圖
/// - 下方：標題 + 簡介 + 兩個按鈕（Start using / Login）
/// - 按鈕行為：Start using -> PersonaWizardScreen；Login -> LoginScreen
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

  //用「香港食物」封面圖
  static const List<String> _heroUrls = [
    'https://themeatclub.com.sg/cdn/shop/files/the-meat-club-ginger-pork.jpg?v=1705912633',
    'https://img-global.cpcdn.com/recipes/4a2ccb2d78d78db4/680x781f0.5_0.50125_1.0q80/%E6%B0%A3%E7%82%B8%E5%AE%89%E6%A0%BC%E6%96%AF%E7%89%9B%E6%89%92-%E9%A3%9F%E8%AD%9C%E6%88%90%E5%93%81%E7%85%A7%E7%89%87.jpg',
    'https://www.justonecookbook.com/wp-content/uploads/2025/02/Miso-Glazed-Eggplant-3348-III-800x1200.jpg',
    'https://img-global.cpcdn.com/recipes/c78dad99dee7f8b0/300x426f0.5_0.5_1.0q80/%E8%9C%82%E8%9C%9C%E8%92%9C%E5%91%B3%E7%83%A4%E9%9B%9E%E7%BF%85%E6%B0%A3%E7%82%B8%E9%8D%8B-%E9%A3%9F%E8%AD%9C%E6%88%90%E5%93%81%E7%85%A7%E7%89%87.webp',
  ];

  /// Hero 圖載入失敗 / 未載入時，用一個「一定睇到」嘅食物 icon 當 fallback。
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
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _heroIndex = (_heroIndex + 1) % _heroUrls.length;
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

    // 參考 JSX：上方圖片約 56% 高度
    final imageH = max(260.0, h * 0.56);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                // 上方封面圖
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
                        child: Image.network(
                          _heroUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          loadingBuilder: (ctx, child, loading) {
                            if (loading == null) return child;
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                _heroFallback(),
                                const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                          errorBuilder: (ctx, _, __) => _heroFallback(),
                        ),
                      ),
                    ),
                  ),
                ),

                // 下方內容（標題 + 兩個按鈕）
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 玻璃卡片（類似 JSX 底部白色面板）
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

                        // Start using（主按鈕）—— 文字強制白色 ✅
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

                        // Login（次按鈕）
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

                        // 底部細字（參考 JSX footer）
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
