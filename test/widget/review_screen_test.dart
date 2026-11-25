import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:receipt_lens/core/database/app_database.dart';
import 'package:receipt_lens/core/money.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_source.dart';
import 'package:receipt_lens/features/scan/data/offline_receipt_parser.dart';
import 'package:receipt_lens/features/scan/domain/parsed_receipt.dart';
import 'package:receipt_lens/features/scan/domain/receipt_parser.dart';
import 'package:receipt_lens/features/scan/presentation/parser_providers.dart';
import 'package:receipt_lens/features/scan/presentation/receipt_providers.dart';
import 'package:receipt_lens/features/scan/presentation/review_screen.dart';
import 'package:receipt_lens/features/scan/presentation/scan_controller.dart';

class _ControlledParser implements ReceiptParser {
  final completer = Completer<ParsedReceipt>();

  @override
  Future<ParsedReceipt> parse(String ocrText) => completer.future;
}

Widget _app(ReceiptParser parser) => ProviderScope(
  overrides: [
    receiptParserProvider.overrideWithValue(parser),
    categoriesProvider.overrideWith(
      (ref) => Stream.value(const [
        Category(id: 1, name: 'Food', color: 0xFFEF6C00, isDefault: true),
        Category(id: 2, name: 'Groceries', color: 0xFF2E7D32, isDefault: true),
      ]),
    ),
  ],
  child: const MaterialApp(
    home: ReviewScreen(
      scan: ScanResult(imagePath: 'missing.jpg', text: 'raw text'),
    ),
  ),
);

void main() {
  testWidgets('shows a loading state, then pre-fills from the parser', (
    tester,
  ) async {
    // A tall screen so the lazy ListView builds the lower fields too.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final parser = _ControlledParser();
    await tester.pumpWidget(_app(parser));

    expect(find.text('Reading receipt…'), findsOneWidget);

    parser.completer.complete(
      ParsedReceipt(
        merchant: 'Mydin',
        purchasedAt: DateTime(2026, 11, 20),
        total: const Money(2175),
        categoryName: 'Groceries',
        source: ReceiptSource.llm,
        warnings: const ['Items do not add up to the total'],
      ),
    );
    // Not pumpAndSettle: a spinner that never leaves keeps scheduling frames
    // and makes it time out. A few bounded pumps fail with a readable message.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Reading receipt…'), findsNothing);
    expect(find.text('Mydin'), findsOneWidget);
    expect(find.text('21.75'), findsOneWidget);
    expect(find.text('Groceries'), findsWidgets);
    expect(find.byKey(const Key('warnings_banner')), findsOneWidget);
    expect(find.text('• Items do not add up to the total'), findsOneWidget);
  });

  testWidgets('lets the user skip waiting and fill the form in manually', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_ControlledParser()));

    await tester.tap(find.text('Fill in manually'));
    await tester.pumpAndSettle();

    expect(find.text('Reading receipt…'), findsNothing);
    expect(find.text('Merchant'), findsOneWidget);
    expect(find.byKey(const Key('warnings_banner')), findsNothing);
  });

  test('OfflineReceiptParser returns the regex result', () async {
    final r = await const OfflineReceiptParser().parse(
      'SHOP NAME\nTotal  16.5',
    );

    expect(r.merchant, 'SHOP NAME');
    expect(r.total, const Money(1650));
    expect(r.source, ReceiptSource.regex);
  });
}
