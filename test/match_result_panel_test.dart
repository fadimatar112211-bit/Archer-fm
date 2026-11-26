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
          onReturnHome: () => returnedHome = true,
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

    expect(find.text('الفائز: اللاعب p2'), findsOneWidget);
    expect(find.textContaining('انتهى وقت المباراة'), findsOneWidget);
    expect(find.textContaining('اللاعب p2 (أنت)'), findsOneWidget);
    expect(find.text('النقاط 120'), findsOneWidget);
    expect(find.text('البلورات 5/7'), findsOneWidget);
    expect(find.text('العودة للقائمة الرئيسية'), findsOneWidget);
    await tester.tap(find.text('العودة للقائمة الرئيسية'));
    expect(returnedHome, isTrue);
  });

  testWidgets('shows a tie and crystal victory reason without inventing a winner', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
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

    expect(find.text('تعادل بين: اللاعب p1، اللاعب p4'), findsOneWidget);
    expect(find.textContaining('ببقاء بلورات لاعب واحد'), findsOneWidget);
    expect(find.text('الفائز: اللاعب p1'), findsNothing);
  });
}
