import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_lens/features/receipts/data/image_store.dart';

void main() {
  late Directory tmp;
  late ImageStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('image_store_test');
    store = ImageStore(baseDir: () async => Directory('${tmp.path}/docs'));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('persist copies the file so it outlives the original', () async {
    final source = File('${tmp.path}/picked.jpg')..writeAsStringSync('img');

    final saved = await store.persist(source.path);
    source.deleteSync();

    expect(saved, isNot(source.path));
    expect(File(saved).readAsStringSync(), 'img');
  });

  test('delete removes the file and ignores null or missing paths', () async {
    final source = File('${tmp.path}/picked.jpg')..writeAsStringSync('img');
    final saved = await store.persist(source.path);

    await store.delete(saved);
    await store.delete(saved);
    await store.delete(null);

    expect(File(saved).existsSync(), isFalse);
  });
}
