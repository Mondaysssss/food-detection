// [OOP] 開始頁：App 入口 UI，導向登入/設定個人資料/進入主頁。

import 'dart:math';

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

  // 你 JSX 入面用嘅「香港食物」封面圖（Unsplash 關鍵字搜尋）
  static const List<String> _hkFoodPhotos = [
    // 家常感（茶餐廳 / 燒味 / 點心 / 湯麵）
    'https://source.unsplash.com/1400x900/?hong%20kong,cha%20chaan%20teng',
    'https://source.unsplash.com/1400x900/?hong%20kong,dim%20sum',
    'https://source.unsplash.com/1400x900/?hong%20kong,noodles',
    'https://source.unsplash.com/1400x900/?hong%20kong,roast%20meat',
    'https://source.unsplash.com/1400x900/?hong%20kong,street%20food',
  ];

  late final String _heroUrl;

  @override
  void initState() {
    super.initState();
    _heroUrl = _hkFoodPhotos[Random().nextInt(_hkFoodPhotos.length)];
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          _heroUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, loading) {
                            if (loading == null) return child;
                            return Container(
                              color: Colors.black.withValues(alpha: .06),
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (ctx, _, __) => Container(
                            color: Colors.black.withValues(alpha: .06),
                            alignment: Alignment.center,
                            child: const Icon(Icons.fastfood, size: 56),
                          ),
                        ),

                        // 底部漸變（令圖片自然融入背景）
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 140,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  _bg.withValues(alpha: .92),
                                  _bg,
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 角落品牌小字（可刪）
                        Positioned(
                          left: 16,
                          top: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .78),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withValues(alpha: .85)),
                            ),
                            child: const Text(
                              'DishMind',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .6,
                                color: _ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 下方內容（標題 + 兩個按鈕）
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 底部白色面板（玻璃感）
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .78),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: .9)),
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

                        const Spacer(),

                        // Start using（主按鈕）
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _ink,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => _goStartUsing(context),
                            child: const Text(
                              'Start using',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                              side: BorderSide(color: _ink.withValues(alpha: .22)),
                              backgroundColor: Colors.white.withValues(alpha: .65),
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

                        // 底部細字
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