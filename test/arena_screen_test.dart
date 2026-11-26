import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:archer_fm/arena/arena_screen.dart';

void main() {
  testWidgets('arena screen loads the packaged map', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ArenaScreen()));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Archer FM Arena'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
