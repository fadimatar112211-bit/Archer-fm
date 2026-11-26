import 'package:archer_fm/game/match/hero_armory_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('armory shows canonical weapons and separate Ultimate unlocks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: HeroArmoryScreen()),
    );

    expect(find.text('ترسانة الأبطال'), findsOneWidget);
    expect(find.text('قوس الطاقة الخضراء'), findsOneWidget);
    expect(find.text('قوس الصقر'), findsOneWidget);
    expect(find.text('قوس الشفق المزدوج'), findsOneWidget);
    expect(find.text('وابل النجوم'), findsOneWidget);
    expect(find.text('السهم الثاقب'), findsOneWidget);
    expect(find.text('حارس الغابة'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('القنص الأسطوري'), findsOneWidget);
    expect(find.textContaining('خمس ضربات متتابعة مستقلة'), findsOneWidget);

    await tester.tap(find.text('فارس اللهب'));
    await tester.pump();

    expect(find.text('سيف اللهب العظيم'), findsOneWidget);
    expect(find.text('مذنب اللهب'), findsOneWidget);
    expect(find.text('وابل النجوم'), findsNothing);
  });
}
