import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/money.dart';
import '../../receipts/domain/receipt_source.dart';
import '../domain/parsed_receipt.dart';
import '../domain/receipt_parser.dart';

/// Parses OCR text with an OpenAI-compatible chat endpoint (LM Studio now,
/// possibly a proxy in front of a hosted model later). Every field is
/// validated: anything implausible becomes null plus a warning, never a guess.
class LlmReceiptParser implements ReceiptParser {
  LlmReceiptParser({
    required String baseUrl,
    this.model,
    this.apiKey,
    this.categories = defaultCategories,
    this.timeout = const Duration(seconds: 60),
    this.extraBody = const {},
    DateTime Function()? clock,
    http.Client? client,
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _clock = clock ?? DateTime.now,
       _client = client ?? http.Client();

  static const defaultCategories = [
    'Food',
    'Groceries',
    'Transport',
    'Shopping',
    'Bills',
    'Health',
    'Entertainment',
    'Other',
  ];

  static const _maxChars = 8000;
  static const _maxTotal = Money(10000000); // RM 100,000

  final String _baseUrl;
  final String? model;
  final String? apiKey;
  final List<String> categories;
  final Duration timeout;

  /// Extra request fields for server-specific options, e.g. turning off
  /// "thinking" on local reasoning models.
  final Map<String, dynamic> extraBody;
  final DateTime Function() _clock;
  final http.Client _client;

  @override
  Future<ParsedReceipt> parse(String ocrText) async {
    final content = await _complete(ocrText);
    return _map(_decodeObject(content));
  }

  // ---- network ------------------------------------------------------------

  Future<String> _complete(String ocrText) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              if (apiKey != null && apiKey!.isNotEmpty)
                'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              if (model != null && model!.isNotEmpty) 'model': model,
              'temperature': 0,
              ...extraBody,
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {'role': 'user', 'content': _clip(ocrText)},
              ],
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ParseException('the AI server did not answer in time');
    } on SocketException {
      throw const ParseException('could not reach the AI server');
    } on http.ClientException {
      throw const ParseException('could not reach the AI server');
    }

    if (response.statusCode != 200) {
      throw ParseException('the AI server returned ${response.statusCode}');
    }

    try {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final first = (data['choices'] as List).first as Map<String, dynamic>;
      return (first['message'] as Map<String, dynamic>)['content'] as String;
    } on Object {
      throw const ParseException('the AI server sent an unexpected response');
    }
  }

  /// Keeps the top (merchant, date) and bottom (totals) of very long receipts.
  String _clip(String text) => text.length <= _maxChars
      ? text
      : '${text.substring(0, 3000)}\n${text.substring(text.length - 5000)}';

  String get _systemPrompt =>
      '''
You extract structured data from Malaysian receipts. The user message is raw OCR text and may contain mistakes.

Reply with ONE JSON object and nothing else (no markdown, no explanation), with exactly these keys:
{"merchant": string or null, "purchased_at": "YYYY-MM-DDTHH:MM" or "YYYY-MM-DD" or null, "subtotal": number or null, "tax": number or null, "rounding": number or null, "total": number or null, "category": one of [${categories.join(', ')}] or null, "items": [{"name": string, "quantity": number, "unit_price": number or null, "line_total": number}]}

Rules:
- Output compact JSON on a single line (no indentation) and do not explain your reasoning.
- Use null for anything not clearly present. Never invent items or amounts.
- Amounts are plain numbers in RM, no currency symbols.
- Dates on Malaysian receipts are day/month/year.
- tax is SST or service tax. rounding is the rounding adjustment line and may be negative.
- items are purchased products only: not payment, cash, change or tax lines.
- A line like "NAME  2  17.00" has a quantity and ONE amount. Treat that amount as the line_total (the price for all units) and set unit_price to line_total divided by quantity. Only treat an amount as a unit price if the receipt clearly labels it as one.
- The line_total values should add up to the subtotal. If they do not, re-read the lines with the other interpretation.''';

  // ---- decoding -------------------------------------------------------------

  Map<String, dynamic> _decodeObject(String content) {
    // Some models think out loud or wrap the JSON in a markdown fence.
    final text = content.replaceAll(
      RegExp(r'<think>.*?</think>', dotAll: true),
      '',
    );
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const ParseException('the AI answer was not JSON');
    }
    try {
      return jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
    } on Object {
      throw const ParseException('the AI answer was not valid JSON');
    }
  }

  // ---- validation ------------------------------------------------------------

  ParsedReceipt _map(Map<String, dynamic> json) {
    final merchant = _text(json['merchant']);
    final purchasedAt = _date(json['purchased_at']);
    final total = _positive(_money(json['total']));
    final subtotal = _nonNegative(_money(json['subtotal']));
    final tax = _nonNegative(_money(json['tax']));
    final rounding = _rounding(_money(json['rounding']));
    final items = _items(json['items']);

    final warnings = <String>[
      if (merchant == null) 'Merchant not found',
      if (purchasedAt == null) 'Date not found',
      if (total == null) 'Total not found',
    ];

    if (total != null) {
      if (subtotal != null) {
        final expected =
            subtotal +
            (tax ?? const Money.zero()) +
            (rounding ?? const Money.zero());
        if ((expected - total).sen.abs() > 10) {
          warnings.add('Subtotal, tax and rounding do not add up to the total');
        }
      }
      if (items.isNotEmpty &&
          !_itemsAddUp(items, total, subtotal, tax, rounding)) {
        warnings.add('Items do not add up to the total');
      }
    }

    return ParsedReceipt(
      merchant: merchant,
      purchasedAt: purchasedAt,
      subtotal: subtotal,
      tax: tax,
      rounding: rounding,
      total: total,
      categoryName: _category(json['category']),
      items: items,
      source: ReceiptSource.llm,
      warnings: warnings,
    );
  }

  /// Item prices may include or exclude tax, so accept any sensible base.
  bool _itemsAddUp(
    List<ParsedItem> items,
    Money total,
    Money? subtotal,
    Money? tax,
    Money? rounding,
  ) {
    final sum = items.fold<Money>(
      const Money.zero(),
      (a, i) => a + i.lineTotal,
    );
    final bases = [
      total,
      ?subtotal,
      total - (tax ?? const Money.zero()) - (rounding ?? const Money.zero()),
    ];
    return bases.any((b) => (sum - b).sen.abs() <= 10);
  }

  String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Money? _money(Object? v) {
    if (v is num) return v.isFinite ? Money((v * 100).round()) : null;
    if (v is String) return Money.tryParse(v);
    return null;
  }

  Money? _positive(Money? m) =>
      (m != null && m.sen > 0 && m.sen <= _maxTotal.sen) ? m : null;

  Money? _nonNegative(Money? m) =>
      (m != null && m.sen >= 0 && m.sen <= _maxTotal.sen) ? m : null;

  Money? _rounding(Money? m) => (m != null && m.sen.abs() <= 100) ? m : null;

  DateTime? _date(Object? v) {
    if (v is! String) return null;
    final d = DateTime.tryParse(v.trim());
    if (d == null) return null;
    final now = _clock();
    final latest = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 2));
    final earliest = DateTime(now.year - 10, now.month, now.day);
    return (d.isBefore(latest) && !d.isBefore(earliest)) ? d : null;
  }

  String? _category(Object? v) {
    if (v is! String) return null;
    final wanted = v.trim().toLowerCase();
    for (final c in categories) {
      if (c.toLowerCase() == wanted) return c;
    }
    return null;
  }

  List<ParsedItem> _items(Object? v) {
    if (v is! List) return const [];
    final result = <ParsedItem>[];
    for (final raw in v) {
      if (raw is! Map<String, dynamic>) continue;
      final name = _text(raw['name']);
      final lineTotal = _nonNegative(_money(raw['line_total']));
      if (name == null || lineTotal == null) continue;

      final q = raw['quantity'];
      result.add(
        ParsedItem(
          name: name,
          lineTotal: lineTotal,
          quantity: (q is num && q.isFinite && q > 0) ? q.toDouble() : 1,
          unitPrice: _nonNegative(_money(raw['unit_price'])),
        ),
      );
    }
    return result;
  }
}
