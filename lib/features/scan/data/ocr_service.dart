import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  OcrService()
    : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  Future<String> recognize(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);
    final lines = [for (final block in result.blocks) ...block.lines];
    return _rebuild(lines);
  }

  /// Groups OCR lines that sit on the same visual row, then orders each
  /// row left to right, so "NASI LEMAK     8.50" stays on one line.
  String _rebuild(List<TextLine> lines) {
    if (lines.isEmpty) return '';

    final sorted = [...lines]
      ..sort(
        (a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy),
      );

    final rows = <List<TextLine>>[];
    for (final line in sorted) {
      if (rows.isNotEmpty) {
        final row = rows.last;
        final rowY =
            row.map((l) => l.boundingBox.center.dy).reduce((a, b) => a + b) /
            row.length;
        if ((line.boundingBox.center.dy - rowY).abs() <
            line.boundingBox.height * 0.6) {
          row.add(line);
          continue;
        }
      }
      rows.add([line]);
    }

    return rows
        .map((row) {
          row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
          return row.map((l) => l.text).join('  ');
        })
        .join('\n');
  }

  Future<void> dispose() => _recognizer.close();
}
