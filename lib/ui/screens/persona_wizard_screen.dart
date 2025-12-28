// [OOP] Wizard：收集使用者偏好（口味、忌口等）並存入 AppState。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
  const QuestionDef({required this.id, required this.title, required this.type});
}

class _PersonaWizardScreenState extends State<PersonaWizardScreen> {
  // add/remove questions here
  final List<QuestionDef> _questions = const [
    QuestionDef(id: 'gender', title: 'Gender', type: QType.genderButtons),
    QuestionDef(id: 'age', title: 'Age', type: QType.ageWheel),
    QuestionDef(id: 'appliance', title: 'Which kitchen appliances do you own?', type: QType.applianceDropdowns),
    QuestionDef(id: 'allergy', title: 'Food allergies', type: QType.allergyCheckboxes),
  ];

  int _index = 0;

  String? _gender;
  int _age = 18;

  final Map<String, int> _appliances = {
    'cookware': 0,
    'stove': 0,
    'electric': 0,
    'bake': 0,
  };

  final Set<String> _allergies = {};

  late FixedExtentScrollController _ageCtl;

  @override
  void initState() {
    super.initState();
    _ageCtl = FixedExtentScrollController(initialItem: (_age - 13).clamp(0, 86));
  }

  @override
  void dispose() {
    _ageCtl.dispose();
    super.dispose();
  }

  double get _progress => (_index + 1) / _questions.length;
  bool get _isLast => _index == _questions.length - 1;

  void _nextOrFinish() {
    if (_index < _questions.length - 1) {
      setState(() => _index++);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
    }
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

            Text(q.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),

            // 讓每一題的控件（多選/選擇器等）置中顯示
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _buildQuestion(q),
                ),
              ),
            ),

            // 底部：返回 + Next/Finish
            Row(
              children: [
                // 小返回按鈕（第一題就禁用）
                IconButton(
                  onPressed: _index == 0 ? null : _prev,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 8),

                // Next step / Finish 佔滿剩餘寬度
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextOrFinish,
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
              title: Text(o.$1),
              secondary: Icon(o.$2, size: 38),//放大字
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _qAge() {
    final items = List<int>.generate(87, (i) => i + 13); // 13..99

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 300, // 原本 180 -> 放大
        child: CupertinoPicker(
          scrollController: _ageCtl,
          itemExtent: 52, // 原本 36 -> 每格更高
          magnification: 1.25, // 中間選中更大
          useMagnifier: true,
          onSelectedItemChanged: (i) => setState(() => _age = items[i]),
          children: [
            for (final v in items)
              Center(
                child: Text(
                  '$v',
                  style: const TextStyle(
                    fontSize: 22, // 字更大
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
      ('Cookware (wok, soup pot, frying pan, steamer, sauté, stew, pressure cooker)', 'cookware'),
      ('Stove / cooktop (induction, gas stove)', 'stove'),
      ('Electric cooking (rice cooker, slow cooker, electric skillet)', 'electric'),
      ('Baking / air frying (oven, air fryer)', 'bake'),
    ];

    final ddItems = List<DropdownMenuItem<int>>.generate(
      5,
      (i) => DropdownMenuItem(
        value: i,
        child: Text(
          i.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), // ✅ 放大
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final r in rows) ...[
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: glass(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.$1,
                        textAlign: TextAlign.center, // 文字也置中（你想要更「正中」就保留）
                        style: const TextStyle(fontSize: 17),//放大文字
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _appliances[r.$2]!,
                      items: ddItems,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700), // 放大
                      onChanged: (v) => setState(() => _appliances[r.$2] = v ?? 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
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
      'Mango',
      'Kiwi',
      'Avocado',
      'Sesame / sesame oil',
      'Coconut',
      'Tomato',
      'Beef / pork',
      'Taro',
    ];

    return SizedBox(
      height: 340,
      child: Scrollbar(
        child: ListView.separated(
          itemCount: allergens.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final name = allergens[i];
            final checked = _allergies.contains(name);
            return CheckboxListTile(
              title: Text(
                name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), // ✅ 放大
              ),
              value: checked,
              onChanged: (v) {
                setState(() {
                  if (v == true) _allergies.add(name);
                  else _allergies.remove(name);
                });
              },
            );
          },
        ),
      ),
    );
  }
}