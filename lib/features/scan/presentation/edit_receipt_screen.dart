import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/money.dart';
import 'receipt_providers.dart';

class EditReceiptScreen extends ConsumerStatefulWidget {
  const EditReceiptScreen({super.key, required this.receipt});

  final Receipt receipt;

  @override
  ConsumerState<EditReceiptScreen> createState() => _EditReceiptScreenState();
}

class _EditReceiptScreenState extends ConsumerState<EditReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchant;
  late final TextEditingController _total;
  late DateTime _date;
  late int _categoryId;
  bool _saving = false;

  /// 1650 sen -> "16.50" (integer maths, no floating point).
  static String _plain(int sen) =>
      '${sen ~/ 100}.${(sen % 100).toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final r = widget.receipt;
    _merchant = TextEditingController(text: r.merchant);
    _total = TextEditingController(text: _plain(r.totalSen));
    _date = r.purchasedAt;
    _categoryId = r.categoryId;
  }

  @override
  void dispose() {
    _merchant.dispose();
    _total.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(receiptRepositoryProvider)
          .updateDetails(
            widget.receipt.id,
            merchant: _merchant.text.trim(),
            purchasedAt: _date,
            total: Money.tryParse(_total.text)!,
            categoryId: _categoryId,
          );
      ref.invalidate(receiptDetailProvider(widget.receipt.id));
      messenger.showSnackBar(const SnackBar(content: Text('Receipt updated')));
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit receipt')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in list)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v!),
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
                : const Text('Save changes'),
          ),
        ),
      ),
    );
  }
}
