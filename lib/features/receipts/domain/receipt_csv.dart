import '../../../core/database/app_database.dart';

const _header = [
  'Date',
  'Merchant',
  'Category',
  'Subtotal',
  'Tax',
  'Rounding',
  'Total',
  'Currency',
  'Source',
  'Needs review',
];

/// Builds a CSV (RFC 4180 style, CRLF line endings) from saved receipts.
String receiptsToCsv(
  Iterable<Receipt> receipts, {
  required Map<int, String> categoryNames,
}) {
  final rows = <List<String>>[
    _header,
    for (final r in receipts)
      [
        _dateTime(r.purchasedAt),
        _text(r.merchant),
        _text(categoryNames[r.categoryId] ?? 'Uncategorized'),
        _amount(r.subtotalSen),
        _amount(r.taxSen),
        _amount(r.roundingSen),
        _amount(r.totalSen),
        _text(r.currency),
        r.source.name,
        r.needsReview ? 'yes' : 'no',
      ],
  ];
  return '${rows.map((row) => row.map(_quote).join(',')).join('\r\n')}\r\n';
}

String _two(int v) => v.toString().padLeft(2, '0');

String _dateTime(DateTime d) =>
    '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

/// 1650 sen -> "16.50" (integer maths). Null stays an empty cell.
String _amount(int? sen) {
  if (sen == null) return '';
  final abs = sen.abs();
  final text = '${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  return sen < 0 ? '-$text' : text;
}

/// Stops spreadsheets from running text such as "=HYPERLINK(...)" as a formula.
String _text(String v) => v.isNotEmpty && '=+-@\t\r'.contains(v[0]) ? "'$v" : v;

String _quote(String v) {
  final needsQuotes =
      v.contains(',') ||
      v.contains('"') ||
      v.contains('\n') ||
      v.contains('\r');
  return needsQuotes ? '"${v.replaceAll('"', '""')}"' : v;
}
