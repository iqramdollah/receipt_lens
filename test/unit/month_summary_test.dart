import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_lens/core/database/app_database.dart';
import 'package:receipt_lens/core/money.dart';
import 'package:receipt_lens/features/insights/domain/month_summary.dart';
import 'package:receipt_lens/features/receipts/data/receipt_repository.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_draft.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_source.dart';

void main() {
  late AppDatabase db;
  late ReceiptRepository repo;
  late List<int> cats;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReceiptRepository(db);
    cats = (await db.select(db.categories).get()).map((c) => c.id).toList();
  });

  tearDown(() => db.close());

  Future<void> add(String merchant, DateTime when, int sen, int categoryId) =>
      repo.save(
        ReceiptDraft(
          merchant: merchant,
          purchasedAt: when,
          total: Money(sen),
          categoryId: categoryId,
          rawText: '',
          source: ReceiptSource.manual,
        ),
      );

  Future<MonthSummary> summarize(DateTime month, {int limit = 5}) async =>
      MonthSummary.from(
        await repo.watchAll().first,
        month,
        merchantLimit: limit,
      );

  final november = DateTime(2026, 11, 15);

  test('counts only receipts inside the selected month', () async {
    await add('Mydin', DateTime(2026, 11, 20, 13), 2175, cats[0]);
    await add('Cafe', DateTime(2026, 11, 2), 1000, cats[1]);
    await add('Last month', DateTime(2026, 10, 31, 23, 59), 9999, cats[0]);
    await add('Next month', DateTime(2026, 12, 1), 8888, cats[0]);

    final s = await summarize(november);

    expect(s.total, const Money(3175));
    expect(s.count, 2);
    expect(s.isEmpty, isFalse);
  });

  test('groups by category, largest first', () async {
    await add('A', DateTime(2026, 11, 3), 3000, cats[1]);
    await add('B', DateTime(2026, 11, 4), 1000, cats[0]);
    await add('C', DateTime(2026, 11, 5), 500, cats[0]);

    final s = await summarize(november);

    expect(s.byCategory.map((c) => c.categoryId), [cats[1], cats[0]]);
    expect(s.byCategory.map((c) => c.total), const [Money(3000), Money(1500)]);
  });

  test('merges merchants ignoring case and spaces, then ranks them', () async {
    await add('Mydin', DateTime(2026, 11, 3), 1000, cats[0]);
    await add('MYDIN ', DateTime(2026, 11, 4), 2000, cats[0]);
    await add('Cafe', DateTime(2026, 11, 5), 2500, cats[0]);
    await add('Kiosk', DateTime(2026, 11, 6), 100, cats[0]);

    final s = await summarize(november, limit: 2);

    expect(s.topMerchants, hasLength(2));
    expect(s.topMerchants.first.name.toLowerCase(), 'mydin');
    expect(s.topMerchants.first.total, const Money(3000));
    expect(s.topMerchants.first.count, 2);
    expect(s.topMerchants.last.name, 'Cafe');
  });

  test('puts each day in its own slot', () async {
    await add('A', DateTime(2026, 11, 20, 9), 1000, cats[0]);
    await add('B', DateTime(2026, 11, 20, 18), 500, cats[0]);
    await add('C', DateTime(2026, 11, 1), 250, cats[0]);

    final s = await summarize(november);

    expect(s.dailyTotals, hasLength(30));
    expect(s.dailyTotals[0], const Money(250));
    expect(s.dailyTotals[1], const Money.zero());
    expect(s.dailyTotals[19], const Money(1500));
  });

  test('an empty month has zeros and the right number of days', () async {
    final s = await summarize(november);

    expect(s.isEmpty, isTrue);
    expect(s.total, const Money.zero());
    expect(s.byCategory, isEmpty);
    expect(s.topMerchants, isEmpty);
    expect(s.dailyTotals, hasLength(30));
  });

  test('knows leap years', () {
    final s = MonthSummary.from(const <Receipt>[], DateTime(2028, 2));
    expect(s.dailyTotals, hasLength(29));
  });
}
