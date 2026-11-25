import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_lens/features/receipts/data/image_store.dart';
import 'package:receipt_lens/features/receipts/data/receipt_repository.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(receiptRepositoryProvider).watchCategories(),
);

final receiptsProvider = StreamProvider<List<Receipt>>(
  (ref) => ref.watch(receiptRepositoryProvider).watchAll(),
);

final imageStoreProvider = Provider<ImageStore>((ref) => ImageStore());

final receiptDetailProvider = FutureProvider.autoDispose
    .family<ReceiptWithItems?, int>(
      (ref, id) => ref.watch(receiptRepositoryProvider).getById(id),
    );
