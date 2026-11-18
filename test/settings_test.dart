import 'package:archer_fm/audio_service.dart';
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
      expect(s.musicEnabled, isTrue);
      expect(s.sfxEnabled, isTrue);
    });

    test('round trip through json preserves every field', () {
      const s = GameSettings(
        controlScale: 1.4,
        joystickScale: 0.8,
        controlSide: ControlSide.left,
        verticalOffset: 40,
        musicEnabled: false,
        sfxEnabled: false,
      );
      final restored = GameSettings.fromJson(s.toJson());
      expect(restored.controlScale, closeTo(1.4, 1e-9));
      expect(restored.joystickScale, closeTo(0.8, 1e-9));
      expect(restored.controlSide, ControlSide.left);
      expect(restored.verticalOffset, closeTo(40, 1e-9));
      expect(restored.musicEnabled, isFalse);
      expect(restored.sfxEnabled, isFalse);
    });

    test('stray saved values are clamped to a safe on-screen range', () {
      final s = GameSettings.fromJson({
        'controlScale': 99,
        'joystickScale': -5,
        'verticalOffset': 9999,
        'controlSide': 'garbage',
        'musicEnabled': 'not a bool',
        'sfxEnabled': 42,
      });
      expect(s.controlScale, GameSettings.maxScale);
      expect(s.joystickScale, GameSettings.minScale);
      expect(s.verticalOffset, GameSettings.maxVerticalOffset);
      expect(s.controlSide, ControlSide.right);
      expect(s.musicEnabled, isTrue);
      expect(s.sfxEnabled, isTrue);
    });
  });

  group('settings screen', () {
    testWidgets('changing size and side saves and resizes the preview',
        (tester) async {
      final store = MemorySettingsStore();
      // Landscape phone size: all six cards are built at once, so the test
      // can address each control without driving the scroll view.
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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

      // Drive the slider callback directly (RTL reverses the visual ends).
      tester.widget<Slider>(find.byKey(const ValueKey('control_scale')))
          .onChanged!(GameSettings.maxScale);
      await tester.pumpAndSettle();

      final saved = await store.load();
      expect(saved.controlScale, closeTo(GameSettings.maxScale, 1e-9));

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
      expect(saved.musicEnabled, isTrue);
      expect(saved.sfxEnabled, isTrue);
    });

    testWidgets('music and effects toggles save and update audio independently',
        (tester) async {
      final store = MemorySettingsStore();
      final audio = RecordingAudioService();
      await tester.pumpWidget(MaterialApp(
        home: AudioScope(
          service: audio,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SettingsScreen(store: store),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('toggle_music')),
        300,
      );
      expect(find.byKey(const ValueKey('toggle_music')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('toggle_sfx')),
        300,
      );
      expect(find.byKey(const ValueKey('toggle_sfx')), findsOneWidget);

      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('toggle_music')))
          .onChanged!(false);
      await tester.pumpAndSettle();
      expect(audio.musicEnabled, isFalse);
      expect(audio.sfxEnabled, isTrue);
      expect((await store.load()).musicEnabled, isFalse);
      expect((await store.load()).sfxEnabled, isTrue);

      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('toggle_sfx')))
          .onChanged!(false);
      await tester.pumpAndSettle();
      expect(audio.musicEnabled, isFalse);
      expect(audio.sfxEnabled, isFalse);
      expect((await store.load()).sfxEnabled, isFalse);
    });
  });
}
