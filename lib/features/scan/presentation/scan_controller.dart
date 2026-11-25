import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ocr_service.dart';

final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrService();
  ref.onDispose(service.dispose);
  return service;
});

class ScanResult {
  const ScanResult({required this.imagePath, required this.text});

  final String imagePath;
  final String text;
}

class ScanController extends AsyncNotifier<ScanResult?> {
  @override
  Future<ScanResult?> build() async => null;

  /// Back to the idle state, once the result has been handed to the review form.
  void reset() => state = const AsyncData(null);

  Future<void> scan(ImageSource source) async {
    final previous = state.value;
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final picked = await ref
          .read(imagePickerProvider)
          .pickImage(source: source, maxWidth: 2000, imageQuality: 90);
      if (picked == null) return previous; // user cancelled

      final text = await ref.read(ocrServiceProvider).recognize(picked.path);
      return ScanResult(imagePath: picked.path, text: text);
    });
  }
}

final scanControllerProvider =
    AsyncNotifierProvider<ScanController, ScanResult?>(ScanController.new);
