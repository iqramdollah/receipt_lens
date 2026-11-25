import '../domain/parsed_receipt.dart';
import '../domain/receipt_parser.dart';
import 'regex_receipt_parser.dart';

/// Tries the AI parser first. If it fails, the offline regex parser answers
/// instead, with a warning so the user knows to double-check the fields.
class FallbackReceiptParser implements ReceiptParser {
  const FallbackReceiptParser({
    required this.primary,
    this.fallback = const RegexReceiptParser(),
  });

  final ReceiptParser primary;
  final RegexReceiptParser fallback;

  @override
  Future<ParsedReceipt> parse(String ocrText) async {
    try {
      return await primary.parse(ocrText);
    } on ParseException catch (e) {
      final r = fallback.parse(ocrText);
      return ParsedReceipt(
        merchant: r.merchant,
        purchasedAt: r.purchasedAt,
        subtotal: r.subtotal,
        tax: r.tax,
        rounding: r.rounding,
        total: r.total,
        warnings: [
          'AI parsing unavailable (${e.message}); used the offline parser',
          ...r.warnings,
        ],
      );
    }
  }
}
