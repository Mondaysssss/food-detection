// [OOP] 設定頁：顯示使用者資訊 + Preference(推到新頁修改 PersonaWizard appliance 數目) + 重設資料。
// 只改 settings_page.dart：Preference 頁用同一檔案內的 widget，不新增新 dart。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/glass.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // =========================================================
          // Top profile
          // =========================================================
          glass(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 34,
                  child: Icon(Icons.person, size: 34), // 冇圖用預設
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.userName, // login 未做：先顯示 User name
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Age: ${app.age}   •   Gender: ${app.gender ?? '—'}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // =========================================================
          // Settings title
          // =========================================================
          const Text(
            'Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),

          // =========================================================
          // Preference (go to a new page, but still same dart file)
          // =========================================================
          glass(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _PreferencePage()),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.tune),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Preference',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // =========================================================
          // Reset all data (last)
          // =========================================================
          glass(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade200.withValues(alpha: .2),
                ),
                onPressed: () => context.read<AppState>().resetAll(),
                icon: const Icon(Icons.delete),
                label: const Text('Reset all data'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// Preference page (same dart file, but a "new page" via Navigator.push)
// =========================================================
class _PreferencePage extends StatelessWidget {
  const _PreferencePage();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    const rows = [
      (
        'Cookware (wok, soup pot, frying pan, steamer, sauté, stew, pressure cooker)',
        'cookware',
      ),
      ('Stove / cooktop (induction, gas stove)', 'stove'),
      (
        'Electric cooking (rice cooker, slow cooker, electric skillet)',
        'electric',
      ),
      ('Baking / air frying (oven, air fryer)', 'bake'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Preference')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Kitchen appliances (counts)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              // ✅ 改的係「數目」，對應 persona_wizard_screen.dart 的 _qAppliance dropdown
              for (final r in rows) ...[
                Builder(
                  builder: (context) {
                    final key = r.$2;
                    final max = AppState.applianceMax[key] ?? 4;

                    final ddItems = List<DropdownMenuItem<int>>.generate(
                      max + 1,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(
                          i.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.$1,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 10),
                          DropdownButton<int>(
                            value: app.applianceValue(key),
                            items: ddItems,
                            onChanged: (v) => context
                                .read<AppState>()
                                .setAppliance(key, v ?? 0),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 4),
              const Text(
                'Note: Persona Wizard requires cookware >= 1 and stove >= 1 to proceed.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
