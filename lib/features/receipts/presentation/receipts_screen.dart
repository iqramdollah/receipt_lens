import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:receipt_lens/features/scan/presentation/receipt_detail_screen.dart';
import 'package:receipt_lens/features/scan/presentation/receipt_providers.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/money.dart';
import '../../../shared/category_icons.dart';
import '../domain/day_label.dart';
import '../domain/export_scope.dart';
import '../domain/receipt_csv.dart';
import '../domain/receipt_filter.dart';
import 'receipt_filter_providers.dart';

class ReceiptsScreen extends ConsumerStatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  ConsumerState<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

/// A day heading in the list, with that day's total.
class _Header {
  const _Header(this.label, this.total);

  final String label;
  final Money total;
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
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Export to CSV',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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

  /// Receipts with a day heading before each new day. Only date sorts are
  /// grouped; sorting by amount would scatter the days.
  static List<Object> _entries(
    List<Receipt> visible,
    ReceiptSort sort,
    DateTime now,
  ) {
    if (sort != ReceiptSort.newest && sort != ReceiptSort.oldest) {
      return visible;
    }

    final result = <Object>[];
    String? label;
    var total = 0;
    var headerIndex = -1;

    for (final r in visible) {
      final l = dayLabel(r.purchasedAt, now);
      if (l != label) {
        label = l;
        total = 0;
        headerIndex = result.length;
        result.add(_Header(l, const Money.zero()));
      }
      total += r.totalSen;
      result[headerIndex] = _Header(l, Money(total));
      result.add(r);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filter = ref.watch(receiptFilterProvider);
    final notifier = ref.read(receiptFilterProvider.notifier);
    final filtered = ref.watch(filteredReceiptsProvider);
    final categoryList =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final categories = {for (final c in categoryList) c.id: c};
    final shortDate = DateFormat('d MMM');
    final canExport =
        (ref.watch(receiptsProvider).value ?? const <Receipt>[]).isNotEmpty;

    Widget chip(Widget child) =>
        Padding(padding: const EdgeInsets.only(right: 8), child: child);

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );

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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
                filled: true,
                fillColor: scheme.surfaceContainerLowest,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: fieldBorder,
                enabledBorder: fieldBorder,
                focusedBorder: fieldBorder.copyWith(
                  borderSide: BorderSide(color: scheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
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
                  return _Empty(filtered: filter.isActive);
                }

                final entries = _entries(visible, filter.sort, DateTime.now());
                final sum = visible.fold<Money>(
                  const Money.zero(),
                  (a, r) => a + Money(r.totalSen),
                );

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Row(
                        children: [
                          Text(
                            '${visible.length} '
                            '${visible.length == 1 ? 'receipt' : 'receipts'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(sum.format(), style: theme.textTheme.titleSmall),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: entries.length,
                        itemBuilder: (context, i) {
                          final e = entries[i];
                          if (e is _Header) return _DayHeader(header: e);

                          final r = e as Receipt;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Dismissible(
                              key: ValueKey(r.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: scheme.onErrorContainer,
                                ),
                              ),
                              onDismissed: (_) => _delete(r),
                              child: _ReceiptTile(
                                receipt: r,
                                category: categories[r.categoryId],
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ReceiptDetailScreen(receiptId: r.id),
                                  ),
                                ),
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

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.header});

  final _Header header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 4),
      child: Row(
        children: [
          Text(
            header.label,
            style: theme.textTheme.titleSmall?.copyWith(color: muted),
          ),
          const Spacer(),
          Text(
            header.total.format(),
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({
    required this.receipt,
    required this.category,
    required this.onTap,
  });

  final Receipt receipt;
  final Category? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final base = category == null ? scheme.outline : Color(category!.color);
    // Dark category colours would nearly vanish on a dark card.
    final tone = isDark ? Color.lerp(base, Colors.white, 0.35)! : base;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: base.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(categoryIcon(category?.name), color: tone),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.merchant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category?.name ?? 'Uncategorized',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (receipt.needsReview) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 12,
                              color: scheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Needs review',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: scheme.onTertiaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                Money(receipt.totalSen).format(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                filtered ? Icons.search_off : Icons.receipt_long_outlined,
                size: 40,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              filtered ? 'No receipts match' : 'No receipts yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? 'Try a different search or clear the filters.'
                  : 'Scan your first receipt from the Scan tab.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
