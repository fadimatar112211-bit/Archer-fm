import 'dart:convert';
import 'dart:io';

import 'package:archer_fm/game/network/authoritative_match_session.dart';
import 'package:archer_fm/game/network/match_combat_configuration.dart';
import 'package:archer_fm/game/network/websocket_game_host.dart';

/// Local development gateway only. It has no TLS or account authentication
/// and must not be exposed to the public internet.
///
/// All combat values are mandatory input from a reviewed JSON file. This
/// server intentionally refuses to start with an unconfigured lobby-only
/// session, which previously acknowledged matches that could not fight.
Future<void> main() async {
  final configPath = Platform.environment['ARCHER_FM_COMBAT_CONFIG'];
  if (configPath == null || configPath.trim().isEmpty) {
    stderr.writeln(
      'Missing ARCHER_FM_COMBAT_CONFIG. Provide a reviewed combat JSON file; '
      'no monster prices, stats or projectile values are invented by this tool.',
    );
    exitCode = 64;
    return;
  }

  final configFile = File(configPath);
  if (!await configFile.exists()) {
    stderr.writeln('Combat configuration file not found: $configPath');
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
    stderr.writeln('Invalid Archer FM combat configuration: $error');
    exitCode = 65;
    return;
  } on ArgumentError catch (error) {
    stderr.writeln('Invalid Archer FM combat configuration: $error');
    exitCode = 65;
    return;
  }

  final port = int.tryParse(Platform.environment['ARCHER_FM_PORT'] ?? '') ?? 8080;
  final bindAddress = InternetAddress.tryParse(
        Platform.environment['ARCHER_FM_BIND_ADDRESS'] ?? '127.0.0.1',
      ) ??
      InternetAddress.loopbackIPv4;

  final host = WebSocketGameHost(
    address: bindAddress,
    port: port,
    sessionFactory: AuthoritativeMatchSession.configuredFactory(
      combatConfiguration: combatConfiguration,
    ),
  );

  await host.start();
  stdout.writeln('Archer FM development match gateway: ${host.uri}');
  stdout.writeln('Combat configuration loaded from: $configPath');
  stdout.writeln('WARNING: development transport only; no TLS or account auth.');

  await ProcessSignal.sigint.watch().first;
  await host.close();
}
