import 'package:intl/intl.dart';

/// An amount of money stored as integer sen (RM 12.50 -> 1250).
class Money implements Comparable<Money> {
  const Money(this.sen);

  const Money.zero() : sen = 0;

  final int sen;

  static final _pattern = RegExp(
    r'^(-)?(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?$',
  );

  /// Parses receipt-style amounts: "12.50", "1,234.5", "RM 8", "MYR12.00", "-3.50".
  /// Returns null if the text is not a valid amount.
  static Money? tryParse(String input) {
    var s = input.trim().toUpperCase();
    s = s.replaceFirst(RegExp(r'^(RM|MYR)\s*'), '').replaceAll(' ', '');

    final m = _pattern.firstMatch(s);
    if (m == null) return null;

    final whole = int.parse(m.group(2)!.replaceAll(',', ''));
    final frac = int.parse((m.group(3) ?? '').padRight(2, '0'));
    final sen = whole * 100 + frac;
    return Money(m.group(1) != null ? -sen : sen);
  }

  /// Malaysian cash rounding: nearest 5 sen (1,2 -> 0; 3,4 -> 5; 6,7 -> 5; 8,9 -> 10).
  Money roundedToFiveSen() {
    final abs = sen.abs();
    final rounded = ((abs + 2) ~/ 5) * 5;
    return Money(sen < 0 ? -rounded : rounded);
  }

  Money operator +(Money other) => Money(sen + other.sen);
  Money operator -(Money other) => Money(sen - other.sen);
  Money operator -() => Money(-sen);

  bool get isNegative => sen < 0;

  static final _format = NumberFormat.currency(
    locale: 'en_MY',
    symbol: 'RM ',
    decimalDigits: 2,
  );

  /// "RM 1,234.50"
  String format() => _format.format(sen / 100);

  @override
  int compareTo(Money other) => sen.compareTo(other.sen);

  @override
  bool operator ==(Object other) => other is Money && other.sen == sen;

  @override
  int get hashCode => sen.hashCode;

  @override
  String toString() => 'Money($sen sen)';
}
