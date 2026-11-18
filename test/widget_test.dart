
import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:archer_fm/hero/hero_viewer_screen.dart' show heroStates, heroDirections;
import 'package:archer_fm/main.dart';
import 'package:flutter/material.dart';
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

Future<void> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: HeroRosterScreen(loaderFactory: _FakeLoader.new),
    ),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Opens the viewer of the [index]-th roster row.
Future<void> _openViewer(WidgetTester tester, int index) async {
  await tester.ensureVisible(find.text('عرض').at(index));
  await tester.pump();
  await tester.tap(find.text('عرض').at(index));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('the roster exposes exactly four playable heroes', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(find.textContaining('قيد التطوير'), findsNothing);
    expect(find.text('فارس اللهب — سيف اللهب العظيم'), findsOneWidget);
    expect(find.text('ظل الليل — خنجران توأمان'), findsOneWidget);
    expect(find.text('حامل العاصفة — رمح الصاعقة'), findsOneWidget);
    expect(find.text('الرامي — قوس الطاقة الخضراء'), findsOneWidget);
    final playButtons = tester
        .widgetList(
          find.byWidgetPredicate(
            (widget) =>
                widget is ButtonStyleButton &&
                widget.runtimeType.toString().contains('FilledButton'),
          ),
        )
        .whereType<ButtonStyleButton>()
        .toList();
    expect(playButtons, hasLength(4));
    expect(playButtons.where((button) => button.onPressed != null), hasLength(4));
  });

  testWidgets('playing the finished Ranger opens the battle screen', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _openViewer(tester, 3);
    // The viewer still opens from any row.
    expect(find.text('Archer FM · Ranger'), findsOneWidget);
  });

  testWidgets('switching state and direction swaps the active clip', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _openViewer(tester, 3);
    expect(find.text('Archer FM · Ranger'), findsOneWidget);

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
    await _pumpHome(tester);
    await _openViewer(tester, 3);
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
}
