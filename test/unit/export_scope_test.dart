import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_lens/core/database/app_database.dart';
import 'package:receipt_lens/core/money.dart';
import 'package:receipt_lens/features/receipts/data/receipt_repository.dart';
import 'package:receipt_lens/features/receipts/domain/export_scope.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_draft.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_source.dart';

void main() {
  late AppDatabase db;
  late ReceiptRepository repo;
  late int cat;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReceiptRepository(db);
    cat = (await db.select(db.categories).get()).first.id;
  });

  tearDown(() => db.close());

  Future<void> add(String merchant, DateTime when) => repo.save(
    ReceiptDraft(
      merchant: merchant,
      purchasedAt: when,
      total: const Money(1000),
      categoryId: cat,
      rawText: '',
      source: ReceiptSource.manual,
    ),
  );

  Future<List<Receipt>> all() => repo.watchAll().first;

  List<String> names(List<Receipt> r) => r.map((e) => e.merchant).toList();

  final now = DateTime(2026, 11, 22);

  Future<void> seed() async {
    await add('Oct', DateTime(2026, 10, 31, 23, 59));
    await add('Early', DateTime(2026, 11, 2));
    await add('Late', DateTime(2026, 11, 20));
    await add('Dec', DateTime(2026, 12, 1));
  }

  test('this month holds only this month, newest first', () async {
    await seed();
    final receipts = await all();

    final picked = selectForExport(
      ExportScope.thisMonth,
      all: receipts,
      filtered: receipts,
      now: now,
    );

    expect(names(picked), ['Late', 'Early']);
  });

  test('last month holds only last month', () async {
    await seed();
    final receipts = await all();

    final picked = selectForExport(
      ExportScope.lastMonth,
      all: receipts,
      filtered: receipts,
      now: now,
    );

    expect(names(picked), ['Oct']);
  });

  test('last month in January wraps back to December', () async {
    await add('Dec', DateTime(2026, 12, 15));
    await add('Jan', DateTime(2027, 1, 3));
    final receipts = await all();

    final picked = selectForExport(
      ExportScope.lastMonth,
      all: receipts,
      filtered: receipts,
      now: DateTime(2027, 1, 15),
    );

    expect(names(picked), ['Dec']);
  });

  test('everything is newest first', () async {
    await seed();
    final receipts = await all();

    final picked = selectForExport(
      ExportScope.all,
      all: receipts,
      filtered: const [],
      now: now,
    );

    expect(names(picked), ['Dec', 'Late', 'Early', 'Oct']);
  });

  test(
    'current view keeps exactly what the list shows, in its order',
    () async {
      await seed();
      final receipts = await all();
      final shown = receipts.reversed.toList();

      final picked = selectForExport(
        ExportScope.currentView,
        all: receipts,
        filtered: shown,
        now: now,
      );

      expect(names(picked), names(shown));
    },
  );
}
