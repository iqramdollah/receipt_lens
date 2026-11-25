import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_lens/core/database/app_database.dart';

import 'package:receipt_lens/core/money.dart';
import 'package:receipt_lens/features/receipts/data/receipt_repository.dart';

import 'package:receipt_lens/features/receipts/domain/receipt_draft.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_source.dart';

void main() {
  late AppDatabase db;
  late ReceiptRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReceiptRepository(db);
  });

  tearDown(() => db.close());

  ReceiptDraft draft({required int categoryId, bool needsReview = false}) =>
      ReceiptDraft(
        needsReview: needsReview,
        merchant: 'Mydin',
        purchasedAt: DateTime(2026, 11, 20, 13, 45),
        total: const Money(4400),
        subtotal: const Money(4150),
        tax: const Money(249),
        rounding: const Money(1),
        categoryId: categoryId,
        rawText: 'MYDIN\nNasi Lemak 2  17.00\nTotal 44.00',
        source: ReceiptSource.llm,
        items: const [
          ReceiptItemDraft(
            name: 'Nasi Lemak',
            quantity: 2,
            unitPrice: Money(850),
            lineTotal: Money(1700),
          ),
        ],
      );

  Future<int> firstCategoryId() async =>
      (await db.select(db.categories).get()).first.id;

  test('seeds the default categories', () async {
    final names = (await db.select(db.categories).get()).map((c) => c.name);
    expect(names, containsAll(['Food', 'Groceries', 'Transport', 'Other']));
  });

  test('saves a receipt with its items', () async {
    final id = await repo.save(draft(categoryId: await firstCategoryId()));

    final saved = await repo.getById(id);
    expect(saved, isNotNull);
    expect(saved!.receipt.merchant, 'Mydin');
    expect(saved.receipt.totalSen, 4400);
    expect(saved.receipt.source, ReceiptSource.llm);
    expect(saved.items, hasLength(1));
    expect(saved.items.single.lineTotalSen, 1700);
  });

  test('deleting a receipt also deletes its items', () async {
    final id = await repo.save(draft(categoryId: await firstCategoryId()));

    await repo.delete(id);

    expect(await db.select(db.receipts).get(), isEmpty);
    expect(await db.select(db.receiptItems).get(), isEmpty);
  });

  test('rejects an unknown category and saves nothing', () async {
    await expectLater(repo.save(draft(categoryId: 9999)), throwsA(anything));

    expect(await db.select(db.receipts).get(), isEmpty);
  });

  test('restore brings back a deleted receipt with its items', () async {
    final id = await repo.save(draft(categoryId: await firstCategoryId()));
    final deleted = (await repo.getById(id))!;

    await repo.delete(id);
    await repo.restore(deleted);

    final restored = await repo.getById(id);
    expect(restored, isNotNull);
    expect(restored!.receipt.merchant, 'Mydin');
    expect(restored.items, hasLength(1));
  });

  test(
    'updateDetails edits fields, clears needsReview, keeps breakdown',
    () async {
      final cat = await firstCategoryId();
      final id = await repo.save(draft(categoryId: cat, needsReview: true));

      await repo.updateDetails(
        id,
        merchant: 'Mydin Mart',
        purchasedAt: DateTime(2026, 11, 19),
        total: const Money(4400),
        categoryId: cat,
      );

      final saved = (await repo.getById(id))!;
      expect(saved.receipt.merchant, 'Mydin Mart');
      expect(saved.receipt.purchasedAt, DateTime(2026, 11, 19));
      expect(saved.receipt.needsReview, isFalse);
      expect(saved.receipt.subtotalSen, 4150);
      expect(saved.receipt.taxSen, 249);
      expect(saved.items, hasLength(1));
    },
  );

  test('changing the total drops subtotal, tax and rounding', () async {
    final cat = await firstCategoryId();
    final id = await repo.save(draft(categoryId: cat));

    await repo.updateDetails(
      id,
      merchant: 'Mydin',
      purchasedAt: DateTime(2026, 11, 20),
      total: const Money(5000),
      categoryId: cat,
    );

    final r = (await repo.getById(id))!.receipt;
    expect(r.totalSen, 5000);
    expect(r.subtotalSen, isNull);
    expect(r.taxSen, isNull);
    expect(r.roundingSen, 0);
  });
}
