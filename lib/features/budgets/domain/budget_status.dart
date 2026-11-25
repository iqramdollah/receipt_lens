import '../../../core/money.dart';
import '../../insights/domain/month_summary.dart';

enum BudgetLevel { ok, warning, over }

/// How one category is doing against its monthly limit.
class BudgetStatus {
  const BudgetStatus({
    required this.categoryId,
    required this.limit,
    required this.spent,
  });

  final int categoryId;
  final Money limit;
  final Money spent;

  /// Negative when over budget.
  Money get remaining => limit - spent;

  /// 1.0 means exactly on the limit; above 1.0 means over.
  double get fraction => limit.sen <= 0 ? 0 : spent.sen / limit.sen;

  /// Spending exactly equal to the limit is a warning, not "over".
  BudgetLevel get level {
    if (spent.sen > limit.sen) return BudgetLevel.over;
    // Integer maths: spent is at least 80% of the limit.
    if (spent.sen * 100 >= limit.sen * 80) return BudgetLevel.warning;
    return BudgetLevel.ok;
  }
}

/// One status per category that has a limit, most pressing first.
List<BudgetStatus> budgetStatuses({
  required Map<int, Money> limits,
  required MonthSummary summary,
}) {
  final spentBy = {for (final c in summary.byCategory) c.categoryId: c.total};

  final result = [
    for (final e in limits.entries)
      BudgetStatus(
        categoryId: e.key,
        limit: e.value,
        spent: spentBy[e.key] ?? const Money.zero(),
      ),
  ];

  result.sort((a, b) {
    final c = b.fraction.compareTo(a.fraction);
    return c != 0 ? c : a.categoryId.compareTo(b.categoryId);
  });
  return result;
}
