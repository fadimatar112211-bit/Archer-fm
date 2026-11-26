import 'dart:convert';
import 'dart:io';

import 'package:archer_fm/game/network/authoritative_match_session.dart';
import 'package:archer_fm/game/network/match_combat_configuration.dart';
import 'package:archer_fm/game/network/match_combat_authority.dart';
import 'package:archer_fm/game/network/supabase_access_token_verifier.dart';
import 'package:archer_fm/game/network/websocket_game_host.dart';

/// Production-oriented gateway entry point.
///
/// Run behind a trusted TLS reverse proxy that exposes WSS publicly and
/// forwards WebSocket upgrades to this loopback-only HTTP listener. The
/// Supabase access token is verified on every create/join/resume handshake.
/// Never expose this internal listener directly to the public internet.
Future<void> main() async {
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final supabaseAnonKey = Platform.environment['SUPABASE_ANON_KEY'];
  final configPath = Platform.environment['ARCHER_FM_COMBAT_CONFIG'];
  if (supabaseUrl == null ||
      supabaseUrl.trim().isEmpty ||
      supabaseAnonKey == null ||
      supabaseAnonKey.trim().isEmpty ||
      configPath == null ||
      configPath.trim().isEmpty) {
    stderr.writeln(
      'SUPABASE_URL, SUPABASE_ANON_KEY and ARCHER_FM_COMBAT_CONFIG are required.',
    );
    exitCode = 64;
    return;
  }

  final configFile = File(configPath);
  if (!await configFile.exists()) {
    stderr.writeln('Combat configuration file not found.');
    exitCode = 66;
    return;
  }

  late final MatchCombatConfiguration combatConfiguration;
  try {
    final decoded = jsonDecode(await configFile.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Root JSON value must be an object.');
    }
    combatConfiguration = decodeMatchCombatConfiguration(decoded);
  } on FormatException catch (error) {
    stderr.writeln('Invalid combat configuration: $error');
    exitCode = 65;
    return;
  } on ArgumentError catch (error) {
    stderr.writeln('Invalid combat configuration: $error');
    exitCode = 65;
    return;
  }

  final bindAddress = InternetAddress.tryParse(
        Platform.environment['ARCHER_FM_BIND_ADDRESS'] ?? '127.0.0.1',
      ) ??
      InternetAddress.loopbackIPv4;
  if (!bindAddress.isLoopback) {
    stderr.writeln('Production gateway must bind to loopback behind a TLS proxy.');
    exitCode = 64;
    return;
  }

  final port = int.tryParse(Platform.environment['ARCHER_FM_PORT'] ?? '') ?? 8080;
  final verifier = SupabaseAccessTokenVerifier(
    supabaseUrl: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  final host = WebSocketGameHost(
    address: bindAddress,
    port: port,
    accessTokenVerifier: verifier.verify,
    sessionFactory: AuthoritativeMatchSession.configuredFactory(
      combatConfiguration: combatConfiguration,
    ),
  );

  try {
    await host.start();
    stdout.writeln('Archer FM authenticated internal gateway: ${host.uri}');
    stdout.writeln('Public clients must connect through the configured WSS proxy.');
    await Future.any([
      ProcessSignal.sigint.watch().first,
      ProcessSignal.sigterm.watch().first,
    ]);
  } finally {
    await host.close();
    verifier.close();
  }
}
