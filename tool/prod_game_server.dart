import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archer_fm/game/network/authoritative_match_session.dart';
import 'package:archer_fm/game/network/match_combat_configuration.dart';
import 'package:archer_fm/game/network/match_combat_authority.dart';
import 'package:archer_fm/game/network/supabase_access_token_verifier.dart';
import 'package:archer_fm/game/network/supabase_rest_client.dart';
import 'package:archer_fm/game/network/progression_purchase_service.dart';
import 'package:archer_fm/game/progression/progression_economy_configuration.dart';
import 'package:archer_fm/game/network/supabase_match_settlement_store.dart';
import 'package:archer_fm/game/network/file_match_settlement_outbox.dart';
import 'package:archer_fm/game/progression/supabase_hero_progress_store.dart';
import 'package:archer_fm/monsters/supabase_monster_progress_store.dart';
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
  final economyConfigPath = Platform.environment['ARCHER_FM_PROGRESSION_ECONOMY_CONFIG'];
  if (supabaseUrl == null ||
      supabaseUrl.trim().isEmpty ||
      supabaseAnonKey == null ||
      supabaseAnonKey.trim().isEmpty ||
      serviceRoleKey == null ||
      serviceRoleKey.trim().isEmpty ||
      configPath == null ||
      configPath.trim().isEmpty ||
      economyConfigPath == null ||
      economyConfigPath.trim().isEmpty) {
    stderr.writeln(
      'SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, ARCHER_FM_COMBAT_CONFIG and ARCHER_FM_PROGRESSION_ECONOMY_CONFIG are required.',
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
  final economyConfigFile = File(economyConfigPath);
  if (!await economyConfigFile.exists()) {
    stderr.writeln('Progression economy configuration file not found.');
    exitCode = 66;
    return;
  }

  late final ProgressionEconomyConfiguration progressionEconomy;
  try {
    final decoded = jsonDecode(await economyConfigFile.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Root JSON value must be an object.');
    }
    progressionEconomy = ProgressionEconomyConfiguration.fromJson(decoded);
  } on FormatException catch (error) {
    stderr.writeln('Invalid progression economy configuration: $error');
    exitCode = 65;
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
  final progressionPurchaseService = ProgressionPurchaseService(
    client: persistenceClient,
    economy: progressionEconomy,
  );
  final heroProgressStore = SupabaseHeroProgressStore(persistenceClient);
  final monsterProgressStore = SupabaseMonsterProgressStore(persistenceClient);
  final monsterProgressionPolicy = combatConfiguration.monsterProgressionPolicy;
  final loadAccountMonsterProgression = monsterProgressionPolicy == null
      ? null
      : (String accountId) async => monsterProgressionPolicy.restore(
            catalog: combatConfiguration.monsterCatalog,
            saveData: await monsterProgressStore.loadData(accountId),
          );
  final settlementOutbox = FileMatchSettlementOutbox(
    file: File(
      Platform.environment['ARCHER_FM_SETTLEMENT_OUTBOX_PATH'] ??
          '/var/lib/archer-fm/pending-match-settlements.json',
    ),
    deliver: (item) async {
      await settlementStore.finalizePlayer(
        matchId: item['matchId'] as String,
        verifiedUserId: item['accountId'] as String,
        placement: item['placement'] as int,
        score: item['score'] as int,
        crystalsRemaining: item['crystalsRemaining'] as int,
        finishReason: item['finishReason'] as String,
        rewardAmount: item['rewardAmount'] as int,
        idempotencyKey: item['idempotencyKey'] as String,
      );
      heroProgressStore.invalidateRevision(item['accountId'] as String);
    },
  );
  try {
    await settlementOutbox.load();
    await settlementOutbox.flushPending();
  } catch (error) {
    stderr.writeln('Existing match settlements remain queued for retry: $error');
  }
  final outboxRetryTimer = Timer.periodic(
    const Duration(seconds: 5),
    (_) {
      settlementOutbox.flushPending().catchError((Object error) {
        stderr.writeln('Persistent settlement outbox retry failed: $error');
      });
    },
  );

  final verifier = SupabaseAccessTokenVerifier(
    supabaseUrl: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  final host = WebSocketGameHost(
    address: bindAddress,
    port: port,
    accessTokenVerifier: verifier.verify,
    progressionPurchaseHandler: ({
      required trustedAccountId,
      required purchaseType,
      required targetId,
      required idempotencyKey,
      required quotedCost,
    }) => progressionPurchaseService.purchase(
      trustedAccountId: trustedAccountId,
      purchaseType: purchaseType,
      targetId: targetId,
      idempotencyKey: idempotencyKey,
      quotedCost: quotedCost,
    ),
    progressionCatalogHandler: ({
      required trustedAccountId,
    }) => progressionPurchaseService.catalog(trustedAccountId),
    sessionFactory: AuthoritativeMatchSession.configuredFactory(
      combatConfiguration: combatConfiguration,
      loadAccountHeroProgress: heroProgressStore.load,
      loadAccountMonsterProgression: loadAccountMonsterProgression,
      onMatchSettlement: ({
        required matchId,
        required accountId,
        required standing,
        required finishReason,
      }) async {
        final reward = rewardSchedule[standing.rank - 1];
        await settlementOutbox.enqueueAndFlush(
          matchId: matchId,
          accountId: accountId,
          placement: standing.rank,
          score: standing.score,
          crystalsRemaining: standing.livingCrystals,
          finishReason: finishReason.name,
          rewardAmount: reward,
          idempotencyKey: 'match:$matchId:user:$accountId:reward:v1',
        );
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
    outboxRetryTimer.cancel();
    try {
      await settlementOutbox.flushPending();
    } catch (error) {
      stderr.writeln('Pending settlements retained on disk during shutdown: $error');
    }
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
