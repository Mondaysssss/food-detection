// [OOP] 主殼：底部導覽（推薦/相機/購物車/歷史/設定等）與各分頁。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/page_frame.dart';
import 'ai_camera_page.dart';
import 'history/history_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  final int initialIndex;
  const HomeShell({super.key, this.initialIndex = 0});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  final _pages = const [
    AiCameraPage(),
    HistoryPage(),
    SettingsPage(),
  ];

  final _titles = const [
    'Ingredient scanner',
    'History',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // ✅ 攔截系統返回鍵：唔直接 pop（防止回到登入頁）
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final exit = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Exit app?'),
            content: const Text('Do you want to exit the application?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if (exit == true) {
          SystemNavigator.pop();
        }
      },
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.9, -1.0),
            radius: 1.3,
            colors: [Color(0xFF0EA5E9), Color(0xFF0B0F14)],
            stops: [0.0, 1.0],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false, // ✅ 移除返回鍵
            title: Text(_titles[_index]),
            actions: const [SizedBox(width: 8)],
          ),
          body: PageFrame(child: _pages[_index]),
          bottomNavigationBar: NavigationBar(
            height: 64,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.photo_camera_outlined),
                selectedIcon: Icon(Icons.photo_camera),
                label: 'Scan',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                selectedIcon: Icon(Icons.history_toggle_off),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}