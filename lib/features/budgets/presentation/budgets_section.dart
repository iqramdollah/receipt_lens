import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:receipt_lens/features/scan/presentation/receipt_providers.dart';

import '../../../core/database/app_database.dart';
import '../domain/budget_status.dart';
import 'budget_providers.dart';
import 'budgets_screen.dart';

/// The budget progress card on the dashboard.
class BudgetsSection extends ConsumerWidget {
  const BudgetsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(budgetStatusesProvider).value;
    if (statuses == null) return const SizedBox.shrink();

    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };

    void openBudgets() => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const BudgetsScreen()));

    if (statuses.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.savings_outlined),
          title: const Text('Monthly budgets'),
          subtitle: const Text('Set a limit per category and track it here.'),
          trailing: TextButton(
            onPressed: openBudgets,
            child: const Text('Set up'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Budgets',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(onPressed: openBudgets, child: const Text('Edit')),
              ],
            ),
            for (final s in statuses)
              _BudgetRow(
                status: s,
                name: categories[s.categoryId]?.name ?? 'Uncategorized',
              ),
          ],
        ),
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.status, required this.name});

  final BudgetStatus status;
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final over = status.level == BudgetLevel.over;
    final color = switch (status.level) {
      BudgetLevel.ok => scheme.primary,
      BudgetLevel.warning => Colors.orange,
      BudgetLevel.over => scheme.error,
    };
    final note = over
        ? '${(-status.remaining).format()} over budget'
        : '${status.remaining.format()} left';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name)),
              Text(
                '${status.spent.format()} of ${status.limit.format()}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: status.fraction > 1 ? 1.0 : status.fraction,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: TextStyle(fontSize: 12, color: over ? scheme.error : null),
          ),
        ],
      ),
    );
  }
}
