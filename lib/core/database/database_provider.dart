import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/receipts/data/receipt_repository.dart';
import 'app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final receiptRepositoryProvider = Provider<ReceiptRepository>(
  (ref) => ReceiptRepository(ref.watch(appDatabaseProvider)),
);
