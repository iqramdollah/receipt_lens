import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:receipt_lens/features/scan/presentation/receipt_providers.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money.dart';
import 'budget_providers.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Category category,
    Money? current,
  ) async {
    final result = await showDialog<_DialogResult>(
      context: context,
      builder: (_) => _BudgetDialog(category: category, current: current),
    );
    if (result == null) return;

    final repo = ref.read(budgetRepositoryProvider);
    if (result.remove) {
      await repo.clear(category.id);
    } else {
      await repo.setLimit(category.id, result.limit!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final limits =
        ref.watch(budgetLimitsProvider).value ?? const <int, Money>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly budgets')),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load categories:\n$e')),
        data: (list) => ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'A limit applies to every month. '
                'Tap a category to set or change it.',
              ),
            ),
            for (final c in list)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(c.color),
                  child: const Icon(
                    Icons.savings_outlined,
                    color: Colors.white,
                  ),
                ),
                title: Text(c.name),
                subtitle: Text(
                  limits[c.id] == null
                      ? 'No limit'
                      : '${limits[c.id]!.format()} per month',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _edit(context, ref, c, limits[c.id]),
              ),
          ],
        ),
      ),
    );
  }
}

class _DialogResult {
  const _DialogResult.save(this.limit) : remove = false;

  const _DialogResult.remove() : limit = null, remove = true;

  final Money? limit;
  final bool remove;
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.category, required this.current});

  final Category category;
  final Money? current;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _controller = TextEditingController(
      text: c == null
          ? ''
          : '${c.sen ~/ 100}.${(c.sen % 100).toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final m = Money.tryParse(_controller.text);
    if (m == null || m.sen <= 0) {
      setState(() => _error = 'Enter an amount above 0, e.g. 500');
      return;
    }
    Navigator.of(context).pop(_DialogResult.save(m));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.category.name} budget'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Monthly limit',
          prefixText: 'RM ',
          errorText: _error,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _DialogResult.remove()),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
