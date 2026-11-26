import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:receipt_lens/shared/category_icons.dart';

void main() {
  test('each default category has its own icon', () {
    final names = [
      'Food',
      'Groceries',
      'Transport',
      'Shopping',
      'Bills',
      'Health',
      'Entertainment',
    ];

    expect({for (final n in names) categoryIcon(n)}, hasLength(names.length));
  });

  test('unknown and missing categories get the generic icon', () {
    expect(categoryIcon('Other'), Icons.receipt_long_outlined);
    expect(categoryIcon('Pets'), Icons.receipt_long_outlined);
    expect(categoryIcon(null), Icons.receipt_long_outlined);
  });
}
