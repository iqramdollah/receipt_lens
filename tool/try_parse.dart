import 'dart:io';

import 'package:receipt_lens/features/scan/data/llm_receipt_parser.dart';
import 'package:receipt_lens/features/scan/domain/receipt_parser.dart';

/// Tries the real LLM parser from the command line.
/// Usage: dart run tool/try_parse.dart tool/sample_receipt.txt [model-id]
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/try_parse.dart <receipt-text-file> [model-id]',
    );
    exitCode = 64;
    return;
  }

  final parser = LlmReceiptParser(
    baseUrl: Platform.environment['LLM_BASE_URL'] ?? 'http://127.0.0.1:1234',
    model: args.length > 1 ? args[1] : null,
    extraBody: const {
      'chat_template_kwargs': {'enable_thinking': false},
    },
    timeout: Duration(
      seconds: int.tryParse(Platform.environment['LLM_TIMEOUT'] ?? '') ?? 60,
    ),
  );

  try {
    final r = await parser.parse(await File(args.first).readAsString());
    stdout
      ..writeln('merchant : ${r.merchant}')
      ..writeln('date     : ${r.purchasedAt}')
      ..writeln('subtotal : ${r.subtotal?.format()}')
      ..writeln('tax      : ${r.tax?.format()}')
      ..writeln('rounding : ${r.rounding?.format()}')
      ..writeln('total    : ${r.total?.format()}')
      ..writeln('category : ${r.categoryName}');
    for (final i in r.items) {
      stdout.writeln('  - ${i.name} x${i.quantity} = ${i.lineTotal.format()}');
    }
    if (r.warnings.isNotEmpty) {
      stdout.writeln('warnings : ${r.warnings.join('; ')}');
    }
  } on ParseException catch (e) {
    stderr.writeln('Failed: ${e.message}');
    exitCode = 1;
  }
}
