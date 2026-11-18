import 'dart:ui' as ui;

import 'package:archer_fm/audio_service.dart';
import 'package:archer_fm/game/home_screen.dart';
import 'package:archer_fm/game/progress/hero_progress.dart';
import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MenuFakeLoader extends HeroAssetLoader {
  _MenuFakeLoader(this.hero);

  final HeroDefinition hero;

  @override
  String get heroId => hero.id;

  @override
  Future<HeroManifest> loadManifest() async => HeroManifest(
        heroId: hero.id,
        frameWidth: 192,
        frameHeight: 192,
        pivotX: 0.5,
        pivotY: 0.86,
        fps: 12,
        clips: const {},
        atlases: const [],
      );

  @override
  Future<AtlasSheet> loadSheet(HeroManifest manifest, String animation) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 192, 192),
      Paint()..color = const Color(0xFF62E86C),
    );
    final image = await recorder.endRecording().toImage(192, 192);
    return AtlasSheet(
      image: image,
      frames: const {},
      width: 192,
      height: 192,
    );
  }
}

void main() {
  Future<RecordingAudioService> pumpMenu(
    WidgetTester tester, {
    ProgressStore? store,
  }) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = RecordingAudioService();
    await tester.pumpWidget(MaterialApp(
      home: AudioScope(
        service: audio,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: MainMenuScreen(
            loaderFactory: _MenuFakeLoader.new,
            store: store,
            hero3dBytes: (hero) async => null,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return audio;
  }

  testWidgets('horizontal menu keeps a 3D hero centered with three swipe cards',
      (tester) async {
    await pumpMenu(tester);

    expect(find.byKey(const ValueKey('home_3d_hero')), findsOneWidget);
    final pageView = tester.widget<PageView>(
      find.byKey(const ValueKey('home_page_view')),
    );
    expect(pageView.controller?.initialPage, 1);
    expect(pageView.scrollDirection, Axis.horizontal);

    expect(find.byKey(const ValueKey('home_shop_page')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_heroes_page')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_progress_page')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_play')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_online')), findsOneWidget);
  });

  testWidgets('swiping left and right moves between the three cards',
      (tester) async {
    await pumpMenu(tester);
    final pageView = find.byKey(const ValueKey('home_page_view'));
    final controller = tester.widget<PageView>(pageView).controller!;

    // The viewport is 0.86 of 1280, so a full-width drag is needed to pass
    // the scroll threshold instead of snapping back to the same card.
    await tester.drag(pageView, const Offset(-900, 0));
    await tester.pumpAndSettle();
    final afterFirstSwipe = controller.page!;
    expect(afterFirstSwipe, isNot(closeTo(1, 0.05)));

    await tester.drag(pageView, const Offset(900, 0));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(1, 0.05));
  });

  testWidgets('choosing another hero updates the centered roster selection',
      (tester) async {
    await pumpMenu(tester);

    await tester.tap(find.byKey(const ValueKey('home_hero_chip_flame')));
    await tester.pumpAndSettle();

    final chip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('home_hero_chip_flame')),
    );
    expect(chip.selected, isTrue);
    expect(find.byKey(const ValueKey('home_3d_hero')), findsOneWidget);
  });

  testWidgets('play opens the pre-match hero/army/weapon screen',
      (tester) async {
    await pumpMenu(tester);

    await tester.tap(find.byKey(const ValueKey('home_play')));
    await tester.pumpAndSettle();

    expect(find.text('اختيار البطل والجيش'), findsOneWidget);
    expect(find.text('السلاح (واحد من ثلاثة)'), findsOneWidget);
  });

  testWidgets('the shop spends essence on a real saved hero upgrade',
      (tester) async {
    final store = MemoryProgressStore();
    final heroId = heroCatalog
        .firstWhere((h) => ['ranger_new', 'flame', 'shadow', 'storm'].contains(h.id))
        .id;
    await store.save(
      heroId,
      const HeroProgress(
        level: 1,
        xp: 0,
        kills: 0,
        essence: 500,
        materials: {'hero': 20, 'capacity': 20},
      ),
    );
    await pumpMenu(tester, store: store);

    // The shop is the first card; jump to it before tapping its button.
    tester
        .widget<PageView>(find.byKey(const ValueKey('home_page_view')))
        .controller!
        .jumpToPage(0);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home_shop_hero_upgrade')));
    await tester.pumpAndSettle();

    final saved = await store.load(heroId);
    expect(saved!.heroUpgradeLevel, 1);
    expect(saved.essence, 440);
  });

  testWidgets('menu starts its music and taps play a UI cue', (tester) async {
    final audio = await pumpMenu(tester);
    expect(audio.musicPlayed, [MusicTrack.menu]);

    await tester.tap(find.byKey(const ValueKey('home_play')));
    await tester.pumpAndSettle();
    expect(audio.cuesPlayed, contains(SoundCue.uiTap));
  });
}
