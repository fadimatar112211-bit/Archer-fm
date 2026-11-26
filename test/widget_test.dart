import 'package:archer_fm/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Hero3D viewer shows four heroes and movement controls', (tester) async {
    await tester.pumpWidget(const ArcherFmApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Archer FM'), findsOneWidget);
    expect(find.text('الرامي المتوازن'), findsWidgets);
    expect(find.text('فارس اللهب'), findsWidgets);
    expect(find.text('ظل الليل'), findsWidgets);
    expect(find.text('حامل العاصفة'), findsWidgets);

    expect(find.text('وقوف'), findsOneWidget);
    expect(find.text('جري'), findsOneWidget);
    expect(find.text('كومبو 1'), findsOneWidget);
    expect(find.text('كومبو 5'), findsOneWidget);
    expect(find.text('اندفاع'), findsOneWidget);
    expect(find.text('إصابة'), findsOneWidget);
    expect(find.text('موت'), findsOneWidget);
    expect(find.text('مهارة 1'), findsOneWidget);
    expect(find.text('مهارة 4'), findsOneWidget);
  });

  testWidgets('can switch hero and trigger movement', (tester) async {
    await tester.pumpWidget(const ArcherFmApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('فارس اللهب').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('فارس اللهب'), findsWidgets);

    await tester.tap(find.text('كومبو 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('كومبو 1'), findsWidgets);
  });
}
