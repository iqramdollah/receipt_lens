import 'parsed_receipt.dart';

abstract interface class ReceiptParser {
  Future<ParsedReceipt> parse(String ocrText);
}

/// Thrown when a parser could not produce a result (network, bad answer).
class ParseException implements Exception {
  const ParseException(this.message);

  final String message;

  @override
  String toString() => 'ParseException: $message';
}
