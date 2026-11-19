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

    debugPrint('SMOKE: mounting app');
    await tester.pumpWidget(const ArcherFmApp());
    debugPrint('SMOKE: app mounted');

    // Allow real asset bundle reads, GLB parsing and first-frame rendering.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.byKey(const ValueKey('home_3d_loaded')).evaluate().isNotEmpty) {
        break;
      }
    }

    debugPrint('SMOKE: home frame ready');
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

    debugPrint('SMOKE: opening army selection');
    await tester.tap(find.byKey(const ValueKey('home_play')));
    await tester.pump(const Duration(milliseconds: 500));

    debugPrint('SMOKE: army selection opened');
    expect(find.text('اختيار البطل والجيش'), findsOneWidget);
    expect(find.byKey(const ValueKey('army_total')), findsOneWidget);
    expect(find.text('الموزَّع: 20/20'), findsOneWidget);
    expect(find.byKey(const ValueKey('start_with_army')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_3d_loaded')), findsOneWidget);

    debugPrint('SMOKE: starting match');
    await tester.tap(find.byKey(const ValueKey('start_with_army')));
    debugPrint('SMOKE: start button tap returned');
    await tester.pump();
    expect(find.byKey(const ValueKey('joystick_zone')), findsOneWidget);
    expect(find.byKey(const ValueKey('btn_attack')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('btn_attack')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    debugPrint('SMOKE: arena controls verified');
    // Stop the live game ticker before the integration binding tears down.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    debugPrint('SMOKE: test cleanup complete');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
