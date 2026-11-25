import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_lens/core/money.dart';
import 'package:receipt_lens/features/scan/data/regex_receipt_parser.dart';

void main() {
  const parser = RegexReceiptParser();
  final now = DateTime(2026, 11, 21);

  group('total', () {
    test('reads the total from the mockup receipt your OCR produced', () {
      const text = '''
SHOP NAME
Address: Lorem Ipsum, 23-10
Telp. 11223344
CASH RECEIPT
Description  Price
Lorem  1.1
Iosum  2.2
Dolor sit amet  3.3
Consectetur  4.4
Adipiscing elit  5.5
Total  16.5
Cash  20.0
Change  3.5
Bank card  234
Approval Code  B123456
THANK YOU!''';

      final r = parser.parse(text, now: now);

      expect(r.total, const Money(1650));
      expect(r.merchant, 'SHOP NAME');
      expect(r.purchasedAt, isNull);
      expect(r.warnings, ['Date not found']);
    });

    test('prefers GRAND TOTAL over a weaker TOTAL line', () {
      final r = parser.parse(
        'STORE\nTOTAL SALES  100.00\nDISCOUNT  10.00\nGRAND TOTAL  90.00',
        now: now,
      );
      expect(r.total, const Money(9000));
    });

    test('reads the amount from the next line when the label is alone', () {
      final r = parser.parse('CAFE\nTOTAL\nRM 12.50', now: now);
      expect(r.total, const Money(1250));
    });

    test('accepts "TOTAL (INCL. SST)"', () {
      final r = parser.parse('CAFE\nTOTAL (INCL. SST)  21.75', now: now);
      expect(r.total, const Money(2175));
    });

    test('ignores TOTAL SAVINGS lines below the real total', () {
      final r = parser.parse(
        'STORE\nTOTAL  21.75\nTOTAL SAVINGS  3.00',
        now: now,
      );
      expect(r.total, const Money(2175));
    });

    test('rejects absurd totals instead of guessing', () {
      final r = parser.parse('STORE\nTOTAL  99999999.00', now: now);
      expect(r.total, isNull);
      expect(r.warnings, contains('Total not found'));
    });
  });

  group('dates', () {
    final cases = {
      '20/11/2026': DateTime(2026, 11, 20),
      '20-11-2026': DateTime(2026, 11, 20),
      '20.11.2026': DateTime(2026, 11, 20),
      '20/11/26': DateTime(2026, 11, 20),
      '2026-11-20': DateTime(2026, 11, 20),
      '20 Nov 2026': DateTime(2026, 11, 20),
      '5 OGOS 2026': DateTime(2026, 8, 5),
      '05-Mei-2026': DateTime(2026, 5, 5),
    };

    cases.forEach((input, expected) {
      test('parses "$input"', () {
        final r = parser.parse('CAFE\n$input\nTOTAL 5.00', now: now);
        expect(r.purchasedAt, expected);
      });
    });

    test('adds the time, including AM/PM', () {
      expect(
        parser.parse('CAFE\n20/11/2026 01:05 PM', now: now).purchasedAt,
        DateTime(2026, 11, 20, 13, 5),
      );
      expect(
        parser.parse('CAFE\n20/11/2026 12:30 AM', now: now).purchasedAt,
        DateTime(2026, 11, 20, 0, 30),
      );
    });

    test('rejects impossible and implausible dates', () {
      for (final bad in ['31/02/2026', '20/11/2031', '20/11/2010']) {
        final r = parser.parse('CAFE\n$bad\nTOTAL 5.00', now: now);
        expect(r.purchasedAt, isNull, reason: bad);
        expect(r.warnings, contains('Date not found'), reason: bad);
      }
    });
  });

  group('other fields', () {
    test('parses a typical Malaysian supermarket receipt', () {
      const text = '''
MYDIN WHOLESALE SDN BHD
(123456-A)
JALAN INDUSTRI 5, JOHOR BAHRU
TEL: 07-1234567
20/11/2026 13:45
NASI LEMAK  2  17.00
TEH TARIK  1  3.50
SUBTOTAL  20.50
SST 6%  1.23
ROUNDING ADJ  0.02
TOTAL  21.75
CASH  50.00
CHANGE  28.25''';

      final r = parser.parse(text, now: now);

      expect(r.merchant, 'MYDIN WHOLESALE SDN BHD');
      expect(r.purchasedAt, DateTime(2026, 11, 20, 13, 45));
      expect(r.subtotal, const Money(2050));
      expect(r.tax, const Money(123));
      expect(r.rounding, const Money(2));
      expect(r.total, const Money(2175));
      expect(r.warnings, isEmpty);
      expect(r.isComplete, isTrue);
    });

    test('keeps a negative rounding adjustment', () {
      final r = parser.parse('CAFE\nTOTAL  10.00\nROUNDING  -0.02', now: now);
      expect(r.rounding, const Money(-2));
    });

    test('does not mistake a tax percentage for an amount', () {
      final r = parser.parse('CAFE\nSST 6.00%  1.23\nTOTAL  21.73', now: now);
      expect(r.tax, const Money(123));
      expect(r.total, const Money(2173));
    });

    test(
      'skips headers, phone numbers and addresses when finding the merchant',
      () {
        final r = parser.parse(
          'TAX INVOICE\nTEL 03-12345678\nKEDAI RUNCIT AH HUAT\nTOTAL 5.00',
          now: now,
        );
        expect(r.merchant, 'KEDAI RUNCIT AH HUAT');
      },
    );

    test('warns when subtotal, tax and rounding do not add up', () {
      final r = parser.parse(
        'CAFE\nSUBTOTAL  10.00\nSST 6%  0.60\nTOTAL  12.00',
        now: now,
      );
      expect(
        r.warnings,
        contains('Subtotal, tax and rounding do not add up to the total'),
      );
    });

    test('handles empty text without crashing', () {
      final r = parser.parse('', now: now);
      expect(r.isComplete, isFalse);
      expect(r.warnings, [
        'Merchant not found',
        'Date not found',
        'Total not found',
      ]);
    });
  });
}
