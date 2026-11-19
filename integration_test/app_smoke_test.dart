import 'package:archer_fm/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android launches in landscape and opens the match setup', (
    tester,
  ) async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await tester.pumpWidget(const ArcherFmApp());

    // Allow real asset bundle reads, GLB parsing and first-frame rendering.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.byKey(const ValueKey('home_play')).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('ARCHER FM'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_play')), findsOneWidget);

    final media = MediaQuery.of(
      tester.element(find.byKey(const ValueKey('home_play'))),
    );
    expect(
      media.size.width,
      greaterThan(media.size.height),
      reason: 'The Android app must honor its landscape orientation lock.',
    );

    await tester.tap(find.byKey(const ValueKey('home_play')));
    await tester.pumpAndSettle();

    expect(find.text('اختيار البطل والجيش'), findsOneWidget);
    expect(find.byKey(const ValueKey('army_total')), findsOneWidget);
    expect(find.text('الموزَّع: 20/20'), findsOneWidget);
    expect(find.byKey(const ValueKey('start_with_army')), findsOneWidget);
  });
}
