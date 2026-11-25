import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_lens/core/money.dart';
import 'package:receipt_lens/features/budgets/domain/budget_status.dart';
import 'package:receipt_lens/features/insights/domain/month_summary.dart';

MonthSummary _summary(Map<int, int> spentByCategory) => MonthSummary(
  month: DateTime(2026, 11),
  total: Money(spentByCategory.values.fold(0, (a, b) => a + b)),
  count: spentByCategory.length,
  byCategory: [
    for (final e in spentByCategory.entries)
      CategoryTotal(categoryId: e.key, total: Money(e.value)),
  ],
  topMerchants: const [],
  dailyTotals: const [],
);

BudgetStatus _status(int limit, int spent) =>
    BudgetStatus(categoryId: 1, limit: Money(limit), spent: Money(spent));

void main() {
  group('BudgetStatus', () {
    test('is ok below 80 percent', () {
      expect(_status(10000, 7999).level, BudgetLevel.ok);
    });

    test('warns from exactly 80 percent', () {
      expect(_status(10000, 8000).level, BudgetLevel.warning);
    });

    test('spending exactly the limit is a warning, not over', () {
      expect(_status(10000, 10000).level, BudgetLevel.warning);
    });

    test('is over only above the limit, and remaining goes negative', () {
      final s = _status(10000, 10001);

      expect(s.level, BudgetLevel.over);
      expect(s.remaining, const Money(-1));
    });

    test('fraction is spent over limit and can pass 1', () {
      expect(_status(10000, 2500).fraction, 0.25);
      expect(_status(10000, 15000).fraction, 1.5);
    });
  });

  group('budgetStatuses', () {
    test(
      'takes spending from the summary and ignores categories without a limit',
      () {
        final result = budgetStatuses(
          limits: {1: const Money(50000)},
          summary: _summary({1: 12000, 2: 99999}),
        );

        expect(result, hasLength(1));
        expect(result.single.categoryId, 1);
        expect(result.single.spent, const Money(12000));
        expect(result.single.remaining, const Money(38000));
      },
    );

    test('a category with a limit but no spending shows zero spent', () {
      final result = budgetStatuses(
        limits: {3: const Money(20000)},
        summary: _summary({1: 500}),
      );

      expect(result.single.spent, const Money.zero());
      expect(result.single.level, BudgetLevel.ok);
    });

    test('puts the most pressing category first', () {
      final result = budgetStatuses(
        limits: {
          1: const Money(10000),
          2: const Money(10000),
          3: const Money(10000),
        },
        summary: _summary({1: 2000, 2: 12000, 3: 8000}),
      );

      expect(result.map((s) => s.categoryId), [2, 3, 1]);
    });

    test('no limits means no statuses', () {
      expect(
        budgetStatuses(limits: const {}, summary: _summary({1: 100})),
        isEmpty,
      );
    });
  });
}
