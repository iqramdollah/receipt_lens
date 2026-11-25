import 'package:receipt_lens/features/receipts/domain/receipt_source.dart';

import '../../../core/money.dart';

/// What the parser could extract from receipt text. Anything it could not
/// find is null, and [warnings] explains what the user should check.
class ParsedReceipt {
  const ParsedReceipt({
    this.merchant,
    this.purchasedAt,
    this.subtotal,
    this.tax,
    this.rounding,
    this.total,
    this.categoryName,
    this.items = const [],
    this.source = ReceiptSource.regex,
    this.warnings = const [],
  });

  final String? merchant;
  final DateTime? purchasedAt;
  final Money? subtotal;
  final Money? tax;
  final Money? rounding;
  final Money? total;
  final String? categoryName;
  final List<ParsedItem> items;
  final ReceiptSource source;
  final List<String> warnings;

  bool get isComplete =>
      merchant != null && purchasedAt != null && total != null;
}

class ParsedItem {
  const ParsedItem({
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
