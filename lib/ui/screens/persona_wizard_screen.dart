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

            _buildQuestion(q),

            const Spacer(),

            ElevatedButton(
              onPressed: _nextOrFinish,
              child: Text(_isLast ? 'Finish' : 'Next step'),
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

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in opts)
          ChoiceChip(
            label: Text(o.$1),
            avatar: Icon(o.$2, size: 18),
            selected: _gender == o.$1,
            onSelected: (_) => setState(() => _gender = o.$1),
          ),
      ],
    );
  }

  Widget _qAge() {
    final items = List<int>.generate(87, (i) => i + 13); // 13..99
    return SizedBox(
      height: 180,
      child: CupertinoPicker(
        scrollController: _ageCtl,
        itemExtent: 36,
        onSelectedItemChanged: (i) => setState(() => _age = items[i]),
        children: [for (final v in items) Center(child: Text('$v'))],
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
      (i) => DropdownMenuItem(value: i, child: Text(i.toString())),
    );

    return Column(
      children: [
        for (final r in rows) ...[
          glass(
            child: Row(
              children: [
                Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 14))),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _appliances[r.$2]!,
                  items: ddItems,
                  onChanged: (v) => setState(() => _appliances[r.$2] = v ?? 0),
                ),
              ],
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
              title: Text(name),
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