import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/settings.dart';
import 'package:archer_fm/game/settings_screen.dart';

void main() {
  group('control settings model', () {
    test('defaults keep movement left and attacks right', () {
      const s = GameSettings();
      expect(s.controlSide, ControlSide.right);
      expect(s.controlScale, 1.0);
      expect(s.joystickScale, 1.0);
      expect(s.verticalOffset, 0.0);
    });

    test('round trip through json preserves every field', () {
      const s = GameSettings(
        controlScale: 1.4,
        joystickScale: 0.8,
        controlSide: ControlSide.left,
        verticalOffset: 40,
      );
      final restored = GameSettings.fromJson(s.toJson());
      expect(restored.controlScale, closeTo(1.4, 1e-9));
      expect(restored.joystickScale, closeTo(0.8, 1e-9));
      expect(restored.controlSide, ControlSide.left);
      expect(restored.verticalOffset, closeTo(40, 1e-9));
    });

    test('stray saved values are clamped to a safe on-screen range', () {
      final s = GameSettings.fromJson({
        'controlScale': 99,
        'joystickScale': -5,
        'verticalOffset': 9999,
        'controlSide': 'garbage',
      });
      expect(s.controlScale, GameSettings.maxScale);
      expect(s.joystickScale, GameSettings.minScale);
      expect(s.verticalOffset, GameSettings.maxVerticalOffset);
      expect(s.controlSide, ControlSide.right);
    });
  });

  group('settings screen', () {
    testWidgets('changing size and side saves and resizes the preview',
        (tester) async {
      final store = MemorySettingsStore();
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SettingsScreen(store: store),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('control_scale')), findsOneWidget);
      expect(find.byKey(const ValueKey('joystick_scale')), findsOneWidget);
      expect(find.byKey(const ValueKey('control_side')), findsOneWidget);
      expect(find.byKey(const ValueKey('vertical_offset')), findsOneWidget);
      expect(find.text('إعدادات التحكم'), findsOneWidget);

      final before = tester.getSize(
          find.byKey(const ValueKey('preview_attack')));

      // Drive the slider callback directly (RTL reverses the visual ends).
      tester.widget<Slider>(find.byKey(const ValueKey('control_scale')))
          .onChanged!(GameSettings.maxScale);
      await tester.pumpAndSettle();

      final saved = await store.load();
      expect(saved.controlScale, closeTo(GameSettings.maxScale, 1e-9));

      final after = tester.getSize(
          find.byKey(const ValueKey('preview_attack')));
      expect(after.width, greaterThan(before.width));

      // Swap the attack cluster to the left side.
      await tester.tap(find.text('يسار'));
      await tester.pumpAndSettle();
      final swapped = await store.load();
      expect(swapped.controlSide, ControlSide.left);
    });

    testWidgets('reset restores the confirmed default layout', (tester) async {
      final store = MemorySettingsStore(const GameSettings(
        controlScale: 1.5,
        controlSide: ControlSide.left,
      ));
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SettingsScreen(store: store),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('reset_controls')),
        300,
      );
      await tester.tap(find.byKey(const ValueKey('reset_controls')));
      await tester.pumpAndSettle();
      final saved = await store.load();
      expect(saved.controlScale, 1.0);
      expect(saved.controlSide, ControlSide.right);
    });
  });
}
