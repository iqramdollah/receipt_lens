import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'review_screen.dart';
import 'scan_controller.dart';

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // As soon as the text has been read, go straight to the review form.
    ref.listen(scanControllerProvider, (_, next) {
      if (next is! AsyncData<ScanResult?>) return;
      final result = next.value;
      if (result == null) return;

      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ReviewScreen(scan: result)),
      );
      // Back to idle, so coming back here shows a fresh scan screen.
      Future.microtask(controller.reset);
    });

    if (scan.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('ReceiptLens')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Reading text…'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ReceiptLens')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.document_scanner_outlined,
                size: 56,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Scan a receipt',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Take a photo or pick one from your gallery. '
            'ReceiptLens reads the details for you to check and save.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (scan.hasError) ...[
            const SizedBox(height: 16),
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Could not read that photo. Try again with better light.\n\n'
                  '${scan.error}',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => controller.scan(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take photo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => controller.scan(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Choose from gallery'),
          ),
          const SizedBox(height: 32),
          Text('For a clean scan', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const _Tip(
            Icons.light_mode_outlined,
            'Use good light and avoid glare',
          ),
          const _Tip(Icons.crop_free, 'Keep the whole receipt in the frame'),
          const _Tip(Icons.straighten, 'Lay it flat so the text is straight'),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
