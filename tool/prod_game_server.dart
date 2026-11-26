import 'dart:convert';
import 'dart:io';

import 'package:archer_fm/game/network/authoritative_match_session.dart';
import 'package:archer_fm/game/network/match_combat_configuration.dart';
import 'package:archer_fm/game/network/match_combat_authority.dart';
import 'package:archer_fm/game/network/supabase_access_token_verifier.dart';
import 'package:archer_fm/game/network/supabase_rest_client.dart';
import 'package:archer_fm/game/network/supabase_match_settlement_store.dart';
import 'package:archer_fm/game/progression/supabase_hero_progress_store.dart';
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
  final serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  final rawRewardSchedule = Platform.environment['ARCHER_FM_MATCH_REWARDS_BY_RANK'];
  final configPath = Platform.environment['ARCHER_FM_COMBAT_CONFIG'];
  if (supabaseUrl == null ||
      supabaseUrl.trim().isEmpty ||
      supabaseAnonKey == null ||
      supabaseAnonKey.trim().isEmpty ||
      serviceRoleKey == null ||
      serviceRoleKey.trim().isEmpty ||
      configPath == null ||
      configPath.trim().isEmpty) {
    stderr.writeln(
      'SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY and ARCHER_FM_COMBAT_CONFIG are required.',
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
  late final List<int> rewardSchedule;
  try {
    rewardSchedule = _decodeRewardSchedule(rawRewardSchedule);
  } on FormatException catch (error) {
    stderr.writeln('Invalid match reward configuration: $error');
    exitCode = 65;
    return;
  }
  final persistenceClient = SupabaseRestClient(
    supabaseUrl: supabaseUrl,
    serviceRoleKey: serviceRoleKey,
  );
  final settlementStore = SupabaseMatchSettlementStore(persistenceClient);
  final heroProgressStore = SupabaseHeroProgressStore(persistenceClient);

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
      loadAccountHeroProgress: heroProgressStore.load,
      onMatchSettlement: ({
        required matchId,
        required accountId,
        required standing,
        required finishReason,
      }) async {
        final reward = rewardSchedule[standing.rank - 1];
        await settlementStore.finalizePlayer(
          matchId: matchId,
          verifiedUserId: accountId,
          placement: standing.rank,
          score: standing.score,
          crystalsRemaining: standing.livingCrystals,
          finishReason: finishReason.name,
          rewardAmount: reward,
          idempotencyKey: 'match:$matchId:user:$accountId:reward:v1',
        );
        heroProgressStore.invalidateRevision(accountId);
      },
      onMatchSettlementError: (error) {
        stderr.writeln('Match settlement pending retry: $error');
      },
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
    persistenceClient.close();
  }
}

List<int> _decodeRewardSchedule(String? raw) {
  if (raw == null || raw.trim().isEmpty) return List<int>.filled(4, 0);
  final decoded = jsonDecode(raw);
  if (decoded is! List ||
      decoded.length != 4 ||
      decoded.any((value) => value is! int || value < 0)) {
    throw const FormatException(
      'ARCHER_FM_MATCH_REWARDS_BY_RANK must be a JSON array of four non-negative integers.',
    );
  }
  return decoded.cast<int>();
}
