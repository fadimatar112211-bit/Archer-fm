import 'dart:ui' show Size;

import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_stage.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:archer_fm/hero/hero_viewer_screen.dart';
import 'package:archer_fm/main.dart';
import 'package:flutter/widgets.dart' show CustomPaint;
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fakeManifest(String heroId) {
  final animations = <String, dynamic>{};
  for (final state in heroStates) {
    for (final direction in heroDirections) {
      final name = '${state}_$direction';
      animations[name] = {
        'loop': state == 'idle' || state == 'walk' || state == 'run',
        'frame_duration_ms': 100,
        'frames': ['$name#0', '$name#1'],
        'events': <Map<String, dynamic>>[],
      };
    }
  }
  return {
    'hero_id': heroId,
    'frame_size': {'width': 192, 'height': 192},
    'pivot': {'x': 0.5, 'y': 0.86},
    'source': {'fps': 12},
    'atlases': [
      {
        'animation': 'idle_s',
        'image': 'atlases/idle_s.png',
        'meta': 'atlases/idle_s.json',
      },
    ],
    'animations': animations,
  };
}

class _FakeLoader extends HeroAssetLoader {
  _FakeLoader(this.hero);

  final HeroDefinition hero;

  @override
  String get heroId => hero.id;

  @override
  Future<HeroManifest> loadManifest() async =>
      HeroManifest.fromJson(_fakeManifest(hero.id));

  @override
  Future<AtlasSheet> loadSheet(HeroManifest manifest, String animation) async {
    throw UnsupportedError('no bitmap in widget test');
  }
}

Future<void> _pumpLoaded(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ArcherFmApp(loaderFactory: _FakeLoader.new));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('app starts on the Ranger idle animation with all controls', (
    tester,
  ) async {
    await _pumpLoaded(tester);
    expect(find.text('Archer FM · Ranger'), findsOneWidget);
    expect(find.text('64 حركة'), findsOneWidget);
    for (final label in ['وقوف', 'هجوم', 'مهارة', 'تفادي', 'موت']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('idle_s'), findsOneWidget);
    expect(find.text('الرامي المتوازن'), findsWidgets);
  });

  testWidgets('switching state and direction swaps the active clip', (
    tester,
  ) async {
    await _pumpLoaded(tester);
    await tester.ensureVisible(find.text('هجوم'));
    await tester.pump();
    await tester.tap(find.text('هجوم'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.textContaining('attack_s'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('شرق'));
    await tester.pump();
    await tester.tap(find.byTooltip('شرق'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.textContaining('attack_e'), findsOneWidget);
  });

  testWidgets('the hero picker switches to another hero and reloads it', (
    tester,
  ) async {
    await _pumpLoaded(tester);
    expect(find.text('Archer FM · Ranger'), findsOneWidget);

    await tester.ensureVisible(find.text('Flame'));
    await tester.pump();
    await tester.tap(find.text('Flame'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('Archer FM · Flame'), findsOneWidget);
    expect(find.textContaining('idle_s'), findsOneWidget);
    expect(find.text('فارس اللهب · قريب المدى · إلحاق ضرر'), findsOneWidget);
  });
  testWidgets('the production Ranger atlas is loaded and painted', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ArcherFmApp());
    // Let the real asset bundle load the manifest, atlas metadata and PNG,
    // while the animation ticker advances through a few idle frames.
    HeroStagePainter? painter;
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      final stagePaint = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((widget) => widget.painter is HeroStagePainter)
          .firstOrNull;
      painter = stagePaint?.painter as HeroStagePainter?;
      if (painter?.sheet != null) break;
    }

    expect(find.text('Archer FM · Ranger'), findsOneWidget);
    expect(find.text('64 حركة'), findsOneWidget);
    expect(painter, isNotNull);
    expect(painter!.sheet, isNotNull, reason: painter.placeholder);
    expect(painter.frameId, startsWith('ranger_idle_s_'));
    expect(painter.sheet!.rectFor(painter.frameId!), isNotNull);
    expect(painter.sheet!.width, greaterThan(0));
    expect(painter.sheet!.height, greaterThan(0));
    expect(find.textContaining('تعذّر تحميل صورة الحركة'), findsNothing);
    expect(find.text('أصول هذا البطل قيد الإنتاج'), findsNothing);
  });

}
