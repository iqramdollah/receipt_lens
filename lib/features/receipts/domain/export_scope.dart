import '../../../core/database/app_database.dart';
import 'receipt_filter.dart';

enum ExportScope { currentView, thisMonth, lastMonth, all }

/// Picks the receipts for an export, newest first (except [ExportScope.currentView],
/// which keeps the order the list is showing).
List<Receipt> selectForExport(
  ExportScope scope, {
  required List<Receipt> all,
  required List<Receipt> filtered,
  required DateTime now,
}) {
  List<Receipt> inMonth(DateTime m) => all
      .where(
        (r) => r.purchasedAt.year == m.year && r.purchasedAt.month == m.month,
      )
      .toList();

  return switch (scope) {
    ExportScope.currentView => filtered,
    ExportScope.thisMonth => const ReceiptFilter().apply(
      inMonth(DateTime(now.year, now.month)),
    ),
    // DateTime rolls month 0 back to December of the previous year.
    ExportScope.lastMonth => const ReceiptFilter().apply(
      inMonth(DateTime(now.year, now.month - 1)),
    ),
    ExportScope.all => const ReceiptFilter().apply(all),
  };
}
