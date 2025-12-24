import 'package:flutter/material.dart';

Widget titleText(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
);

InputDecoration inputDecoration(String hint, {IconData? icon}) {
  return InputDecoration(
    prefixIcon: icon == null ? null : Icon(icon),
    hintText: hint,
    filled: true,
    fillColor: Colors.white12,
    hintStyle: const TextStyle(color: Colors.white60),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white),
    ),
  );
}

Widget sectionTitle(String t) => Text(
  t,
  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
);

Widget kvPill(String k, String v) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  decoration: BoxDecoration(
    color: Colors.white12,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: Colors.white24),
  ),
  child: Text('$k: $v', style: const TextStyle(fontSize: 12)),
);

Widget qtyList(List<MapEntry<String, String>> items) {
  if (items.isEmpty) {
    return const Text('—', style: TextStyle(color: Colors.white70));
  }
  return Column(
    children: [
      for (final e in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(prettyName(e.key))),
              Text(e.value, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
    ],
  );
}

String prettyName(String key) {
  switch (key) {
    case 'soy_sauce': return 'Soy sauce';
    case 'sesame': return 'Sesame';
    case 'pasta': return 'Pasta';
    default: return key.replaceAll('_', ' ');
  }
}