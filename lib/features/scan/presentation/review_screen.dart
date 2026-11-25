import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:receipt_lens/features/scan/presentation/receipt_providers.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/money.dart';
import '../../receipts/domain/receipt_draft.dart';
import '../../receipts/domain/receipt_source.dart';

import '../data/regex_receipt_parser.dart';
import '../domain/parsed_receipt.dart';
import 'parser_providers.dart';
import 'scan_controller.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.scan});

  final ScanResult scan;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merchant = TextEditingController();
  final _total = TextEditingController();
  DateTime _date = DateTime.now();
  int? _categoryId;
  bool _saving = false;

  ParsedReceipt? _parsed;
  String? _suggestedCategory;
  bool _parsing = true;

  @override
  void initState() {
    super.initState();
    _readReceipt();
  }

  @override
  void dispose() {
    _merchant.dispose();
    _total.dispose();
    super.dispose();
  }

  Future<void> _readReceipt() async {
    ParsedReceipt result;
    try {
      result = await ref.read(receiptParserProvider).parse(widget.scan.text);
    } on Object {
      result = const RegexReceiptParser().parse(widget.scan.text);
    }
    // The user may have left the screen or tapped "Fill in manually".
    if (!mounted || !_parsing) return;

    setState(() {
      _parsed = result;
      _suggestedCategory = result.categoryName;
      _merchant.text = result.merchant ?? '';
      _total.text = result.total == null ? '' : _formatAmount(result.total!);
      _date = result.purchasedAt ?? DateTime.now();
      _parsing = false;
    });
  }

  void _skip() => setState(() => _parsing = false);

  /// 1650 sen -> "16.50" (integer maths, no floating point).
  String _formatAmount(Money m) =>
      '${m.sen ~/ 100}.${(m.sen % 100).toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!
        .save(); // copies the dropdown choice into _categoryId
    setState(() => _saving = true);

    final parsed = _parsed;
    final images = ref.read(imageStoreProvider);
    String? storedImage;
    try {
      final total = Money.tryParse(_total.text)!;
      // If the user corrected the total, the parsed breakdown no longer fits.
      final keepParsed = parsed != null && parsed.total == total;
      storedImage = await images.persist(widget.scan.imagePath);

      await ref
          .read(receiptRepositoryProvider)
          .save(
            ReceiptDraft(
              merchant: _merchant.text.trim(),
              purchasedAt: _date,
              total: total,
              categoryId: _categoryId!,
              rawText: widget.scan.text,
              source: parsed?.source ?? ReceiptSource.manual,
              imagePath: storedImage,
              needsReview: parsed != null && parsed.warnings.isNotEmpty,
              subtotal: keepParsed ? parsed.subtotal : null,
              tax: keepParsed ? parsed.tax : null,
              rounding: keepParsed
                  ? (parsed.rounding ?? const Money.zero())
                  : const Money.zero(),
              items: [
                for (final i in parsed?.items ?? const <ParsedItem>[])
                  ReceiptItemDraft(
                    name: i.name,
                    quantity: i.quantity,
                    unitPrice: i.unitPrice,
                    lineTotal: i.lineTotal,
                  ),
              ],
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved ${total.format()}')));
      Navigator.of(context).pop();
    } catch (e) {
      await images.delete(storedImage);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_parsing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review receipt')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Reading receipt…'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _skip,
                child: const Text('Fill in manually'),
              ),
            ],
          ),
        ),
      );
    }

    final categories = ref.watch(categoriesProvider);
    final warnings = _parsed?.warnings ?? const <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Review receipt')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(widget.scan.imagePath),
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                key: const Key('warnings_banner'),
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Please check these fields:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      for (final w in warnings) Text('• $w'),
                    ],
                  ),
                ),
              ),
            ],
            ExpansionTile(
              title: const Text('Recognized text'),
              tilePadding: EdgeInsets.zero,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    widget.scan.text,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _merchant,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Merchant',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter the merchant' : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('d MMM yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _total,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Total',
                prefixText: 'RM ',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final m = Money.tryParse(v ?? '');
                if (m == null || m.sen <= 0) {
                  return 'Enter a valid amount, e.g. 16.50';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load categories: $e'),
              data: (list) => DropdownButtonFormField<int>(
                // Pre-select the category the parser suggested, if any.
                initialValue:
                    _categoryId ??
                    list
                        .where((c) => c.name == _suggestedCategory)
                        .map((c) => c.id)
                        .firstOrNull,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in list)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
                onSaved: (v) => _categoryId = v,
                validator: (v) => v == null ? 'Choose a category' : null,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save receipt'),
          ),
        ),
      ),
    );
  }
}
