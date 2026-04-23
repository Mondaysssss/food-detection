// [OOP] Settings page: displays user info + Preferences (navigates to a sub-page to adjust appliance counts + allergies, applied on Confirm) + reset data.
// ✅ Confirm is pinned to the bottom (bottomNavigationBar), no scrolling required to see it.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/glass.dart';

import '../../domain/services/auth_service.dart';
import 'intro_start_screen.dart';

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
          // Top profile
          glass(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 34,
                  child: Icon(Icons.person, size: 34),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ✅ Age / Gender same font size as user name (18)
                      // ✅ "Age:" / "Gender:" white; value text black
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Age: ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text: '${app.age}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color.fromARGB(255, 103, 163, 85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Gender: ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text: app.gender ?? '—',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color.fromARGB(255, 103, 163, 85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),

          // Preference -> new page (same dart file)
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

          glass(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange.shade200.withValues(alpha: .2),
                ),
                onPressed: () async {
                  context.read<AppState>().resetAll();
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const IntroStartScreen(),
                      ),
                      (_) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// Preference page (same dart file)
// ✅ All changes stored in temp first, only written to AppState after pressing Confirm
// ✅ Confirm pinned to bottom (bottomNavigationBar)
// =========================================================
class _PreferencePage extends StatefulWidget {
  const _PreferencePage();

  @override
  State<_PreferencePage> createState() => _PreferencePageState();
}

class _PreferencePageState extends State<_PreferencePage> {
  static const applianceRows = [
    ('Cookware (wok, pot, frying pan)', 'cookware'),
    ('Stove / cooktop (induction, gas stove)', 'stove'),
    ('Electric cooking (rice cooker)', 'electric'),
    ('Baking (oven)', 'bake'),
  ];

  static const allergens = [
    'Peanuts',
    'Tree nuts (walnuts, almonds, cashews, etc.)',
    'Milk / dairy',
    'Eggs',
    'Fish',
    'Shellfish (shrimp, crab, lobster)',
    'Wheat (gluten)',
    'Soy (soybeans / soy products)',
    'Beef / pork',
  ];

  bool _inited = false;

  // temp (only modified here before Confirm)
  final Map<String, int> _tempAppliances = {
    'cookware': 0,
    'stove': 0,
    'electric': 0,
    'bake': 0,
  };
  final Set<String> _tempAllergies = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;

    final app = context.read<AppState>();

    for (final r in applianceRows) {
      final key = r.$2;
      _tempAppliances[key] = app.applianceValue(key);
    }

    _tempAllergies
      ..clear()
      ..addAll(app.allergies);

    _inited = true;
  }

  int _tempValue(String key) {
    final v = _tempAppliances[key] ?? 0;
    final mn = AppState.applianceMin[key] ?? 0;
    return v < mn ? mn : v;
  }

  void _setTempAppliance(String key, int v) {
    final max = AppState.applianceMax[key] ?? 999;
    var vv = v;
    if (vv < 0) vv = 0;
    if (vv > max) vv = max;
    setState(() => _tempAppliances[key] = vv);
  }

  bool _hasTempAllergy(String name) => _tempAllergies.contains(name);

  void _toggleTempAllergy(String name) {
    setState(() {
      if (_tempAllergies.contains(name))
        _tempAllergies.remove(name);
      else
        _tempAllergies.add(name);
    });
  }

  Future<void> _confirm() async {
    final app = context.read<AppState>();

    for (final r in applianceRows) {
      final key = r.$2;
      app.setAppliance(key, _tempAppliances[key] ?? 0);
    }
    app.setAllergies(Set<String>.from(_tempAllergies));

    final auth = AuthService();
    final user = auth.currentUser;
    debugPrint('>>> _confirm: user = ${user?.uid}'); // ADD THIS
    if (user != null) {
      try {
        await auth.savePreferences(
          uid: user.uid,
          gender: app.gender,
          birthYear: app.birthYear!,
          birthMonth: app.birthMonth!,
          birthDay: app.birthDay!,
          appliances: Map<String, int>.from(app.appliances),
          allergies: app.allergies.toList(),
        );
        debugPrint('>>> preferences saved OK'); // ADD THIS
      } catch (e) {
        debugPrint('>>> savePreferences FAILED: $e'); // ADD THIS
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preference updated')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bottomBarHeight = 76.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Preference')),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: glass(
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomBarHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== Appliance counts =====
            glass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Kitchen appliances (counts)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),

                  for (final r in applianceRows) ...[
                    Builder(
                      builder: (context) {
                        final key = r.$2;
                        final min = AppState.applianceMin[key] ?? 0;
                        final max = AppState.applianceMax[key] ?? 4;

                        final ddItems = List<DropdownMenuItem<int>>.generate(
                          max - min + 1,
                          (i) => DropdownMenuItem(
                            value: i + min,
                            child: Text(
                              (i + min).toString(),
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.$1,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                    if ((AppState.applianceMin[key] ?? 0) > 0)
                                      Text(
                                        '(min: ${AppState.applianceMin[key]})',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              DropdownButton<int>(
                                value: _tempValue(key),
                                items: ddItems,
                                onChanged: (v) =>
                                    _setTempAppliance(key, v ?? 0),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ===== Allergies (temp) =====
            glass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Food allergies',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 610,
                    child: Scrollbar(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: allergens.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final name = allergens[i];
                          final checked = _hasTempAllergy(name);

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _toggleTempAllergy(name),
                            child: glass(
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                    ),
                                  ),
                                  if (checked)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: .15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 18,
                                          color: Colors.greenAccent,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
