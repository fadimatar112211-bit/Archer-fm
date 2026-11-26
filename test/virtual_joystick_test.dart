import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/controls/virtual_joystick.dart';

void main() {
  testWidgets('sends normalized movement and zero when released', (tester) async {
    final sent = <Offset>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: VirtualJoystick(
            onMove: (direction) {
              sent.add(direction);
              return true;
            },
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(VirtualJoystick));
    final gesture = await tester.startGesture(center);
    await gesture.moveTo(center + const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 80));

    expect(sent, isNotEmpty);
    expect(sent.last.dx, closeTo(1, 0.02));
    expect(sent.last.dy, closeTo(0, 0.02));

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 80));
    expect(sent.last, Offset.zero);
  });

  testWidgets('retries direction when transport rejects it', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: VirtualJoystick(
            onMove: (_) {
              attempts++;
              return false;
            },
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(VirtualJoystick));
    final gesture = await tester.startGesture(center);
    await gesture.moveTo(center + const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 220));
    expect(attempts, greaterThan(1));
    await gesture.up();
  });

  testWidgets('exposes an Arabic movement hint and stops on disposal', (
    tester,
  ) async {
    final sent = <Offset>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: VirtualJoystick(
          onMove: (direction) {
            sent.add(direction);
            return true;
          },
        ),
      ),
    );

    expect(find.bySemanticsLabel('عصا الحركة'), findsOneWidget);
    final center = tester.getCenter(find.byType(VirtualJoystick));
    final gesture = await tester.startGesture(center);
    await gesture.moveTo(center + const Offset(70, 0));
    await tester.pump(const Duration(milliseconds: 80));
    expect(sent.last, isNot(Offset.zero));

    await tester.pumpWidget(const SizedBox.shrink());
    expect(sent.last, Offset.zero);
    await gesture.cancel();
  });


  testWidgets('exposes accessible directional movement and stop actions', (
    tester,
  ) async {
    final sent = <Offset>[];
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: VirtualJoystick(
          onMove: (direction) {
            sent.add(direction);
            return true;
          },
        ),
      ),
    );

    final data = tester
        .getSemantics(find.byType(VirtualJoystick))
        .getSemanticsData();
      expect(data.customSemanticsActionIds, hasLength(5));
      expect(sent, isEmpty);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('movement sensitivity scales the input vector before normalization', (
    tester,
  ) async {
    final sent = <Offset>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: VirtualJoystick(
            sensitivity: 0.5,
            onMove: (direction) {
              sent.add(direction);
              return true;
            },
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(VirtualJoystick));
    final gesture = await tester.startGesture(center);
    await gesture.moveTo(center + const Offset(50, 0));
    await tester.pump(const Duration(milliseconds: 80));

    expect(sent, isNotEmpty);
    expect(sent.last.dx, closeTo(0.4167, 0.02));
    expect(sent.last.dy, closeTo(0, 0.02));
    await gesture.up();
  });

}
