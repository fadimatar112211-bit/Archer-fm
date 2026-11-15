import 'dart:ui' show Size;

import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:archer_fm/hero/hero_viewer_screen.dart';
import 'package:archer_fm/main.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fakeManifest() {
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
    'hero_id': 'ranger',
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
  @override
  Future<HeroManifest> loadManifest() async =>
      HeroManifest.fromJson(_fakeManifest());

  @override
  Future<AtlasSheet> loadSheet(HeroManifest manifest, String animation) async {
    throw UnsupportedError('no bitmap in widget test');
  }
}

Future<void> _pumpLoaded(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ArcherFmApp(loader: _FakeLoader()));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('app starts on the idle animation with all controls', (
    tester,
  ) async {
    await _pumpLoaded(tester);
    expect(find.text('Archer FM · Ranger'), findsOneWidget);
    expect(find.text('64 حركة'), findsOneWidget);
    for (final label in ['وقوف', 'هجوم', 'مهارة', 'تفادي', 'موت']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('idle_s'), findsOneWidget);
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
}
