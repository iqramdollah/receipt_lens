import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:receipt_lens/features/scan/presentation/receipt_detail_screen.dart';
import 'package:receipt_lens/features/scan/presentation/receipt_providers.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/money.dart';
import '../domain/export_scope.dart';
import '../domain/receipt_csv.dart';
import '../domain/receipt_filter.dart';

import 'receipt_filter_providers.dart';

class ReceiptsScreen extends ConsumerStatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  ConsumerState<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends ConsumerState<ReceiptsScreen> {
  // Dismissible must leave the tree in the same frame it is dismissed, but
  // the database stream updates a moment later. Hiding the id locally
  // bridges that gap.
  final _hiddenIds = <int>{};
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _delete(Receipt receipt) async {
    final repo = ref.read(receiptRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _hiddenIds.add(receipt.id));
    final deleted = await repo.getById(receipt.id);
    await repo.delete(receipt.id);

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted ${receipt.merchant}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              if (deleted != null) await repo.restore(deleted);
              if (mounted) setState(() => _hiddenIds.remove(receipt.id));
            },
          ),
        ),
      );
  }

  Future<void> _pickRange() async {
    final filter = ref.read(receiptFilterProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3)),
      initialDateRange: (filter.from != null && filter.to != null)
          ? DateTimeRange(start: filter.from!, end: filter.to!)
          : null,
    );
    if (picked != null) {
      ref
          .read(receiptFilterProvider.notifier)
          .setRange(picked.start, picked.end);
    }
  }

  void _clearFilters() {
    _search.clear();
    ref.read(receiptFilterProvider.notifier).clear();
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final all = ref.read(receiptsProvider).value ?? const <Receipt>[];
    final filtered =
        ref.read(filteredReceiptsProvider).value ?? const <Receipt>[];
    final filter = ref.read(receiptFilterProvider);
    final now = DateTime.now();

    List<Receipt> pick(ExportScope s) =>
        selectForExport(s, all: all, filtered: filtered, now: now);

    final monthFormat = DateFormat('MMMM yyyy');
    final options = <(ExportScope, String, String)>[
      (
        ExportScope.currentView,
        'What I see now',
        filter.isActive
            ? 'Matches your search and filters'
            : 'Every receipt, in the current order',
      ),
      (ExportScope.thisMonth, monthFormat.format(now), 'This month'),
      (
        ExportScope.lastMonth,
        monthFormat.format(DateTime(now.year, now.month - 1)),
        'Last month',
      ),
      (ExportScope.all, 'Everything', 'Every saved receipt'),
    ];

    final scope = await showModalBottomSheet<ExportScope>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Export to CSV',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            for (final (s, title, subtitle) in options)
              Builder(
                builder: (_) {
                  final count = pick(s).length;
                  return ListTile(
                    enabled: count > 0,
                    title: Text(title),
                    subtitle: Text(
                      '$subtitle · $count ${count == 1 ? 'receipt' : 'receipts'}',
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(s),
                  );
                },
              ),
          ],
        ),
      ),
    );
    if (scope == null) return;

    final receipts = pick(scope);
    if (receipts.isEmpty) return;

    final names = {
      for (final c in ref.read(categoriesProvider).value ?? const <Category>[])
        c.id: c.name,
    };

    try {
      final csv = receiptsToCsv(receipts, categoryNames: names);
      final file = await ref.read(csvExporterProvider).write(csv);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'ReceiptLens export',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not export: $e')));
    }
  }

  static String _sortLabel(ReceiptSort s) => switch (s) {
    ReceiptSort.newest => 'Newest first',
    ReceiptSort.oldest => 'Oldest first',
    ReceiptSort.highest => 'Highest amount',
    ReceiptSort.lowest => 'Lowest amount',
  };

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(receiptFilterProvider);
    final notifier = ref.read(receiptFilterProvider.notifier);
    final filtered = ref.watch(filteredReceiptsProvider);
    final categoryList =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final categories = {for (final c in categoryList) c.id: c};
    final dateFormat = DateFormat('d MMM yyyy');
    final shortDate = DateFormat('d MMM');
    final canExport =
        (ref.watch(receiptsProvider).value ?? const <Receipt>[]).isNotEmpty;

    Widget chip(Widget child) =>
        Padding(padding: const EdgeInsets.only(right: 8), child: child);

    final rangeLabel = (filter.from != null && filter.to != null)
        ? '${shortDate.format(filter.from!)} – ${shortDate.format(filter.to!)}'
        : 'Any date';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
        actions: [
          PopupMenuButton<ReceiptSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: filter.sort,
            onSelected: notifier.setSort,
            itemBuilder: (_) => [
              for (final s in ReceiptSort.values)
                PopupMenuItem(value: s, child: Text(_sortLabel(s))),
            ],
          ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.ios_share),
            onPressed: canExport ? _export : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: notifier.setQuery,
              decoration: InputDecoration(
                hintText: 'Search merchant or text',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: filter.isActive
                    ? IconButton(
                        tooltip: 'Clear search and filters',
                        icon: const Icon(Icons.close),
                        onPressed: _clearFilters,
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                chip(
                  FilterChip(
                    label: const Text('Needs review'),
                    selected: filter.needsReviewOnly,
                    onSelected: notifier.setNeedsReviewOnly,
                  ),
                ),
                chip(
                  InputChip(
                    avatar: const Icon(Icons.date_range, size: 18),
                    label: Text(rangeLabel),
                    selected: filter.hasDates,
                    onPressed: _pickRange,
                    onDeleted: filter.hasDates
                        ? () => notifier.setRange(null, null)
                        : null,
                  ),
                ),
                for (final c in categoryList)
                  chip(
                    FilterChip(
                      label: Text(c.name),
                      selected: filter.categoryId == c.id,
                      onSelected: (on) =>
                          notifier.setCategory(on ? c.id : null),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filtered.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Could not load receipts:\n$e')),
              data: (all) {
                final visible = all
                    .where((r) => !_hiddenIds.contains(r.id))
                    .toList();

                if (visible.isEmpty) {
                  return Center(
                    child: filter.isActive
                        ? const Text(
                            'No receipts match your filters.',
                            textAlign: TextAlign.center,
                          )
                        : const Text(
                            'No receipts yet.\nScan one to get started.',
                            textAlign: TextAlign.center,
                          ),
                  );
                }

                final sum = visible.fold<Money>(
                  const Money.zero(),
                  (a, r) => a + Money(r.totalSen),
                );

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            '${visible.length} '
                            '${visible.length == 1 ? 'receipt' : 'receipts'}',
                          ),
                          const Spacer(),
                          Text(
                            sum.format(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = visible[i];
                          final category = categories[r.categoryId];

                          return Dismissible(
                            key: ValueKey(r.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: const Icon(Icons.delete),
                            ),
                            onDismissed: (_) => _delete(r),
                            child: ListTile(
                              isThreeLine: r.needsReview,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      ReceiptDetailScreen(receiptId: r.id),
                                ),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: category == null
                                    ? null
                                    : Color(category.color),
                                child: const Icon(
                                  Icons.receipt_long,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(r.merchant),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${dateFormat.format(r.purchasedAt)} · '
                                    '${category?.name ?? 'Uncategorized'}',
                                  ),
                                  if (r.needsReview)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 14,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Needs review',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              trailing: Text(
                                Money(r.totalSen).format(),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
