import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_lens/features/scan/presentation/receipt_providers.dart';

import '../../../core/database/app_database.dart';
import '../data/csv_exporter.dart';
import '../domain/receipt_filter.dart';

class ReceiptFilterNotifier extends Notifier<ReceiptFilter> {
  @override
  ReceiptFilter build() => const ReceiptFilter();

  void setQuery(String value) => state = state.copyWith(query: value);

  void setCategory(int? id) => state = state.copyWith(categoryId: id);

  void setRange(DateTime? from, DateTime? to) =>
      state = state.copyWith(from: from, to: to);

  void setNeedsReviewOnly(bool value) =>
      state = state.copyWith(needsReviewOnly: value);

  void setSort(ReceiptSort sort) => state = state.copyWith(sort: sort);

  /// Clears every filter but keeps the chosen sort order.
  void clear() => state = ReceiptFilter(sort: state.sort);
}

final receiptFilterProvider =
    NotifierProvider<ReceiptFilterNotifier, ReceiptFilter>(
      ReceiptFilterNotifier.new,
    );

final filteredReceiptsProvider = Provider<AsyncValue<List<Receipt>>>((ref) {
  final filter = ref.watch(receiptFilterProvider);
  return ref.watch(receiptsProvider).whenData(filter.apply);
});

final csvExporterProvider = Provider<CsvExporter>((ref) => CsvExporter());
