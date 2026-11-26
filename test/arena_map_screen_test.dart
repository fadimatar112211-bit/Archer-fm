import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/arena/arena_map_screen.dart';

void main() {
  testWidgets('arena map preview opens and renders the four-player arena', (tester) async {
    await tester.view.setPhysicalSize(const Size(900, 600));
    await tester.view.setDevicePixelRatio(1);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ArenaMapScreen()));
    expect(find.text('ساحة المعركة · ٤ لاعبين'), findsOneWidget);
    expect(find.textContaining('٢٨ بلورة'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
