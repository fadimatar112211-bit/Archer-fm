import 'package:archer_fm/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ArcherFmApp boots into the arena map screen', (tester) async {
    await tester.pumpWidget(const ArcherFmApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.textContaining('Archer FM Arena'), findsOneWidget);
    expect(find.text('هجوم'), findsOneWidget);
  });
}
