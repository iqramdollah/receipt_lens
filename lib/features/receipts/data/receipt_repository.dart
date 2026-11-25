import 'package:drift/drift.dart';
import 'package:receipt_lens/core/money.dart';

import '../../../core/database/app_database.dart';
import '../domain/receipt_draft.dart';

class ReceiptWithItems {
  const ReceiptWithItems(this.receipt, this.items);

  final Receipt receipt;
  final List<ReceiptItem> items;
}

class ReceiptRepository {
  ReceiptRepository(this._db);

  final AppDatabase _db;

  /// Saves a receipt and its items in a single transaction.
  /// Returns the new receipt id.
  Future<int> save(ReceiptDraft draft) {
    return _db.transaction(() async {
      final id = await _db
          .into(_db.receipts)
          .insert(
            ReceiptsCompanion.insert(
              merchant: draft.merchant,
              purchasedAt: draft.purchasedAt,
              totalSen: draft.total.sen,
              categoryId: draft.categoryId,
              rawText: draft.rawText,
              source: draft.source,
              currency: Value(draft.currency),
              subtotalSen: Value(draft.subtotal?.sen),
              taxSen: Value(draft.tax?.sen),
              roundingSen: Value(draft.rounding.sen),
              imagePath: Value(draft.imagePath),
              needsReview: Value(draft.needsReview),
            ),
          );

      await _db.batch((b) {
        b.insertAll(_db.receiptItems, [
          for (final item in draft.items)
            ReceiptItemsCompanion.insert(
              receiptId: id,
              name: item.name,
              lineTotalSen: item.lineTotal.sen,
              quantity: Value(item.quantity),
              unitPriceSen: Value(item.unitPrice?.sen),
            ),
        ]);
      });

      return id;
    });
  }

  Stream<List<Receipt>> watchAll() {
    final query = _db.select(_db.receipts)
      ..orderBy([(t) => OrderingTerm.desc(t.purchasedAt)]);
    return query.watch();
  }

  Future<ReceiptWithItems?> getById(int id) async {
    final receipt = await (_db.select(
      _db.receipts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (receipt == null) return null;

    final items = await (_db.select(
      _db.receiptItems,
    )..where((t) => t.receiptId.equals(id))).get();
    return ReceiptWithItems(receipt, items);
  }

  /// Applies a user's corrections. Clears the needs-review flag, and drops the
  /// parsed subtotal, tax and rounding if the total was changed (they would no
  /// longer add up).
  Future<void> updateDetails(
    int id, {
    required String merchant,
    required DateTime purchasedAt,
    required Money total,
    required int categoryId,
  }) async {
    final current = await (_db.select(
      _db.receipts,
    )..where((t) => t.id.equals(id))).getSingle();
    final totalChanged = current.totalSen != total.sen;

    await (_db.update(_db.receipts)..where((t) => t.id.equals(id))).write(
      ReceiptsCompanion(
        merchant: Value(merchant),
        purchasedAt: Value(purchasedAt),
        totalSen: Value(total.sen),
        categoryId: Value(categoryId),
        needsReview: const Value(false),
        subtotalSen: totalChanged
            ? const Value<int?>(null)
            : const Value<int?>.absent(),
        taxSen: totalChanged
            ? const Value<int?>(null)
            : const Value<int?>.absent(),
        roundingSen: totalChanged ? const Value(0) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.receipts)..where((t) => t.id.equals(id))).go();
  }

  /// Re-inserts a previously deleted receipt and its items (used by "Undo").
  Future<void> restore(ReceiptWithItems deleted) {
    return _db.transaction(() async {
      await _db.into(_db.receipts).insert(deleted.receipt.toCompanion(true));
      await _db.batch((b) {
        b.insertAll(_db.receiptItems, [
          for (final item in deleted.items) item.toCompanion(true),
        ]);
      });
    });
  }

  Stream<List<Category>> watchCategories() {
    final query = _db.select(_db.categories)
      ..orderBy([(t) => OrderingTerm.asc(t.id)]);
    return query.watch();
  }
}
