import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shared/glass.dart';
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
    final top = MediaQuery.paddingOf(context).top + 56;
    final soft = Colors.white.withValues(alpha: 0.85);

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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('ReceiptLens'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: RepaintBoundary(child: BrandHeaderBackground(height: 460)),
          ),
          ListView(
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, 24),
            children: [
              Text(
                'Scan a receipt',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Take a photo or pick one from your gallery. '
                'The text is read on your phone.',
                style: theme.textTheme.bodyLarge?.copyWith(color: soft),
              ),
              const SizedBox(height: 24),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: scan.isLoading
                    ? _Reading(soft: soft)
                    : _Actions(controller: controller),
              ),
              if (scan.hasError) ...[
                const SizedBox(height: 16),
                Card(
                  color: scheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Could not read that photo. Try again with better '
                      'light.\n\n${scan.error}',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Text('For a clean scan', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      _Tip(
                        Icons.light_mode_outlined,
                        'Use good light and avoid glare',
                      ),
                      _Tip(
                        Icons.crop_free,
                        'Keep the whole receipt in the frame',
                      ),
                      _Tip(
                        Icons.straighten,
                        'Lay it flat so the text is straight',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.controller});

  final ScanController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Brand.deep,
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: () => controller.scan(ImageSource.camera),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Take photo'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: () => controller.scan(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choose from gallery'),
        ),
      ],
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({required this.soft});

  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Reading text…',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text('This happens on your phone.', style: TextStyle(color: soft)),
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
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: primary.withValues(alpha: 0.12),
            child: Icon(icon, size: 18, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
