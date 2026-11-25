import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money.dart';

class BudgetRepository {
  BudgetRepository(this._db);

  final AppDatabase _db;

  Stream<List<Budget>> watchAll() => _db.select(_db.budgets).watch();

  /// Creates or replaces the limit for [categoryId].
  Future<void> setLimit(int categoryId, Money limit) {
    return _db.transaction(() async {
      final updated =
          await (_db.update(_db.budgets)
                ..where((b) => b.categoryId.equals(categoryId)))
              .write(BudgetsCompanion(limitSen: Value(limit.sen)));

      if (updated == 0) {
        await _db
            .into(_db.budgets)
            .insert(
              BudgetsCompanion.insert(
                categoryId: categoryId,
                limitSen: limit.sen,
              ),
            );
      }
    });
  }

  Future<void> clear(int categoryId) {
    return (_db.delete(
      _db.budgets,
    )..where((b) => b.categoryId.equals(categoryId))).go();
  }
}
