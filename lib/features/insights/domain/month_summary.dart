import '../../../core/database/app_database.dart';
import '../../../core/money.dart';

class CategoryTotal {
  const CategoryTotal({required this.categoryId, required this.total});

  final int categoryId;
  final Money total;
}

class MerchantTotal {
  const MerchantTotal({
    required this.name,
    required this.total,
    required this.count,
  });

  final String name;
  final Money total;
  final int count;
}

class _MerchantAcc {
  _MerchantAcc(this.name);

  final String name;
  int sen = 0;
  int count = 0;
}

/// Spending for one calendar month, computed from saved receipts.
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.total,
    required this.count,
    required this.byCategory,
    required this.topMerchants,
    required this.dailyTotals,
  });

  /// First day of the month.
  final DateTime month;
  final Money total;
  final int count;

  /// Largest first.
  final List<CategoryTotal> byCategory;
  final List<MerchantTotal> topMerchants;

  /// Index 0 is day 1 of the month.
  final List<Money> dailyTotals;

  bool get isEmpty => count == 0;

  static MonthSummary from(
    Iterable<Receipt> receipts,
    DateTime month, {
    int merchantLimit = 5,
  }) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final daily = List<int>.filled(daysInMonth, 0);
    final byCategory = <int, int>{};
    final byMerchant = <String, _MerchantAcc>{};
    var total = 0;
    var count = 0;

    for (final r in receipts) {
      final d = r.purchasedAt;
      if (d.year != first.year || d.month != first.month) continue;

      total += r.totalSen;
      count++;
      daily[d.day - 1] += r.totalSen;
      byCategory[r.categoryId] = (byCategory[r.categoryId] ?? 0) + r.totalSen;

      final name = r.merchant.trim();
      final acc = byMerchant.putIfAbsent(
        name.toLowerCase(),
        () => _MerchantAcc(name),
      );
      acc.sen += r.totalSen;
      acc.count++;
    }

    final categories =
        [
          for (final e in byCategory.entries)
            CategoryTotal(categoryId: e.key, total: Money(e.value)),
        ]..sort((a, b) {
          final c = b.total.compareTo(a.total);
          return c != 0 ? c : a.categoryId.compareTo(b.categoryId);
        });

    final merchants =
        [
          for (final m in byMerchant.values)
            MerchantTotal(name: m.name, total: Money(m.sen), count: m.count),
        ]..sort((a, b) {
          final c = b.total.compareTo(a.total);
          return c != 0 ? c : a.name.compareTo(b.name);
        });

    return MonthSummary(
      month: first,
      total: Money(total),
      count: count,
      byCategory: categories,
      topMerchants: merchants.take(merchantLimit).toList(),
      dailyTotals: [for (final sen in daily) Money(sen)],
    );
  }
}
