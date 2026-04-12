// [OOP] Wizard：收集使用者偏好並存入 AppState。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/page_frame.dart';
import '../widgets/glass.dart';
import 'login_screen.dart';
import '../../domain/services/auth_service.dart'; // 新增
import 'home_shell.dart'; // 新增

class PersonaWizardScreen extends StatefulWidget {
  final bool goHomeAfterFinish; // ← 新增
  const PersonaWizardScreen({super.key, this.goHomeAfterFinish = false});

  @override
  State<PersonaWizardScreen> createState() => _PersonaWizardScreenState();
}

enum QType {
  genderButtons,
  birthDatePicker,
  applianceDropdowns,
  allergyCheckboxes,
}

class QuestionDef {
  final String id;
  final String title;
  final QType type;
  const QuestionDef({
    required this.id,
    required this.title,
    required this.type,
  });
}

class _PersonaWizardScreenState extends State<PersonaWizardScreen> {
  final List<QuestionDef> _questions = const [
    QuestionDef(id: 'gender', title: 'Gender', type: QType.genderButtons),
    QuestionDef(
      id: 'birthDate',
      title: 'Date of Birth',
      type: QType.birthDatePicker,
    ),
    QuestionDef(
      id: 'appliance',
      title: 'Which kitchen appliances do you own?',
      type: QType.applianceDropdowns,
    ),
    QuestionDef(
      id: 'allergy',
      title: 'Food allergies',
      type: QType.allergyCheckboxes,
    ),
  ];

  int _index = 0;

  String? _gender;
  int _birthYear = 2000;
  int _birthMonth = 1;
  int _birthDay = 1;
  bool _inited = false;

  final Map<String, int> _appliances = {
    'cookware': 1,
    'stove': 1,
    'electric': 0,
    'bake': 0,
  };

  static const Map<String, int> _applianceMin = {
    'cookware': 1,
    'stove': 1,
    'electric': 0,
    'bake': 0,
  };

  static const Map<String, int> _applianceMax = {
    'cookware': 2,
    'stove': 2,
    'electric': 2,
    'bake': 1,
  };

  int _applianceValue(String key) {
    final v = _appliances[key] ?? 0;
    final max = _applianceMax[key] ?? 4;
    if (v < 0) return 0;
    if (v > max) return max;
    return v;
  }

  bool _applianceOk(String key) {
    final v = _applianceValue(key);
    final min = _applianceMin[key] ?? 0;
    final max = _applianceMax[key] ?? 999;
    return v >= min && v <= max;
  }

  final Set<String> _allergies = {};

  late FixedExtentScrollController _yearCtl;
  late FixedExtentScrollController _monthCtl;
  late FixedExtentScrollController _dayCtl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final minYear = now.year - 100; // 1926
    final maxYear = now.year - 12; // 2014
    _yearCtl = FixedExtentScrollController(
      initialItem: (_birthYear - minYear).clamp(0, maxYear - minYear),
    );
    _monthCtl = FixedExtentScrollController(
      initialItem: (_birthMonth - 1).clamp(0, 11),
    );
    _dayCtl = FixedExtentScrollController(
      initialItem: (_birthDay - 1).clamp(0, 30),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;

    final app = context.read<AppState>();

    final now = DateTime.now();
    _birthYear = (app.birthYear ?? 2000).clamp(now.year - 100, now.year - 12);
    _birthMonth = app.birthMonth ?? 1;
    _birthDay = app.birthDay ?? 1;

    _gender = app.gender;

    for (final k in _appliances.keys) {
      _appliances[k] = app.applianceValue(k);
    }

    _allergies
      ..clear()
      ..addAll(app.allergies);

    // Rebuild controllers to match loaded values
    final minYear = now.year - 100;
    final maxYear = now.year - 12;
    _yearCtl.dispose();
    _yearCtl = FixedExtentScrollController(
      initialItem: (_birthYear - minYear).clamp(0, maxYear - minYear),
    );
    _monthCtl.dispose();
    _monthCtl = FixedExtentScrollController(
      initialItem: (_birthMonth - 1).clamp(0, 11),
    );
    _dayCtl.dispose();
    _dayCtl = FixedExtentScrollController(
      initialItem: (_birthDay - 1).clamp(0, 30),
    );
  }

  @override
  void dispose() {
    _yearCtl.dispose();
    _monthCtl.dispose();
    _dayCtl.dispose();
    super.dispose();
  }

  double get _progress => (_index + 1) / _questions.length;
  bool get _isLast => _index == _questions.length - 1;

  bool get _canProceed {
    final q = _questions[_index];
    switch (q.type) {
      case QType.genderButtons:
        return _gender != null;
      case QType.birthDatePicker:
        return true;
      case QType.applianceDropdowns:
        return _applianceOk('cookware') &&
            _applianceOk('stove') &&
            _applianceOk('electric') &&
            _applianceOk('bake');
      case QType.allergyCheckboxes:
        return true;
    }
  }

  Future<void> _nextOrFinish() async {
    if (!_canProceed) return;

    if (_index < _questions.length - 1) {
      setState(() => _index++);
    } else {
      // ✅ 存入 AppState
      context.read<AppState>().setPersona(
        newGender: _gender,
        newBirthYear: _birthYear,
        newBirthMonth: _birthMonth,
        newBirthDay: _birthDay,
        newAppliances: Map<String, int>.from(_appliances),
      );
      context.read<AppState>().setAllergies(Set<String>.from(_allergies));

      if (widget.goHomeAfterFinish) {
        // 從登入/建帳流程過來 → 存 Firestore → 去 HomeShell
        final auth = AuthService();
        final user = auth.currentUser;
        if (user != null) {
          final app = context.read<AppState>();
          await auth.savePreferences(
            uid: user.uid,
            gender: app.gender,
            username: app.userName != 'User name' ? app.userName : null,
            birthYear: app.birthYear!,
            birthMonth: app.birthMonth!,
            birthDay: app.birthDay!,
            appliances: Map<String, int>.from(app.appliances),
            allergies: app.allergies.toList(),
          );
        }
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 0)),
            (_) => false,
          );
        }
      } else {
        // 從 IntroStartScreen 過來 → 去 LoginScreen（現有行為）
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  void _prev() {
    if (_index > 0) setState(() => _index--);
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_index];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalization'),
        automaticallyImplyLeading: false,
      ),
      body: PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: _progress, minHeight: 8),
            ),
            const SizedBox(height: 16),

            Text(
              q.title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _buildQuestion(q),
                ),
              ),
            ),

            Row(
              children: [
                IconButton(
                  onPressed: _index == 0 ? null : _prev,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canProceed ? _nextOrFinish : null,
                    child: Text(_isLast ? 'Finish' : 'Next step'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(QuestionDef q) {
    switch (q.type) {
      case QType.genderButtons:
        return _qGender();
      case QType.birthDatePicker:
        return _qBirthDate();
      case QType.applianceDropdowns:
        return _qAppliance();
      case QType.allergyCheckboxes:
        return _qAllergy();
    }
  }

  Widget _qGender() {
    final opts = const [
      ('Male', Icons.male),
      ('Female', Icons.female),
      ('Other', Icons.transgender),
      ('Prefer not to say', Icons.help_outline),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final o in opts) ...[
          glass(
            child: RadioListTile<String>(
              value: o.$1,
              groupValue: _gender,
              onChanged: (v) => setState(() => _gender = v),
              title: Text(
                o.$1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              secondary: Icon(o.$2, size: 30),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              visualDensity: const VisualDensity(vertical: 1.0),
              dense: true,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _qBirthDate() {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    final minYear = now.year - 100;
    final maxYear = now.year - 12;
    final years = List<int>.generate(maxYear - minYear + 1, (i) => i + minYear);
    final daysInMonth = DateUtils.getDaysInMonth(_birthYear, _birthMonth);
    final days = List<int>.generate(daysInMonth, (i) => i + 1);

    // clamp day if month changed to one with fewer days
    if (_birthDay > daysInMonth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _birthDay = daysInMonth;
            _dayCtl.dispose();
            _dayCtl = FixedExtentScrollController(initialItem: _birthDay - 1);
          });
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 300,
        child: Row(
          children: [
            // ── Month ──
            Expanded(
              flex: 3,
              child: CupertinoPicker(
                scrollController: _monthCtl,
                itemExtent: 52,
                magnification: 1.20,
                useMagnifier: true,
                squeeze: 1.0,
                onSelectedItemChanged: (i) {
                  setState(() {
                    _birthMonth = i + 1;
                    final maxDay = DateUtils.getDaysInMonth(
                      _birthYear,
                      _birthMonth,
                    );
                    if (_birthDay > maxDay) {
                      _birthDay = maxDay;
                      _dayCtl.dispose();
                      _dayCtl = FixedExtentScrollController(
                        initialItem: _birthDay - 1,
                      );
                    }
                  });
                },
                children: [
                  for (final name in monthNames)
                    Center(
                      child: Text(name, style: const TextStyle(fontSize: 20)),
                    ),
                ],
              ),
            ),
            // ── Day ──
            Expanded(
              flex: 1,
              child: CupertinoPicker(
                scrollController: _dayCtl,
                itemExtent: 52,
                magnification: 1.20,
                useMagnifier: true,
                squeeze: 1.0,
                onSelectedItemChanged: (i) => setState(() => _birthDay = i + 1),
                children: [
                  for (final d in days)
                    Center(
                      child: Text('$d', style: const TextStyle(fontSize: 20)),
                    ),
                ],
              ),
            ),
            // ── Year ──
            Expanded(
              flex: 2,
              child: CupertinoPicker(
                scrollController: _yearCtl,
                itemExtent: 52,
                magnification: 1.20,
                useMagnifier: true,
                squeeze: 1.0,
                onSelectedItemChanged: (i) {
                  setState(() {
                    _birthYear = years[i];
                    final maxDay = DateUtils.getDaysInMonth(
                      _birthYear,
                      _birthMonth,
                    );
                    if (_birthDay > maxDay) {
                      _birthDay = maxDay;
                      _dayCtl.dispose();
                      _dayCtl = FixedExtentScrollController(
                        initialItem: _birthDay - 1,
                      );
                    }
                  });
                },
                children: [
                  for (final y in years)
                    Center(
                      child: Text('$y', style: const TextStyle(fontSize: 20)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qAppliance() {
    final rows = const [
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final r in rows)
          Builder(
            builder: (context) {
              final key = r.$2;
              final min = _applianceMin[key] ?? 0;
              final max = _applianceMax[key] ?? 4;

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

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: glass(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    r.$1,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 17),
                                  ),
                                  if ((_applianceMin[key] ?? 0) > 0)
                                    Text(
                                      '(min: ${_applianceMin[key]})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<int>(
                              value: _applianceValue(key),
                              items: ddItems,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              onChanged: (v) =>
                                  setState(() => _appliances[key] = v ?? 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _qAllergy() {
    const allergens = [
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: SizedBox(
        height: 610,
        child: Scrollbar(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: allergens.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final name = allergens[i];
              final checked = _allergies.contains(name);

              void toggle() {
                setState(() {
                  if (checked)
                    _allergies.remove(name);
                  else
                    _allergies.add(name);
                });
              }

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: toggle,
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
                              color: Colors.white.withValues(alpha: .15),
                              borderRadius: BorderRadius.circular(999),
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
    );
  }
}
