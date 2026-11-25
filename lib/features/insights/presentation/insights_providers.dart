import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_lens/features/scan/presentation/receipt_providers.dart';

import '../domain/month_summary.dart';

class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void previous() => state = DateTime(state.year, state.month - 1);

  void next() => state = DateTime(state.year, state.month + 1);
}

final selectedMonthProvider = NotifierProvider<SelectedMonth, DateTime>(
  SelectedMonth.new,
);

/// Recomputes whenever a receipt is saved, edited or deleted.
final monthSummaryProvider = Provider<AsyncValue<MonthSummary>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref
      .watch(receiptsProvider)
      .whenData((all) => MonthSummary.from(all, month));
});
