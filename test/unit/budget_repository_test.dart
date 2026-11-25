import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_lens/core/database/app_database.dart';
import 'package:receipt_lens/core/money.dart';
import 'package:receipt_lens/features/budgets/data/budget_repository.dart';

void main() {
  late AppDatabase db;
  late BudgetRepository repo;
  late List<int> cats;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = BudgetRepository(db);
    cats = (await db.select(db.categories).get()).map((c) => c.id).toList();
  });

  tearDown(() => db.close());

  test('setLimit creates a budget', () async {
    await repo.setLimit(cats[0], const Money(50000));

    final rows = await repo.watchAll().first;
    expect(rows, hasLength(1));
    expect(rows.single.categoryId, cats[0]);
    expect(rows.single.limitSen, 50000);
  });

  test('setLimit twice replaces the value instead of adding a row', () async {
    await repo.setLimit(cats[0], const Money(50000));
    await repo.setLimit(cats[0], const Money(75000));

    final rows = await repo.watchAll().first;
    expect(rows, hasLength(1));
    expect(rows.single.limitSen, 75000);
  });

  test('categories keep separate limits', () async {
    await repo.setLimit(cats[0], const Money(1000));
    await repo.setLimit(cats[1], const Money(2000));

    final rows = await repo.watchAll().first;
    expect(
      {for (final r in rows) r.categoryId: r.limitSen},
      {cats[0]: 1000, cats[1]: 2000},
    );
  });

  test('clear removes only that category', () async {
    await repo.setLimit(cats[0], const Money(1000));
    await repo.setLimit(cats[1], const Money(2000));

    await repo.clear(cats[0]);

    final rows = await repo.watchAll().first;
    expect(rows.map((r) => r.categoryId), [cats[1]]);
  });

  test('deleting a category deletes its budget', () async {
    await repo.setLimit(cats[0], const Money(1000));

    await (db.delete(db.categories)..where((c) => c.id.equals(cats[0]))).go();

    expect(await repo.watchAll().first, isEmpty);
  });
}
