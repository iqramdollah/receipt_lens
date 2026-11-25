import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:receipt_lens/core/money.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_source.dart';
import 'package:receipt_lens/features/scan/data/fallback_receipt_parser.dart';
import 'package:receipt_lens/features/scan/data/llm_receipt_parser.dart';
import 'package:receipt_lens/features/scan/domain/parsed_receipt.dart';
import 'package:receipt_lens/features/scan/domain/receipt_parser.dart';

final _now = DateTime(2026, 11, 21);

final _good = <String, dynamic>{
  'merchant': 'Mydin',
  'purchased_at': '2026-11-20T13:45',
  'subtotal': 20.5,
  'tax': 1.23,
  'rounding': 0.02,
  'total': 21.75,
  'category': 'groceries',
  'items': [
    {
      'name': 'Nasi Lemak',
      'quantity': 2,
      'unit_price': 8.5,
      'line_total': 17.0,
    },
    {'name': 'Teh Tarik', 'quantity': 1, 'unit_price': 3.5, 'line_total': 3.5},
  ],
};

http.Response _chat(String content) => http.Response(
  jsonEncode({
    'choices': [
      {
        'message': {'content': content},
      },
    ],
  }),
  200,
);

LlmReceiptParser _parser(MockClient client, {Duration? timeout}) =>
    LlmReceiptParser(
      baseUrl: 'http://10.0.2.2:1234/',
      model: 'test-model',
      timeout: timeout ?? const Duration(seconds: 5),
      clock: () => _now,
      client: client,
    );

LlmReceiptParser _replying(String content) =>
    _parser(MockClient((_) async => _chat(content)));

class _Failing implements ReceiptParser {
  const _Failing();

  @override
  Future<ParsedReceipt> parse(String ocrText) async =>
      throw const ParseException('offline');
}

class _Fixed implements ReceiptParser {
  const _Fixed();

  @override
  Future<ParsedReceipt> parse(String ocrText) async =>
      const ParsedReceipt(merchant: 'From AI', source: ReceiptSource.llm);
}

void main() {
  group('LlmReceiptParser', () {
    test('sends the OCR text and maps a clean answer', () async {
      late http.Request seen;
      final parser = _parser(
        MockClient((req) async {
          seen = req;
          return _chat(jsonEncode(_good));
        }),
      );

      final r = await parser.parse('MYDIN\nTOTAL 21.75');

      expect(seen.url.toString(), 'http://10.0.2.2:1234/v1/chat/completions');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['model'], 'test-model');
      expect(body['temperature'], 0);
      expect((body['messages'] as List).last, {
        'role': 'user',
        'content': 'MYDIN\nTOTAL 21.75',
      });

      expect(r.merchant, 'Mydin');
      expect(r.purchasedAt, DateTime(2026, 11, 20, 13, 45));
      expect(r.subtotal, const Money(2050));
      expect(r.tax, const Money(123));
      expect(r.rounding, const Money(2));
      expect(r.total, const Money(2175));
      expect(r.categoryName, 'Groceries');
      expect(r.source, ReceiptSource.llm);
      expect(r.items, hasLength(2));
      expect(r.items.first.name, 'Nasi Lemak');
      expect(r.items.first.quantity, 2);
      expect(r.items.first.unitPrice, const Money(850));
      expect(r.items.first.lineTotal, const Money(1700));
      expect(r.warnings, isEmpty);
    });

    test('copes with markdown fences and thinking text', () async {
      final content =
          '<think>maybe {"total": 1}</think>\n```json\n${jsonEncode(_good)}\n```';

      final r = await _replying(content).parse('x');

      expect(r.total, const Money(2175));
      expect(r.merchant, 'Mydin');
    });

    test('drops implausible values instead of guessing', () async {
      final r = await _replying(
        jsonEncode({
          'merchant': '  ',
          'purchased_at': '2031-01-01',
          'total': 99999999,
          'category': 'Crypto',
          'items': 'none',
        }),
      ).parse('x');

      expect(r.merchant, isNull);
      expect(r.purchasedAt, isNull);
      expect(r.total, isNull);
      expect(r.categoryName, isNull);
      expect(r.items, isEmpty);
      expect(r.warnings, [
        'Merchant not found',
        'Date not found',
        'Total not found',
      ]);
    });

    test('accepts amounts sent as strings', () async {
      final r = await _replying(
        jsonEncode({'merchant': 'Cafe', 'total': 'RM 21.75'}),
      ).parse('x');

      expect(r.total, const Money(2175));
    });

    test('warns when items do not add up to the total', () async {
      final r = await _replying(
        jsonEncode({
          'merchant': 'Cafe',
          'purchased_at': '2026-11-20',
          'total': 21.75,
          'items': [
            {'name': 'Tea', 'line_total': 3.5},
          ],
        }),
      ).parse('x');

      expect(r.warnings, ['Items do not add up to the total']);
    });

    test('warns when subtotal, tax and rounding do not add up', () async {
      final r = await _replying(
        jsonEncode({
          'merchant': 'Cafe',
          'purchased_at': '2026-11-20',
          'subtotal': 10,
          'tax': 0.6,
          'total': 12,
        }),
      ).parse('x');

      expect(r.warnings, [
        'Subtotal, tax and rounding do not add up to the total',
      ]);
    });

    test('skips malformed items and keeps the good ones', () async {
      final r = await _replying(
        jsonEncode({
          'merchant': 'Cafe',
          'purchased_at': '2026-11-20',
          'total': 3.5,
          'items': [
            {'name': 'Tea', 'line_total': 3.5},
            {'name': '', 'line_total': 1},
            {'line_total': 2},
          ],
        }),
      ).parse('x');

      expect(r.items, hasLength(1));
      expect(r.items.single.name, 'Tea');
      expect(r.warnings, isEmpty);
    });
  });

  group('LlmReceiptParser failures', () {
    test('HTTP errors become ParseException', () {
      final parser = _parser(
        MockClient((_) async => http.Response('boom', 500)),
      );
      expect(parser.parse('x'), throwsA(isA<ParseException>()));
    });

    test('a non-JSON answer becomes ParseException', () {
      expect(
        _replying('Sorry, I cannot help with that.').parse('x'),
        throwsA(isA<ParseException>()),
      );
    });

    test('an unexpected response shape becomes ParseException', () {
      final parser = _parser(
        MockClient((_) async => http.Response('{"oops": 1}', 200)),
      );
      expect(parser.parse('x'), throwsA(isA<ParseException>()));
    });

    test('a slow server becomes ParseException', () {
      final parser = _parser(
        MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return _chat('{}');
        }),
        timeout: const Duration(milliseconds: 20),
      );
      expect(parser.parse('x'), throwsA(isA<ParseException>()));
    });

    test('an unreachable server becomes ParseException', () {
      final parser = _parser(
        MockClient((_) async => throw http.ClientException('down')),
      );
      expect(parser.parse('x'), throwsA(isA<ParseException>()));
    });
  });

  group('FallbackReceiptParser', () {
    test('uses the offline parser when the AI server fails', () async {
      const parser = FallbackReceiptParser(primary: _Failing());

      final r = await parser.parse('SHOP NAME\nTotal  16.5');

      expect(r.source, ReceiptSource.regex);
      expect(r.merchant, 'SHOP NAME');
      expect(r.total, const Money(1650));
      expect(r.warnings.first, startsWith('AI parsing unavailable'));
    });

    test('returns the AI result untouched when it works', () async {
      const parser = FallbackReceiptParser(primary: _Fixed());

      final r = await parser.parse('anything');

      expect(r.merchant, 'From AI');
      expect(r.source, ReceiptSource.llm);
    });
  });
}
