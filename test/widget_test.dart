import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/main.dart';

void main() {
  testWidgets('app starts with Arabic hero pipeline screen', (tester) async {
    await tester.pumpWidget(const ArcherFmApp());
    expect(find.text('آرتشر إف إم — تجهيز عارض الأبطال'), findsOneWidget);
  });
}
