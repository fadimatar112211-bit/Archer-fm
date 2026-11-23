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

    // The menu must remain interactive while the optional 3D hero preview
    // loads. This smoke test covers startup, orientation, setup navigation,
    // and mounting the production 3D hero renderer in the arena.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.byKey(const ValueKey('home_play')).evaluate().isNotEmpty) {
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
    // Allow the route transition to finish on slower software-rendered CI
    // emulators before asserting the destination app bar is mounted.
    await tester.pump(const Duration(milliseconds: 350));

    debugPrint('SMOKE: army selection opened');
    expect(find.text('اختيار البطل والجيش'), findsOneWidget);

    // The setup screen is a vertical ListView. Its lower army controls are
    // lazily built, so explicitly scroll them into view before finding them.
    final setupScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('army_total')),
      240,
      scrollable: setupScroll,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('army_total')), findsOneWidget);
    expect(find.text('الموزَّع: 20/20'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('start_with_army')),
      240,
      scrollable: setupScroll,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('start_with_army')), findsOneWidget);

    debugPrint('SMOKE: starting match');
    await tester.tap(find.byKey(const ValueKey('start_with_army')));
    debugPrint('SMOKE: start button tap returned');
    // MaterialPageRoute needs its transition to finish before the arena's
    // positioned controls are mounted. The game ticker never settles, so use
    // a bounded pump rather than pumpAndSettle().
    await tester.pump(const Duration(milliseconds: 400));
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
