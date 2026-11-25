import '../../../core/money.dart';
import 'receipt_source.dart';

class ReceiptItemDraft {
  const ReceiptItemDraft({
    required this.name,
    required this.lineTotal,
    this.quantity = 1,
    this.unitPrice,
  });

  final String name;
  final double quantity;
  final Money? unitPrice;
  final Money lineTotal;
}

/// A receipt that has been parsed (or typed in) but not yet saved.
class ReceiptDraft {
  const ReceiptDraft({
    required this.merchant,
    required this.purchasedAt,
    required this.total,
    required this.categoryId,
    required this.rawText,
    required this.source,
    this.currency = 'MYR',
    this.subtotal,
    this.tax,
    this.rounding = const Money.zero(),
    this.imagePath,
    this.needsReview = false,
    this.items = const [],
  });

  final String merchant;
  final DateTime purchasedAt;
  final String currency;
  final Money? subtotal;
  final Money? tax;
  final Money rounding;
  final Money total;
  final int categoryId;
  final String? imagePath;
  final String rawText;
  final ReceiptSource source;
  final bool needsReview;
  final List<ReceiptItemDraft> items;
}
