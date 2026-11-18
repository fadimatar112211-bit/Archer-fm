import 'package:archer_fm/game/net/hotspot_service.dart';
import 'package:archer_fm/game/net/lobby_screen.dart';
import 'package:archer_fm/game/net/online_match_server.dart';
import 'package:archer_fm/game/social/account_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hotspot result queue', () {
    test('results stay local and sync to the account once connectivity returns',
        () async {
      final socialStore = MemorySocialStore();
      final resultStore = MemorySocialStore();
      final social = SocialService(store: socialStore);
      final pending = PendingResultStore(store: resultStore);
      await social.signIn('lina', 'pw');

      await pending.save(
        PendingMatchRecord(
          id: 'm1',
          username: 'lina',
          won: false,
          kills: 3,
          score: 5,
          reason: 'timeUp',
          hotspot: true,
          createdAtMs: 1000,
        ),
      );
      expect(await pending.unsyncedCount(), 1);
      expect(social.current!.matches, 0);

      final applied = await pending.syncToAccount(social);
      expect(applied, 1);
      expect(social.current!.matches, 1);
      expect(social.current!.kills, 3);
      expect(await pending.unsyncedCount(), 0);

      // Re-syncing is idempotent: a result is applied only once.
      expect(await pending.syncToAccount(social), 0);
      expect(social.current!.matches, 1);
    });
  });

  group('hotspot hosting', () {
    test('a host binds a port and advertises local addresses', () async {
      final hotspot = HotspotService(
        port: 0,
        server: OnlineMatchServer(),
      );
      await hotspot.startHosting();
      expect(hotspot.hosting, isTrue);
      expect(hotspot.server.port, greaterThan(0));
      final addresses = await hotspot.hostAddresses();
      for (final address in addresses) {
        expect(address.isLoopback, isFalse);
      }
      await hotspot.stopHosting();
    });
  });

  group('lobby screen', () {
    testWidgets('shows accounts, four heroes and the five match lengths',
        (tester) async {
      final social = SocialService(store: MemorySocialStore());
      final pending = PendingResultStore(store: MemorySocialStore());
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: LobbyScreen(socialService: social, pendingResults: pending),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('lobby_signin')), findsOneWidget);
      expect(find.byKey(const ValueKey('lobby_hero_ranger_new')), findsOneWidget);
      expect(find.byKey(const ValueKey('lobby_hero_flame')), findsOneWidget);
      expect(find.byKey(const ValueKey('lobby_hero_shadow')), findsOneWidget);
      expect(find.byKey(const ValueKey('lobby_hero_storm')), findsOneWidget);
      for (final minutes in [10, 20, 30, 45, 60]) {
        expect(
          find.byKey(ValueKey('lobby_duration_$minutes')),
          findsOneWidget,
        );
      }
      // The connection section is lower in the lazy list; bring it into view.
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'أونلاين'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'هوتسبوت'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('lobby_username')),
        'Lina',
      );
      await tester.enterText(
        find.byKey(const ValueKey('lobby_password')),
        'pw',
      );
      await tester.tap(find.byKey(const ValueKey('lobby_signin')));
      await tester.pumpAndSettle();
      expect(social.currentUsername, 'lina');
      expect(find.text('Lina'), findsOneWidget);
    });
  });
}
