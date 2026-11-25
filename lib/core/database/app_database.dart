import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/receipts/domain/receipt_source.dart';

part 'app_database.g.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get color => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

@TableIndex(name: 'receipts_purchased_at', columns: {#purchasedAt})
@TableIndex(name: 'receipts_category_id', columns: {#categoryId})
class Receipts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get merchant => text()();
  DateTimeColumn get purchasedAt => dateTime()();
  TextColumn get currency => text().withDefault(const Constant('MYR'))();
  IntColumn get subtotalSen => integer().nullable()();
  IntColumn get taxSen => integer().nullable()();
  IntColumn get roundingSen => integer().withDefault(const Constant(0))();
  IntColumn get totalSen => integer()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get imagePath => text().nullable()();
  TextColumn get rawText => text()();
  TextColumn get source => textEnum<ReceiptSource>()();
  BoolColumn get needsReview => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class ReceiptItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get receiptId =>
      integer().references(Receipts, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  IntColumn get unitPriceSen => integer().nullable()();
  IntColumn get lineTotalSen => integer()();
}

/// One monthly spending limit per category (applies to every month).
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer()
      .references(Categories, #id, onDelete: KeyAction.cascade)
      .unique()();
  IntColumn get limitSen => integer()();
}

@DriftDatabase(tables: [Categories, Receipts, ReceiptItems, Budgets])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'receipt_lens'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedCategories();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(budgets);
    },
    beforeOpen: (details) async {
      // SQLite ignores foreign keys unless this is switched on.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seedCategories() async {
    const defaults = <(String, int)>[
      ('Food', 0xFFEF6C00),
      ('Groceries', 0xFF2E7D32),
      ('Transport', 0xFF1565C0),
      ('Shopping', 0xFF8E24AA),
      ('Bills', 0xFF00838F),
      ('Health', 0xFFD81B60),
      ('Entertainment', 0xFFF9A825),
      ('Other', 0xFF757575),
    ];
    await batch((b) {
      b.insertAll(categories, [
        for (final (name, color) in defaults)
          CategoriesCompanion.insert(
            name: name,
            color: color,
            isDefault: const Value(true),
          ),
      ]);
    });
  }
}
