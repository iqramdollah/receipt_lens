import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps receipt photos in app-private storage so they survive cache clears.
class ImageStore {
  ImageStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;

  /// Copies [sourcePath] into the store and returns the new path.
  Future<String> persist(String sourcePath) async {
    final base = await _baseDir();
    final dir = Directory(p.join(base.path, 'receipt_images'));
    await dir.create(recursive: true);

    final name =
        '${DateTime.now().microsecondsSinceEpoch}${p.extension(sourcePath)}';
    final saved = await File(sourcePath).copy(p.join(dir.path, name));
    return saved.path;
  }

  Future<void> delete(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
