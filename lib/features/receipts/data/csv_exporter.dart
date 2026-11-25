import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Writes a CSV into the app's temporary folder, ready to be shared.
class CsvExporter {
  CsvExporter({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getTemporaryDirectory;

  final Future<Directory> Function() _baseDir;

  Future<File> write(String csv, {DateTime? now}) async {
    final d = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');

    final dir = await _baseDir();
    await dir.create(recursive: true);

    // The BOM makes Excel read non-ASCII merchant names correctly.
    return File(
      p.join(dir.path, 'receipts_${d.year}-${two(d.month)}-${two(d.day)}.csv'),
    ).writeAsString('\uFEFF$csv');
  }
}
