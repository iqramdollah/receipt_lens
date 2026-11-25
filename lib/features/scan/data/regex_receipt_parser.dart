import '../../../core/money.dart';
import '../domain/parsed_receipt.dart';

/// Offline fallback parser for Malaysian receipts (English and Bahasa Malaysia).
/// It never guesses: anything it cannot find stays null with a warning.
class RegexReceiptParser {
  const RegexReceiptParser();

  static const _maxTotal = Money(10000000); // RM 100,000

  // ---- amounts ----------------------------------------------------------

  // 12.50, 1,234.5, -0.02. Rejects date fragments (20.11.2026) and percentages (6.00%).
  static final _amount = RegExp(
    r'(?<![\d.,])-?(?:\d{1,3}(?:,\d{3})+|\d+)\.\d{1,2}(?!\d|\.\d|\s*%)',
  );

  // ---- labels -----------------------------------------------------------

  static final _totalStrong = RegExp(
    r'GRAND\s*TOTAL|TOTAL\s*(AMOUNT|DUE|PAYABLE|BAYARAN)|AMOUNT\s*(DUE|PAYABLE)'
    r'|NET\s*(TOTAL|AMOUNT)|JUMLAH\s*(KESELURUHAN|BAYARAN|BESAR)|BALANCE\s*DUE',
  );
  static final _totalWeak = RegExp(r'\bTOTAL\b|\bJUMLAH\b');
  static final _strongExclude = RegExp(r'EXCL|BEFORE');
  static final _weakExclude = RegExp(
    r'SUB\s*-?\s*TOTAL|JUMLAH\s*KECIL|EXCL|BEFORE'
    r'|TOTAL\s*(ITEM|QTY|SAVING|DISC|POINT)|ITEMS?\s*TOTAL'
    r'|TOTAL\s*(TAX|SST|GST|CUKAI)|(TAX|SST|GST|CUKAI)\s*TOTAL'
    r'|CHANGE|BAKI|CASH|TUNAI|TENDER|\bROUND(ING)?\b|DISCOUNT|DISKAUN',
  );

  static final _subtotalLabel = RegExp(r'SUB\s*-?\s*TOTAL|JUMLAH\s*KECIL');
  static final _taxLabel = RegExp(r'\b(SST|GST|TAX|CUKAI)\b');
  static final _taxExclude = RegExp(
    r'TAX\s*INVOICE|(SST|GST)\s*(NO|ID|REG)|INCL|EXCL|TOTAL',
  );
  static final _roundingLabel = RegExp(r'\bROUND(ING)?\b|PEMBULATAN');

  // ---- dates ------------------------------------------------------------

  static final _isoDate = RegExp(r'(?<!\d)(\d{4})-(\d{2})-(\d{2})(?!\d)');
  static final _numericDate4 = RegExp(
    r'(?<!\d)(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})(?!\d)',
  );
  static final _numericDate2 = RegExp(
    r'(?<![\d/\-.])(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2})(?![\d/\-.])',
  );
  static final _namedDate = RegExp(
    r'(?<!\d)(\d{1,2})[\s\-]*'
    r'(JAN|FEB|MAR|APR|MAY|MEI|JUN|JUL|AUG|OGO|SEP|OCT|OKT|NOV|DEC|DIS)'
    r'[A-Z]*\.?,?[\s\-]*(\d{4}|\d{2})(?!\d)',
    caseSensitive: false,
  );
  static final _time = RegExp(
    r'(?<![\d:])([01]?\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?\s*([AP]M)?',
    caseSensitive: false,
  );
  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'mei': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'ogo': 8,
    'sep': 9,
    'oct': 10,
    'okt': 10,
    'nov': 11,
    'dec': 12,
    'dis': 12,
  };

  // ---- merchant ---------------------------------------------------------

  static final _merchantNoise = RegExp(
    r'\b(TEL|TELP|PHONE|FAX|ADDRESS|ALAMAT|JALAN|JLN|LOT|RECEIPT|INVOICE|RESIT'
    r'|WELCOME|SELAMAT|THANK|GST|SST|REG|DATE|TARIKH)\b|WWW\.|@|HTTP|NO\.',
    caseSensitive: false,
  );

  // ---- public API -------------------------------------------------------

  ParsedReceipt parse(String text, {DateTime? now}) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final total = _findTotal(lines);
    final subtotal = _findLabelled(lines, _subtotalLabel);
    final tax = _findLabelled(lines, _taxLabel, exclude: _taxExclude);
    final rounding = _findLabelled(lines, _roundingLabel, allowNegative: true);
    final purchasedAt = _findDate(lines, now ?? DateTime.now());
    final merchant = _findMerchant(lines);

    final warnings = <String>[
      if (merchant == null) 'Merchant not found',
      if (purchasedAt == null) 'Date not found',
      if (total == null) 'Total not found',
    ];

    if (subtotal != null && total != null) {
      final expected =
          subtotal +
          (tax ?? const Money.zero()) +
          (rounding ?? const Money.zero());
      if ((expected - total).sen.abs() > 10) {
        warnings.add('Subtotal, tax and rounding do not add up to the total');
      }
    }

    return ParsedReceipt(
      merchant: merchant,
      purchasedAt: purchasedAt,
      subtotal: subtotal,
      tax: tax,
      rounding: rounding,
      total: total,
      warnings: warnings,
    );
  }

  // ---- totals and labelled amounts ---------------------------------------

  List<Money> _amountsIn(String line) => [
    for (final m in _amount.allMatches(line)) ?Money.tryParse(m[0]!),
  ];

  bool _isAmountOnly(String line) {
    final stripped = line.toUpperCase().replaceAll(RegExp(r'RM|MYR|\s'), '');
    return RegExp(r'^-?[\d,]+\.\d{1,2}$').hasMatch(stripped);
  }

  Money? _findTotal(List<String> lines) {
    for (final (label, exclude) in [
      (_totalStrong, _strongExclude),
      (_totalWeak, _weakExclude),
    ]) {
      // Bottom-up: the real total is near the end of the receipt.
      for (var i = lines.length - 1; i >= 0; i--) {
        final upper = lines[i].toUpperCase();
        if (!label.hasMatch(upper) || exclude.hasMatch(upper)) continue;

        var amounts = _amountsIn(lines[i]);
        if (amounts.isEmpty &&
            i + 1 < lines.length &&
            _isAmountOnly(lines[i + 1])) {
          amounts = _amountsIn(lines[i + 1]);
        }
        if (amounts.isEmpty) continue;

        final candidate = amounts.last;
        if (candidate.sen > 0 && candidate.sen <= _maxTotal.sen) {
          return candidate;
        }
      }
    }
    return null;
  }

  Money? _findLabelled(
    List<String> lines,
    RegExp label, {
    RegExp? exclude,
    bool allowNegative = false,
  }) {
    for (var i = lines.length - 1; i >= 0; i--) {
      final upper = lines[i].toUpperCase();
      if (!label.hasMatch(upper)) continue;
      if (exclude != null && exclude.hasMatch(upper)) continue;

      final amounts = _amountsIn(lines[i]);
      if (amounts.isEmpty) continue;
      if (!allowNegative && amounts.last.isNegative) continue;
      return amounts.last;
    }
    return null;
  }

  // ---- dates -------------------------------------------------------------

  DateTime? _findDate(List<String> lines, DateTime now) {
    for (var i = 0; i < lines.length; i++) {
      final date = _dateIn(lines[i]);
      if (date == null || !_isPlausible(date, now)) continue;

      final time =
          _timeIn(lines[i]) ??
          (i + 1 < lines.length ? _timeIn(lines[i + 1]) : null);
      return time == null
          ? date
          : DateTime(date.year, date.month, date.day, time.$1, time.$2);
    }
    return null;
  }

  DateTime? _dateIn(String line) {
    for (final m in _isoDate.allMatches(line)) {
      final d = _make(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
      if (d != null) return d;
    }
    for (final m in _numericDate4.allMatches(line)) {
      final d = _dayMonth(int.parse(m[3]!), int.parse(m[1]!), int.parse(m[2]!));
      if (d != null) return d;
    }
    for (final m in _namedDate.allMatches(line)) {
      final month = _months[m[2]!.toLowerCase()]!;
      final d = _make(_year(m[3]!), month, int.parse(m[1]!));
      if (d != null) return d;
    }
    for (final m in _numericDate2.allMatches(line)) {
      final d = _dayMonth(
        2000 + int.parse(m[3]!),
        int.parse(m[1]!),
        int.parse(m[2]!),
      );
      if (d != null) return d;
    }
    return null;
  }

  int _year(String v) => v.length == 2 ? 2000 + int.parse(v) : int.parse(v);

  /// Malaysian receipts are day/month/year; fall back to month/day when the
  /// first reading is impossible (e.g. 11/20/2026).
  DateTime? _dayMonth(int year, int a, int b) =>
      _make(year, b, a) ?? _make(year, a, b);

  DateTime? _make(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, m, d);
    // DateTime rolls 31 Feb over to March, so check it round-trips.
    return (dt.year == y && dt.month == m && dt.day == d) ? dt : null;
  }

  bool _isPlausible(DateTime d, DateTime now) {
    final latest = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 2));
    final earliest = DateTime(now.year - 10, now.month, now.day);
    return d.isBefore(latest) && !d.isBefore(earliest);
  }

  (int, int)? _timeIn(String line) {
    final m = _time.firstMatch(line);
    if (m == null) return null;

    var hour = int.parse(m[1]!);
    final minute = int.parse(m[2]!);
    final meridiem = m[3]?.toUpperCase();
    if (meridiem == 'PM' && hour < 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    return (hour, minute);
  }

  // ---- merchant ----------------------------------------------------------

  String? _findMerchant(List<String> lines) {
    for (final line in lines.take(8)) {
      if (!_isNoise(line)) return line;
    }
    return null;
  }

  bool _isNoise(String line) {
    final letters = RegExp(r'[A-Za-z]').allMatches(line).length;
    final digits = RegExp(r'\d').allMatches(line).length;
    if (letters < 3 || digits > letters) return true;
    if (_merchantNoise.hasMatch(line)) return true;
    return _dateIn(line) != null;
  }
}
