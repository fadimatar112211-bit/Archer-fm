import 'package:archer_fm/game/match/match_result_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the authoritative winner and ranked final standings', (
    tester,
  ) async {
    var returnedHome = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MatchResultPanel(
          localPlayerId: 'p2',
          onReturnHome: () { returnedHome = true; },
          result: {
            'reason': 'timeExpired',
            'winnerId': 'p2',
            'tiedPlayerIds': [],
            'standings': [
              {
                'playerId': 'p2',
                'score': 120,
                'livingCrystals': 5,
                'rank': 1,
                'hasForfeited': false,
              },
              {
                'playerId': 'p1',
                'score': 90,
                'livingCrystals': 3,
                'rank': 2,
                'hasForfeited': false,
              },
            ],
          },
        ),
      ),
    );

    expect(find.text('الفائز: أنت'), findsOneWidget);
    expect(find.textContaining('انتهى وقت المباراة'), findsOneWidget);
    expect(find.text('أنت'), findsOneWidget);
    expect(find.text('النقاط 120'), findsOneWidget);
    expect(find.text('البلورات 5/7'), findsOneWidget);
    expect(find.text('العودة للقائمة الرئيسية'), findsOneWidget);
    await tester.tap(find.text('العودة للقائمة الرئيسية'));
    expect(returnedHome, isTrue);
  });

  testWidgets('announces the result panel as a named accessible region', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MatchResultPanel(
          localPlayerId: 'p1',
          onReturnHome: () {},
          result: {
            'reason': 'timeExpired',
            'winnerId': 'p1',
            'tiedPlayerIds': [],
            'standings': [
              {
                'playerId': 'p1',
                'rank': 1,
                'score': 120,
                'livingCrystals': 5,
                'hasForfeited': false,
              },
            ],
          },
        ),
      ),
    );

    expect(find.bySemanticsLabel('نتيجة المباراة'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'المركز 1، أنت، النقاط 120، البلورات 5 من 7',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows a tie and crystal victory reason without inventing a winner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MatchResultPanel(
          localPlayerId: 'p4',
          onReturnHome: () {},
          result: {
            'reason': 'lastCrystalHolder',
            'winnerId': null,
            'tiedPlayerIds': ['p1', 'p4'],
            'standings': [
              {
                'playerId': 'p1',
                'score': 100,
                'livingCrystals': 1,
                'rank': 1,
                'hasForfeited': false,
              },
              {
                'playerId': 'p4',
                'score': 100,
                'livingCrystals': 1,
                'rank': 1,
                'hasForfeited': false,
              },
            ],
          },
        ),
      ),
    );

    expect(find.text('تعادل بين: اللاعب 1، أنت'), findsOneWidget);
    expect(find.textContaining('ببقاء بلورات لاعب واحد'), findsOneWidget);
    expect(find.text('الفائز: اللاعب 1'), findsNothing);
  });
}
