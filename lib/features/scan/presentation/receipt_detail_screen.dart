import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:receipt_lens/features/receipts/data/receipt_repository.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_source.dart';
import 'package:receipt_lens/features/scan/presentation/edit_receipt_screen.dart';

import '../../../core/money.dart';

import 'receipt_providers.dart';

class ReceiptDetailScreen extends ConsumerWidget {
  const ReceiptDetailScreen({super.key, required this.receiptId});

  final int receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(receiptDetailProvider(receiptId));
    final categories = ref.watch(categoriesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          if (detail.value case final d?)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EditReceiptScreen(receipt: d.receipt),
                ),
              ),
            ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load receipt:\n$e')),
        data: (d) {
          if (d == null) return const Center(child: Text('Receipt not found'));
          return _Content(
            data: d,
            categoryName: categories
                .where((c) => c.id == d.receipt.categoryId)
                .map((c) => c.name)
                .firstOrNull,
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.data, required this.categoryName});

  final ReceiptWithItems data;
  final String? categoryName;

  static String _sourceLabel(ReceiptSource s) => switch (s) {
    ReceiptSource.llm => 'AI parsing',
    ReceiptSource.regex => 'Offline parser',
    ReceiptSource.manual => 'Entered manually',
  };

  @override
  Widget build(BuildContext context) {
    final r = data.receipt;
    final theme = Theme.of(context);
    final imageFile = r.imagePath == null ? null : File(r.imagePath!);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (imageFile != null && imageFile.existsSync())
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(imageFile, height: 220, fit: BoxFit.cover),
          ),
        const SizedBox(height: 16),
        Text(r.merchant, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(Money(r.totalSen).format(), style: theme.textTheme.headlineMedium),
        if (r.needsReview) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Some fields were not read with confidence. Check them against the photo.',
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _Row('Date', DateFormat('d MMM yyyy, h:mm a').format(r.purchasedAt)),
        _Row('Category', categoryName ?? 'Uncategorized'),
        if (r.subtotalSen != null)
          _Row('Subtotal', Money(r.subtotalSen!).format()),
        if (r.taxSen != null) _Row('Tax', Money(r.taxSen!).format()),
        if (r.roundingSen != 0) _Row('Rounding', Money(r.roundingSen).format()),
        _Row('Read by', _sourceLabel(r.source)),
        if (data.items.isNotEmpty) ...[
          const Divider(height: 32),
          Text('Items', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in data.items)
            _Row(
              '${item.name} × ${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}',
              Money(item.lineTotalSen).format(),
            ),
        ],
        ExpansionTile(
          title: const Text('Recognized text'),
          tilePadding: EdgeInsets.zero,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                r.rawText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
