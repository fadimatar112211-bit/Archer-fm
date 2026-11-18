import 'dart:io';

import 'package:archer_fm/game/net/hotspot_service.dart';
import 'package:archer_fm/game/net/lobby_screen.dart';
import 'package:archer_fm/game/social/account_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual evidence for the online/hotspot step: the Arabic pre-match lobby
/// with a signed-in profile, the four heroes and the confirmed durations.
void main() {
  testWidgets('captures the online and hotspot lobby', (tester) async {
    final socialStore = MemorySocialStore();
    final social = SocialService(store: socialStore);
    await social.signIn('Lina', 'pw');

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0B1A10),
          ),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: LobbyScreen(
              socialService: social,
              pendingResults: PendingResultStore(store: MemorySocialStore()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/online_lobby.png'),
    );

    final baseline = File('test/goldens/online_lobby.png').readAsBytesSync();
    final dir = Directory('/tmp/opencode/merge/captures');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('${dir.path}/36_online_lobby.png').writeAsBytesSync(baseline);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
