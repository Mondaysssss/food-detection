// [OOP] Wizard：收集使用者偏好並存入 AppState。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/page_frame.dart';
import '../widgets/glass.dart';
import 'login_screen.dart';

class PersonaWizardScreen extends StatefulWidget {
  const PersonaWizardScreen({super.key});

  @override
  State<PersonaWizardScreen> createState() => _PersonaWizardScreenState();
}

enum QType { genderButtons, ageWheel, applianceDropdowns, allergyCheckboxes }

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
    QuestionDef(id: 'age', title: 'Age', type: QType.ageWheel),
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
  int _age = 18;

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

  late FixedExtentScrollController _ageCtl;

  @override
  void initState() {
    super.initState();
    _ageCtl = FixedExtentScrollController(
      initialItem: (_age - 13).clamp(0, 86),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final app = context.read<AppState>();

    _age = app.age;
    _gender = app.gender;

    for (final k in _appliances.keys) {
      _appliances[k] = app.applianceValue(k);
    }

    _allergies
      ..clear()
      ..addAll(app.allergies);

    _ageCtl.dispose();
    _ageCtl = FixedExtentScrollController(
      initialItem: (_age - 13).clamp(0, 86),
    );
  }

  @override
  void dispose() {
    _ageCtl.dispose();
    super.dispose();
  }

  double get _progress => (_index + 1) / _questions.length;
  bool get _isLast => _index == _questions.length - 1;

  bool get _canProceed {
    final q = _questions[_index];
    switch (q.type) {
      case QType.genderButtons:
        return _gender != null;
      case QType.ageWheel:
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

  void _nextOrFinish() {
    if (!_canProceed) return;

    if (_index < _questions.length - 1) {
      setState(() => _index++);
    } else {
      // ✅ 存入 AppState
      context.read<AppState>().setPersona(
        newGender: _gender,
        newAge: _age,
        newAppliances: Map<String, int>.from(_appliances),
      );
      context.read<AppState>().setAllergies(Set<String>.from(_allergies));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
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
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Close',
        ),
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
      case QType.ageWheel:
        return _qAge();
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

  Widget _qAge() {
    final items = List<int>.generate(87, (i) => i + 13);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 300,
        child: CupertinoPicker(
          scrollController: _ageCtl,
          itemExtent: 52,
          magnification: 1.25,
          useMagnifier: true,
          onSelectedItemChanged: (i) => setState(() => _age = items[i]),
          children: [
            for (final v in items)
              Center(
                child: Text(
                  '$v',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
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
