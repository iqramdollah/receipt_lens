import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_lens/core/database/app_database.dart';
import 'package:receipt_lens/core/money.dart';
import 'package:receipt_lens/features/budgets/data/budget_repository.dart';
import 'package:receipt_lens/features/receipts/data/receipt_repository.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_draft.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_source.dart';

void main() {
  test(
    'upgrading a version 1 database keeps its data and adds budgets',
    () async {
      final dir = Directory.systemTemp.createTempSync('budget_migration');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/app.db');

      // A database with a saved receipt...
      final first = AppDatabase(NativeDatabase(file));
      final categoryId = (await first.select(first.categories).get()).first.id;
      await ReceiptRepository(first).save(
        ReceiptDraft(
          merchant: 'Old receipt',
          purchasedAt: DateTime(2026, 11, 1),
          total: const Money(1250),
          categoryId: categoryId,
          rawText: '',
          source: ReceiptSource.manual,
        ),
      );
      // ...rewound to look like version 1.
      await first.customStatement('DROP TABLE budgets');
      await first.customStatement('PRAGMA user_version = 1');
      await first.close();

      // Opening it again runs the upgrade.
      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);

      final receipts = await upgraded.select(upgraded.receipts).get();
      expect(receipts.map((r) => r.merchant), ['Old receipt']);
      expect(await upgraded.select(upgraded.categories).get(), isNotEmpty);
      expect(await upgraded.select(upgraded.budgets).get(), isEmpty);

      await BudgetRepository(upgraded).setLimit(categoryId, const Money(50000));
      expect(await upgraded.select(upgraded.budgets).get(), hasLength(1));
    },
  );
}
