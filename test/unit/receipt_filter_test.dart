import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_lens/core/database/app_database.dart';
import 'package:receipt_lens/core/money.dart';
import 'package:receipt_lens/features/receipts/data/receipt_repository.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_draft.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_filter.dart';
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

  Future<void> add(
    String merchant,
    DateTime when,
    int sen,
    int categoryId, {
    String raw = '',
    bool review = false,
  }) => repo.save(
    ReceiptDraft(
      merchant: merchant,
      purchasedAt: when,
      total: Money(sen),
      categoryId: categoryId,
      rawText: raw,
      source: ReceiptSource.manual,
      needsReview: review,
    ),
  );

  Future<List<String>> merchants(ReceiptFilter f) async {
    final all = await repo.watchAll().first;
    return f.apply(all).map((r) => r.merchant).toList();
  }

  final nov = DateTime(2026, 11, 10);

  group('search', () {
    test('matches the merchant, ignoring case', () async {
      await add('Mydin', nov, 1000, cats[0]);
      await add('Cafe Ali', nov, 500, cats[0]);

      expect(await merchants(const ReceiptFilter(query: 'MYD')), ['Mydin']);
    });

    test('also matches the recognized text, which holds the items', () async {
      await add('Kedai Ah Huat', nov, 1000, cats[0], raw: 'NASI LEMAK 2 17.00');
      await add('Cafe', nov, 500, cats[0], raw: 'TEH TARIK');

      expect(await merchants(const ReceiptFilter(query: 'nasi lemak')), [
        'Kedai Ah Huat',
      ]);
    });

    test('a blank query matches everything', () async {
      await add('A', nov, 100, cats[0]);
      await add('B', nov, 200, cats[0]);

      expect(await merchants(const ReceiptFilter(query: '   ')), hasLength(2));
    });
  });

  group('filters', () {
    test('by category', () async {
      await add('A', nov, 100, cats[0]);
      await add('B', nov, 200, cats[1]);

      expect(await merchants(ReceiptFilter(categoryId: cats[1])), ['B']);
    });

    test('needs review only', () async {
      await add('Fine', nov, 100, cats[0]);
      await add('Check me', nov, 200, cats[0], review: true);

      expect(await merchants(const ReceiptFilter(needsReviewOnly: true)), [
        'Check me',
      ]);
    });

    test(
      'date range includes the whole last day and nothing after it',
      () async {
        await add('Before', DateTime(2026, 11, 19, 23, 59), 100, cats[0]);
        await add('Morning', DateTime(2026, 11, 20, 8), 100, cats[0]);
        await add('Night', DateTime(2026, 11, 20, 23, 59), 100, cats[0]);
        await add('After', DateTime(2026, 11, 21), 100, cats[0]);

        final result = await merchants(
          ReceiptFilter(
            from: DateTime(2026, 11, 20, 15),
            to: DateTime(2026, 11, 20),
          ),
        );

        expect(result.toSet(), {'Morning', 'Night'});
      },
    );

    test('filters combine', () async {
      await add('Mydin', nov, 100, cats[0]);
      await add('Mydin Express', nov, 100, cats[1]);
      await add('Cafe', nov, 100, cats[1]);

      expect(
        await merchants(ReceiptFilter(query: 'mydin', categoryId: cats[1])),
        ['Mydin Express'],
      );
    });
  });

  group('sorting', () {
    setUp(() async {
      await add('A', DateTime(2026, 11, 1), 3000, cats[0]);
      await add('B', DateTime(2026, 11, 2), 1000, cats[0]);
      await add('C', DateTime(2026, 11, 3), 2000, cats[0]);
    });

    test('newest and oldest', () async {
      expect(await merchants(const ReceiptFilter()), ['C', 'B', 'A']);
      expect(await merchants(const ReceiptFilter(sort: ReceiptSort.oldest)), [
        'A',
        'B',
        'C',
      ]);
    });

    test('highest and lowest amount', () async {
      expect(await merchants(const ReceiptFilter(sort: ReceiptSort.highest)), [
        'A',
        'C',
        'B',
      ]);
      expect(await merchants(const ReceiptFilter(sort: ReceiptSort.lowest)), [
        'B',
        'C',
        'A',
      ]);
    });
  });

  group('state', () {
    test('isActive ignores sorting but sees every real filter', () {
      expect(const ReceiptFilter().isActive, isFalse);
      expect(const ReceiptFilter(sort: ReceiptSort.highest).isActive, isFalse);
      expect(const ReceiptFilter(query: 'x').isActive, isTrue);
      expect(const ReceiptFilter(categoryId: 1).isActive, isTrue);
      expect(const ReceiptFilter(needsReviewOnly: true).isActive, isTrue);
      expect(
        ReceiptFilter(from: DateTime(2026), to: DateTime(2026)).isActive,
        isTrue,
      );
    });

    test('copyWith can clear nullable fields', () {
      final f = ReceiptFilter(
        categoryId: 3,
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 2),
      );

      final cleared = f.copyWith(categoryId: null, from: null, to: null);

      expect(cleared.categoryId, isNull);
      expect(cleared.from, isNull);
      expect(cleared.to, isNull);
      expect(f.copyWith(query: 'x').categoryId, 3);
    });
  });
}
