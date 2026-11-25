import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:receipt_lens/shared/glass.dart';

void main() {
  testWidgets('GlassCard blurs what is behind it by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GlassCard(child: Text('hello'))),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('GlassCard is a solid panel in high-contrast mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: true),
          child: child!,
        ),
        home: const Scaffold(body: GlassCard(child: Text('hello'))),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
