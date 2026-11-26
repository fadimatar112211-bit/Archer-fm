import 'package:archer_fm/game/match/match_loadout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Arabic match setup shows all four heroes and four unit types',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MatchLoadoutScreen(),
        ),
      ),
    );

    expect(find.text('تجهيز المباراة'), findsOneWidget);
    expect(find.text('الرامي'), findsOneWidget);
    expect(find.text('فارس اللهب'), findsOneWidget);
    expect(find.text('ظل الليل'), findsOneWidget);
    expect(find.text('حامل العاصفة'), findsOneWidget);
    expect(find.text('عدّاء'), findsOneWidget);
    expect(find.text('مدرّع'), findsOneWidget);
    expect(find.text('متسلّل'), findsOneWidget);
    expect(find.text('رامٍ'), findsOneWidget);
    expect(find.text('20 / 20'), findsOneWidget);
    expect(find.text('runner'), findsNothing);
    expect(find.text('tank'), findsNothing);
    expect(find.text('stalker'), findsNothing);
    expect(find.text('ranged'), findsNothing);
  });

  testWidgets('army selector never allows more than twenty starting units',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: MatchLoadoutScreen()),
    );

    final runnerRow = find.ancestor(
      of: find.text('عدّاء'),
      matching: find.byType(ListTile),
    );
    final minus = find.descendant(
      of: runnerRow,
      matching: find.byIcon(Icons.remove_circle_outline),
    );
    await tester.tap(minus);
    await tester.pump();

    expect(find.text('19 / 20'), findsOneWidget);
    final plus = find.descendant(
      of: runnerRow,
      matching: find.byIcon(Icons.add_circle_outline),
    );
    await tester.tap(plus);
    await tester.pump();

    expect(find.text('20 / 20'), findsOneWidget);
    expect(find.text('تأكيد التشكيلة وإرسالها'), findsOneWidget);
  });

  testWidgets('connection validates server address before opening a socket',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: MatchLoadoutScreen()),
    );

    await tester.tap(find.text('إنشاء غرفة'));
    await tester.pump();

    expect(
      find.text('أدخل عنوان خادم يبدأ بـ ws:// أو wss://'),
      findsOneWidget,
    );
    expect(find.text('جارٍ انتظار رد الخادم…'), findsNothing);
  });


  testWidgets('match setup remains scrollable on a short landscape display',
      (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MatchLoadoutScreen(),
        ),
      ),
    );

    expect(find.text('تجهيز المباراة'), findsOneWidget);
    expect(find.text('الاتصال بالغرفة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final scrollable = find.byType(Scrollable);
    expect(scrollable, findsWidgets);
  });


  testWidgets('setup remains scrollable at three landscape aspect sizes',
      (tester) async {
    for (final size in [
      const Size(640, 360),
      const Size(1280, 540),
      const Size(1600, 720),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MatchLoadoutScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('تجهيز المباراة'), findsOneWidget);
      expect(find.text('الاتصال بالغرفة'), findsOneWidget);
      expect(find.byType(Scrollable), findsWidgets);
      expect(tester.takeException(), isNull,
          reason: 'No setup overflow at $size.');
    }
  });


}
