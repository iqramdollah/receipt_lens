import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_lens/core/money.dart';

void main() {
  group('Money.tryParse', () {
    test('parses plain amounts', () {
      expect(Money.tryParse('12.50'), const Money(1250));
      expect(Money.tryParse('16.5'), const Money(1650));
      expect(Money.tryParse('8'), const Money(800));
    });

    test('parses currency prefixes and thousands separators', () {
      expect(Money.tryParse('RM 8.90'), const Money(890));
      expect(Money.tryParse('MYR12.00'), const Money(1200));
      expect(Money.tryParse('1,234.50'), const Money(123450));
    });

    test('parses negatives', () {
      expect(Money.tryParse('-3.50'), const Money(-350));
    });

    test('rejects invalid input', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse('12.345'), isNull);
      expect(Money.tryParse('12,50'), isNull);
    });
  });

  group('Money.roundedToFiveSen', () {
    test('rounds to nearest 5 sen', () {
      expect(const Money(1001).roundedToFiveSen(), const Money(1000));
      expect(const Money(1002).roundedToFiveSen(), const Money(1000));
      expect(const Money(1003).roundedToFiveSen(), const Money(1005));
      expect(const Money(1004).roundedToFiveSen(), const Money(1005));
      expect(const Money(1006).roundedToFiveSen(), const Money(1005));
      expect(const Money(1007).roundedToFiveSen(), const Money(1005));
      expect(const Money(1008).roundedToFiveSen(), const Money(1010));
      expect(const Money(1009).roundedToFiveSen(), const Money(1010));
    });

    test('handles negatives symmetrically', () {
      expect(const Money(-1003).roundedToFiveSen(), const Money(-1005));
    });
  });

  group('Money arithmetic and formatting', () {
    test('adds and subtracts exactly', () {
      expect(const Money(10) + const Money(20), const Money(30));
      expect(const Money(1650) - const Money(2000), const Money(-350));
    });

    test('formats as RM', () {
      expect(const Money(123450).format(), 'RM 1,234.50');
      expect(const Money(5).format(), 'RM 0.05');
    });
  });
}
