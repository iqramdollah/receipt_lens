import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_lens/core/database/app_database.dart';
import 'package:receipt_lens/core/money.dart';
import 'package:receipt_lens/features/receipts/data/csv_exporter.dart';
import 'package:receipt_lens/features/receipts/data/receipt_repository.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_csv.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_draft.dart';
import 'package:receipt_lens/features/receipts/domain/receipt_source.dart';

void main() {
  late AppDatabase db;
  late ReceiptRepository repo;
  late int cat;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReceiptRepository(db);
    cat = (await db.select(db.categories).get()).first.id;
  });

  tearDown(() => db.close());

  Future<String> csvFor(ReceiptDraft draft, {Map<int, String>? names}) async {
    await repo.save(draft);
    return receiptsToCsv(
      await repo.watchAll().first,
      categoryNames: names ?? {cat: 'Food'},
    );
  }

  ReceiptDraft draft({
    String merchant = 'Mydin',
    Money? subtotal,
    Money? tax,
    Money rounding = const Money.zero(),
    Money total = const Money(4400),
    bool review = false,
  }) => ReceiptDraft(
    merchant: merchant,
    purchasedAt: DateTime(2026, 11, 20, 13, 45),
    total: total,
    subtotal: subtotal,
    tax: tax,
    rounding: rounding,
    categoryId: cat,
    rawText: '',
    source: ReceiptSource.manual,
    needsReview: review,
  );

  test('writes a header and one row per receipt', () async {
    final csv = await csvFor(
      draft(
        subtotal: const Money(4150),
        tax: const Money(249),
        rounding: const Money(1),
      ),
    );

    final lines = csv.split('\r\n');
    expect(
      lines[0],
      'Date,Merchant,Category,Subtotal,Tax,Rounding,Total,Currency,Source,Needs review',
    );
    expect(
      lines[1],
      '2026-11-20 13:45,Mydin,Food,41.50,2.49,0.01,44.00,MYR,manual,no',
    );
    expect(lines, hasLength(3));
    expect(lines.last, '');
  });

  test(
    'leaves missing amounts empty and flags receipts needing review',
    () async {
      final csv = await csvFor(
        draft(merchant: 'Cafe', total: const Money(1250), review: true),
      );

      expect(
        csv.split('\r\n')[1],
        '2026-11-20 13:45,Cafe,Food,,,0.00,12.50,MYR,manual,yes',
      );
    },
  );

  test('keeps negative rounding as a number', () async {
    final csv = await csvFor(draft(rounding: const Money(-2)));

    expect(csv.split('\r\n')[1], contains(',-0.02,'));
  });

  test('quotes commas and doubles quote marks', () async {
    final csv = await csvFor(draft(merchant: 'Ah Huat, "Best" Kedai'));

    expect(csv, contains('"Ah Huat, ""Best"" Kedai"'));
  });

  test('defuses spreadsheet formulas in text cells', () async {
    final csv = await csvFor(draft(merchant: '=HYPERLINK("x")'));

    expect(csv, contains('''"'=HYPERLINK(""x"")"'''));
  });

  test('uses Uncategorized when the category is unknown', () async {
    final csv = await csvFor(draft(), names: const {});

    expect(csv.split('\r\n')[1], contains(',Uncategorized,'));
  });

  test('CsvExporter writes a BOM-prefixed file named by date', () async {
    final tmp = Directory.systemTemp.createTempSync('csv_export_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final exporter = CsvExporter(
      baseDir: () async => Directory('${tmp.path}/out'),
    );

    final file = await exporter.write('a,b\r\n', now: DateTime(2026, 11, 22));

    expect(file.path, endsWith('receipts_2026-11-22.csv'));
    final bytes = file.readAsBytesSync();
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(utf8.decode(bytes.sublist(3)), 'a,b\r\n');
  });
}
