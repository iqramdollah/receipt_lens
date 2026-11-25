import '../domain/parsed_receipt.dart';
import '../domain/receipt_parser.dart';
import 'regex_receipt_parser.dart';

/// Adapts the synchronous regex parser to the [ReceiptParser] interface.
class OfflineReceiptParser implements ReceiptParser {
  const OfflineReceiptParser([this._regex = const RegexReceiptParser()]);

  final RegexReceiptParser _regex;

  @override
  Future<ParsedReceipt> parse(String ocrText) async => _regex.parse(ocrText);
}
