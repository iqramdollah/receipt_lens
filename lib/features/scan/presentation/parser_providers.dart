import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:receipt_lens/features/scan/data/fallback_receipt_parser.dart';

import '../../../core/app_config.dart';

import '../data/llm_receipt_parser.dart';
import '../data/offline_receipt_parser.dart';
import '../domain/receipt_parser.dart';

final receiptParserProvider = Provider<ReceiptParser>((ref) {
  if (!AppConfig.hasLlm) return const OfflineReceiptParser();

  final client = http.Client();
  ref.onDispose(client.close);

  return FallbackReceiptParser(
    primary: LlmReceiptParser(
      baseUrl: AppConfig.llmBaseUrl,
      model: AppConfig.llmModel.isEmpty ? null : AppConfig.llmModel,
      apiKey: AppConfig.llmApiKey.isEmpty ? null : AppConfig.llmApiKey,
      timeout: Duration(seconds: AppConfig.llmTimeoutSeconds),
      client: client,
    ),
  );
});
