import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/money.dart';
import '../../insights/presentation/insights_providers.dart';
import '../data/budget_repository.dart';
import '../domain/budget_status.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(appDatabaseProvider)),
);

final budgetLimitsProvider = StreamProvider<Map<int, Money>>(
  (ref) => ref
      .watch(budgetRepositoryProvider)
      .watchAll()
      .map((rows) => {for (final b in rows) b.categoryId: Money(b.limitSen)}),
);

/// Statuses for the month selected on the dashboard.
final budgetStatusesProvider = Provider<AsyncValue<List<BudgetStatus>>>((ref) {
  final summary = ref.watch(monthSummaryProvider);
  final limits = ref.watch(budgetLimitsProvider);

  final error = summary.error ?? limits.error;
  if (error != null) return AsyncError(error, StackTrace.current);

  final s = summary.value;
  final l = limits.value;
  if (s == null || l == null) return const AsyncLoading();

  return AsyncData(budgetStatuses(limits: l, summary: s));
});
