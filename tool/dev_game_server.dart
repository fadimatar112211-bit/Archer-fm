import 'dart:io';

import 'package:archer_fm/game/network/authoritative_match_session.dart';
import 'package:archer_fm/game/network/websocket_game_host.dart';

/// Local development gateway only. It has no TLS or account authentication
/// and must not be exposed to the public internet.
Future<void> main() async {
  final port = int.tryParse(Platform.environment['ARCHER_FM_PORT'] ?? '') ?? 8080;
  final bindAddress = InternetAddress.tryParse(
        Platform.environment['ARCHER_FM_BIND_ADDRESS'] ?? '127.0.0.1',
      ) ??
      InternetAddress.loopbackIPv4;

  final host = WebSocketGameHost(
    address: bindAddress,
    port: port,
    sessionFactory: AuthoritativeMatchSession.fromCreateMessage,
  );

  await host.start();
  stdout.writeln('Archer FM development match gateway: ${host.uri}');
  stdout.writeln('WARNING: development transport only; no TLS or account auth.');

  await ProcessSignal.sigint.watch().first;
  await host.close();
}
