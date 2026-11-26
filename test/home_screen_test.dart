import 'package:archer_fm/main.dart';
import 'package:archer_fm/game/feedback/game_feedback_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Arabic home hub opens match setup and keeps RTL labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ArcherFmApp());

    expect(find.text('آرتشر إف إم'), findsOneWidget);
    expect(find.text('اللعب بلا إعلانات'), findsOneWidget);
    expect(find.text('المباراة'), findsOneWidget);
    expect(find.text('الأبطال'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('ترسانة الأبطال'), findsOneWidget);

    await tester.tap(find.text('المباراة'));
    await tester.pumpAndSettle();

    expect(find.text('تجهيز المباراة'), findsOneWidget);
    expect(find.text('الاتصال بالغرفة'), findsOneWidget);
  });

  testWidgets('home hub opens the canonical armory', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ArcherFmApp());
    await tester.tap(find.text('ترسانة الأبطال'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('ترسانة الأبطال'), findsOneWidget);
    expect(find.text('قوس الطاقة الخضراء'), findsOneWidget);
  });

  testWidgets('settings expose a working haptics switch and no fake audio toggle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ArcherFmApp());
    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();

    expect(find.text('الاهتزاز'), findsOneWidget);
    expect(find.text('الصوت'), findsOneWidget);
    expect(
      find.text('لم يتم ربط ملفات الموسيقى والمؤثرات الصوتية بعد'),
      findsOneWidget,
    );
    expect(find.text('لا توجد إعلانات داخل اللعبة'), findsOneWidget);

    final toggle = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'الاهتزاز'),
    );
    expect(toggle.value, isTrue);
    await tester.tap(find.widgetWithText(SwitchListTile, 'الاهتزاز'));
    await tester.pump();
    final updated = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'الاهتزاز'),
    );
    expect(updated.value, isFalse);
    expect(GameFeedbackPreferences.hapticsEnabled, isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    final reopened = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'الاهتزاز'),
    );
    expect(reopened.value, isFalse);
    await tester.tap(find.widgetWithText(SwitchListTile, 'الاهتزاز'));
    await tester.pump();
    expect(GameFeedbackPreferences.hapticsEnabled, isTrue);
  });

  testWidgets('movement sensitivity setting updates the live shared preference', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    GameFeedbackPreferences.setMovementSensitivity(1.0);
    await tester.pumpWidget(const ArcherFmApp());
    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();

    expect(find.text('حساسية عصا الحركة'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 1.0);
    slider.onChanged!(1.4);
    await tester.pump();
    expect(GameFeedbackPreferences.movementSensitivity, 1.4);
    expect(find.text('140٪'), findsOneWidget);

    GameFeedbackPreferences.setMovementSensitivity(1.0);
  });

}
