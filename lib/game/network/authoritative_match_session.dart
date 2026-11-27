import 'dart:async';
import 'dart:math';
import 'dart:ui';

import '../heroes/hero_roster.dart';
import '../world/arena_map.dart';
import '../world/castle_system.dart';
import '../match/match_rules.dart';
import '../progression/hero_progress.dart';
import 'match_world_authority.dart';
import 'match_combat_authority.dart';
import '../../monsters/monster_models.dart';
import '../../monsters/monster_army.dart';
import '../../monsters/monster_progression.dart';
import 'websocket_game_host.dart';

typedef AccountHeroProgressLoader = Future<HeroProgress> Function(String accountId);
typedef AccountMonsterProgressionLoader =
    Future<MonsterProgression> Function(String accountId);

typedef MatchSettlementHandler = Future<void> Function({
  required String matchId,
  required String accountId,
  required MatchStanding standing,
  required MatchFinishReason finishReason,
});

/// Concrete four-player match session used by [WebSocketGameHost].
///
/// Client commands may choose a valid hero/loadout, start a full lobby, or
/// forfeit. Scores and crystal counts are updated only through trusted
/// server-side methods called by the authoritative combat/castle systems.
class AuthoritativeMatchSession
    implements PlayerScopedSnapshotSession, AccountBoundGameServerSession,
        AccountProvisioningGameServerSession {
  AuthoritativeMatchSession({
    required this.code,
    int durationMinutes = 30,
    Random? random,
    bool Function(String playerId, String weaponId)? canUseWeapon,
    int Function(String playerId, String heroId)? heroLevelForPlayer,
    int Function(String playerId, String weaponId)? weaponUpgradeLevelForPlayer,
    ArenaMap Function()? mapFactory,
    MatchCombatConfiguration? combatConfiguration,
    MatchSettlementHandler? onMatchSettlement,
    void Function(Object error)? onMatchSettlementError,
    AccountHeroProgressLoader? loadAccountHeroProgress,
    AccountMonsterProgressionLoader? loadAccountMonsterProgression,
  })  : _loadAccountHeroProgress = loadAccountHeroProgress,
        _loadAccountMonsterProgression = loadAccountMonsterProgression,
        _onMatchSettlement = onMatchSettlement,
        _onMatchSettlementError = onMatchSettlementError,
        _mapFactory = mapFactory,
        _combatConfiguration = combatConfiguration,
        duration = MatchDuration.fromMinutes(durationMinutes),
        _random = random ?? Random.secure(),
        _canUseWeapon = canUseWeapon,
        _heroLevelForPlayer = heroLevelForPlayer,
        _weaponUpgradeLevelForPlayer = weaponUpgradeLevelForPlayer;

  /// Creates the production-style room factory with an explicitly supplied
  /// approved combat catalog and tuning. No provisional balance is selected
  /// by the transport or this session.
  static GameServerSessionFactory configuredFactory({
    required MatchCombatConfiguration combatConfiguration,
    bool Function(String playerId, String weaponId)? canUseWeapon,
    int Function(String playerId, String heroId)? heroLevelForPlayer,
    int Function(String playerId, String weaponId)? weaponUpgradeLevelForPlayer,
    ArenaMap Function()? mapFactory,
    MatchSettlementHandler? onMatchSettlement,
    void Function(Object error)? onMatchSettlementError,
    AccountHeroProgressLoader? loadAccountHeroProgress,
    AccountMonsterProgressionLoader? loadAccountMonsterProgression,
  }) {
    return (roomCode, message) => AuthoritativeMatchSession.fromCreateMessage(
          roomCode,
          message,
          canUseWeapon: canUseWeapon,
          heroLevelForPlayer: heroLevelForPlayer,
          weaponUpgradeLevelForPlayer: weaponUpgradeLevelForPlayer,
          mapFactory: mapFactory,
          combatConfiguration: combatConfiguration,
          onMatchSettlement: onMatchSettlement,
          onMatchSettlementError: onMatchSettlementError,
          loadAccountHeroProgress: loadAccountHeroProgress,
          loadAccountMonsterProgression: loadAccountMonsterProgression,
        );
  }

  factory AuthoritativeMatchSession.fromCreateMessage(
    String roomCode,
    Map<String, dynamic> message, {
    bool Function(String playerId, String weaponId)? canUseWeapon,
    int Function(String playerId, String heroId)? heroLevelForPlayer,
    int Function(String playerId, String weaponId)? weaponUpgradeLevelForPlayer,
    ArenaMap Function()? mapFactory,
    MatchCombatConfiguration? combatConfiguration,
    MatchSettlementHandler? onMatchSettlement,
    void Function(Object error)? onMatchSettlementError,
    AccountHeroProgressLoader? loadAccountHeroProgress,
    AccountMonsterProgressionLoader? loadAccountMonsterProgression,
  }) {
    final requestedDuration = message['durationMinutes'];
    if (requestedDuration != null && requestedDuration is! int) {
      throw const FormatException('durationMinutes must be an integer.');
    }
    return AuthoritativeMatchSession(
      code: roomCode,
      durationMinutes: requestedDuration as int? ?? 30,
      canUseWeapon: canUseWeapon,
      heroLevelForPlayer: heroLevelForPlayer,
      weaponUpgradeLevelForPlayer: weaponUpgradeLevelForPlayer,
      mapFactory: mapFactory,
      combatConfiguration: combatConfiguration,
      onMatchSettlement: onMatchSettlement,
      onMatchSettlementError: onMatchSettlementError,
      loadAccountHeroProgress: loadAccountHeroProgress,
      loadAccountMonsterProgression: loadAccountMonsterProgression,
    );
  }

  @override
  final String code;
  late final String matchId = '$code-${_token()}';
  final MatchDuration duration;
  final ArenaMap Function()? _mapFactory;
  final MatchCombatConfiguration? _combatConfiguration;
  final AccountHeroProgressLoader? _loadAccountHeroProgress;
  final AccountMonsterProgressionLoader? _loadAccountMonsterProgression;
  final Map<String, HeroProgress> _accountHeroProgress = {};
  final Map<String, MonsterProgression> _accountMonsterProgression = {};
  final MatchSettlementHandler? _onMatchSettlement;
  final void Function(Object error)? _onMatchSettlementError;
  final Map<String, _PendingMatchSettlement> _pendingSettlements = {};
  bool _settlementInFlight = false;
  bool _settlementsQueued = false;
  Duration _settlementRetryElapsed = Duration.zero;
  MatchCombatAuthority? combat;
  MatchWorldAuthority? world;
  int _worldNowMs = 0;
  final Random _random;
  final bool Function(String playerId, String weaponId)? _canUseWeapon;
  /// Server-only lookup. The callback must resolve the authenticated account
  /// from trusted connection context; never accept account IDs from messages.
  final int Function(String playerId, String heroId)? _heroLevelForPlayer;
  /// Trusted account lookup; never populated from a client message.
  final int Function(String playerId, String weaponId)?
      _weaponUpgradeLevelForPlayer;
  final List<_MatchPlayer> _players = [];
  MatchRulesEngine? _rules;
  int _nextPlayerNumber = 1;

  @override
  Iterable<GameServerPlayer> get players => List.unmodifiable(_players);

  MatchRulesEngine? get rules => _rules;

  @override
  bool get shouldRemove =>
      _players.isEmpty ||
      (_rules?.phase == MatchPhase.finished &&
          _players.every((player) => !player.connected) &&
          _pendingSettlements.isEmpty &&
          !_settlementInFlight);

  @override
  GameServerPlayer? join() => _join(accountId: null);

  @override
  GameServerPlayer? joinForAccount(String accountId) {
    if (accountId.trim().isEmpty || accountId.length > 180) return null;
    return _join(accountId: accountId);
  }

  GameServerPlayer? _join({required String? accountId}) {
    if (_rules != null ||
        _players.length >= 4 ||
        (accountId != null &&
            _players.any((player) => player.accountId == accountId))) {
      return null;
    }
    final number = _nextPlayerNumber++;
    final player = _MatchPlayer(
      id: 'p$number',
      resumeToken: _token(),
      accountId: accountId,
    );
    _players.add(player);
    return player;
  }

  @override
  Future<void> prepareAccount(GameServerPlayer player, String accountId) async {
    final matchPlayer = _find(player.id);
    if (matchPlayer == null || matchPlayer.accountId != accountId) {
      throw StateError('Verified account does not own this match slot.');
    }
    if (!_accountHeroProgress.containsKey(player.id)) {
      final heroLoader = _loadAccountHeroProgress;
      if (heroLoader != null) {
        _accountHeroProgress[player.id] = await heroLoader(accountId);
      }
    }
    if (!_accountMonsterProgression.containsKey(player.id)) {
      final monsterLoader = _loadAccountMonsterProgression;
      if (monsterLoader != null) {
        _accountMonsterProgression[player.id] = await monsterLoader(accountId);
      }
    }
  }

  @override
  bool ownsResumeToken(String resumeToken, String accountId) {
    for (final player in _players) {
      if (player.resumeToken == resumeToken) {
        return player.accountId == accountId;
      }
    }
    return false;
  }

  @override
  GameServerPlayer? resume(String resumeToken) {
    for (final player in _players) {
      if (player.resumeToken == resumeToken) {
        // Rotate the bearer token on every successful resume. A captured
        // token can therefore be used only once, not replayed to hijack a
        // later connection.
        player.resumeToken = _token();
        player.connected = true;
        player.moveX = 0;
        player.moveY = 0;
        return player;
      }
    }
    return null;
  }

  @override
  void disconnect(GameServerPlayer player) {
    final matchPlayer = _find(player.id);
    if (matchPlayer != null) {
      matchPlayer.connected = false;
      matchPlayer.moveX = 0;
      matchPlayer.moveY = 0;
    }
  }

  @override
  void leave(GameServerPlayer player) {
    final matchPlayer = _find(player.id);
    if (matchPlayer == null) return;
    if (_rules?.phase == MatchPhase.running) {
      _rules!.forfeit(matchPlayer.id);
      matchPlayer.connected = false;
      _queueFinishedSettlements();
      return;
    }
    _players.remove(matchPlayer);
  }

  @override
  String? handle(GameServerPlayer player, Map<String, dynamic> message) {
    final current = _find(player.id);
    if (current == null || !current.connected) return 'player_unavailable';
    switch (message['type']) {
      case 'select':
        if (_rules != null) return 'match_already_started';
        final heroId = message['heroId'];
        final weaponId = message['weaponId'];
        if (heroId is! String || weaponId is! String) {
          return 'invalid_loadout';
        }
        final hero = archerFmHeroes.where((item) => item.id.name == heroId);
        if (hero.isEmpty ||
            !hero.single.weapons.any((weapon) => weapon.id == weaponId)) {
          return 'invalid_loadout';
        }
        final isStartingWeapon = hero.single.weapons.first.id == weaponId;
        final accountProgress = _accountHeroProgress[current.id];
        final ownsWeapon = accountProgress?.ownsWeapon(weaponId) ??
            (_canUseWeapon?.call(current.id, weaponId) ?? false);
        if (!isStartingWeapon && !ownsWeapon) {
          return 'weapon_locked';
        }
        current.heroId = heroId;
        current.weaponId = weaponId;
        return null;
      case 'army_select':
        if (_rules != null) return 'match_already_started';
        final rawCounts = message['counts'];
        if (rawCounts is! Map) return 'invalid_army_selection';
        final counts = {for (final type in MonsterType.values) type: 0};
        for (final entry in rawCounts.entries) {
          if (entry.key is! String || entry.value is! int) {
            return 'invalid_army_selection';
          }
          final type = MonsterType.values.where((item) => item.name == entry.key);
          if (type.isEmpty || (entry.value as int) < 0) {
            return 'invalid_army_selection';
          }
          counts[type.single] = entry.value as int;
        }
        try {
          current.initialArmySelection = InitialArmySelection(counts);
        } on ArgumentError {
          return 'invalid_army_selection';
        }
        return null;
      case 'start':
        if (_rules != null) return 'match_already_started';
        if (_players.length != 4) return 'need_four_players';
        if (_players.any((item) => item.heroId == null || item.weaponId == null)) {
          return 'all_players_must_select';
        }
        if (_combatConfiguration != null &&
            _players.any((item) => item.initialArmySelection == null)) {
          return 'all_players_must_select_army';
        }
        world = MatchWorldAuthority(
          map: _mapFactory?.call() ?? ArenaMap.generate(_random),
          playerIds: [for (final item in _players) item.id],
          random: _random,
        );
        if (_combatConfiguration case final config?) {
          try {
            combat = MatchCombatAuthority(
              world: world!,
              heroes: {
                for (final item in _players)
                  item.id: archerFmHeroes.firstWhere(
                    (hero) => hero.id.name == item.heroId,
                  ),
              },
              weaponIds: {
                for (final item in _players) item.id: item.weaponId!,
              },
              heroLevels: {
                for (final item in _players)
                  item.id: _accountHeroProgress[item.id]?.heroLevel(item.heroId!) ??
                      _heroLevelForPlayer?.call(item.id, item.heroId!) ??
                      1,
              },
              initialArmies: {
                for (final item in _players)
                  item.id: item.initialArmySelection!,
              },
              configuration: _accountMonsterProgression.isEmpty
                  ? config
                  : config.withMonsterProgressionByPlayer({
                      ...config.monsterProgressionByPlayer,
                      for (final entry in _accountMonsterProgression.entries)
                        entry.key: entry.value,
                    }),
              weaponUpgradeLevels: {
                for (final item in _players)
                  item.id: _accountHeroProgress[item.id]?.weaponLevel(item.weaponId!) ??
                      _weaponUpgradeLevelForPlayer?.call(item.id, item.weaponId!) ??
                      0,
              },
              onKill: (playerId, targetKind) {
                final isHero = targetKind == MonsterTargetKind.hero;
                final score = isHero
                    ? config.heroKillScore
                    : config.monsterKillScore;
                final resources = isHero
                    ? config.heroKillResources
                    : config.monsterKillResources;
                if (score > 0) awardScore(playerId, score);
                if (resources > 0) world!.creditResources(playerId, resources);
              },
              random: _random,
            );
          } on ArgumentError {
            world = null;
            return 'invalid_combat_configuration';
          }
        }
        _rules = MatchRulesEngine(
          duration: duration,
          participants: [
            for (final item in _players)
              MatchParticipantSeed(playerId: item.id),
          ],
        )..start();
        return null;
      case 'forfeit':
        final rules = _rules;
        if (rules == null || rules.phase != MatchPhase.running) return 'match_not_running';
        final result = rules.forfeit(current.id);
        if (result.accepted) _queueFinishedSettlements();
        return result.accepted ? null : 'forfeit_rejected';
      case 'move':
        if (_rules?.phase != MatchPhase.running) return 'match_not_running';
        final authority = combat;
        final dx = message['dx'];
        final dy = message['dy'];
        if (authority == null) return 'combat_not_configured';
        if (dx is! num || dy is! num ||
            !dx.toDouble().isFinite || !dy.toDouble().isFinite ||
            dx.toDouble() * dx.toDouble() + dy.toDouble() * dy.toDouble() > 1.000002) {
          return 'invalid_movement';
        }
        current.moveX = dx.toDouble();
        current.moveY = dy.toDouble();
        return null;
      case 'attack':
        if (_rules?.phase != MatchPhase.running) return 'match_not_running';
        final authority = combat;
        final targetId = message['targetId'];
        if (authority == null) return 'combat_not_configured';
        if (targetId is! String) return 'invalid_target';
        final result = authority.attack(current.id, targetId);
        current.lastCombatAction = {
          'accepted': result.accepted,
          'messageAr': result.messageAr,
          'damage': result.damage,
          'comboIndex': result.comboIndex,
        };
        _syncCrystalStandings();
        return result.accepted ? null : 'attack_rejected';
      case 'ultimate':
        if (_rules?.phase != MatchPhase.running) return 'match_not_running';
        final authority = combat;
        final targetId = message['targetId'];
        final index = message['index'];
        if (authority == null) return 'combat_not_configured';
        if (targetId is! String || index is! int) return 'invalid_ultimate';
        final result = authority.useUltimate(current.id, index, targetId);
        current.lastCombatAction = {
          'accepted': result.accepted,
          'messageAr': result.messageAr,
          'damage': result.damage,
          'cooldownRemainingMs': result.cooldownRemainingMs,
        };
        _syncCrystalStandings();
        return result.accepted ? null : 'ultimate_rejected';
      case 'purchase':
        if (_rules?.phase != MatchPhase.running) return 'match_not_running';
        final authority = combat;
        final typeName = message['monsterType'];
        if (authority == null) return 'combat_not_configured';
        if (typeName is! String) return 'invalid_monster_type';
        final matches = MonsterType.values.where((type) => type.name == typeName);
        if (matches.isEmpty) return 'invalid_monster_type';
        final purchase = authority.purchaseMonster(current.id, matches.single);
        if (purchase == null) return 'purchase_rejected';
        current.lastPurchase = {
          'unitId': purchase.unit.id,
          'monsterType': purchase.unit.type.name,
          'cost': purchase.cost,
        };
        return null;
      case 'rebuild_crystal':
        if (_rules?.phase != MatchPhase.running) return 'match_not_running';
        final x = message['x'];
        final y = message['y'];
        if (x is! num || y is! num ||
            !x.toDouble().isFinite || !y.toDouble().isFinite) {
          return 'invalid_rebuild_position';
        }
        // The owner is always the authenticated connection's server-side
        // player identity. A client-supplied ownerId is deliberately ignored.
        final rebuild = rebuildCrystal(
          ownerId: current.id,
          position: Offset(x.toDouble(), y.toDouble()),
        );
        switch (rebuild) {
          case CrystalRebuildResult.ok:
            current.lastRebuild = {'x': x.toDouble(), 'y': y.toDouble()};
            return null;
          case CrystalRebuildResult.notEnoughResources:
            return 'rebuild_not_enough_resources';
          case CrystalRebuildResult.atMax:
            return 'rebuild_at_max';
          case CrystalRebuildResult.outsideTerritory:
            return 'rebuild_outside_territory';
          case CrystalRebuildResult.blocked:
            return 'rebuild_blocked';
        }
      default:
        return 'unsupported_command';
    }
  }

  /// Called only by trusted server-side combat/scoring code.
  MatchCommandResult awardScore(String playerId, int points) {
    final rules = _rules;
    if (rules == null) {
      return const MatchCommandResult.rejected('المباراة لم تبدأ');
    }
    return rules.addScore(playerId, points);
  }

  /// Called only by trusted server-side castle/crystal authority.
  MatchCommandResult updateLivingCrystals(String playerId, int count) {
    final rules = _rules;
    if (rules == null) {
      return const MatchCommandResult.rejected('المباراة لم تبدأ');
    }
    final result = rules.setLivingCrystals(playerId, count);
    if (result.accepted) _queueFinishedSettlements();
    return result;
  }

  /// Server-authoritative movement through map collision and terrain rules.
  Offset? movePlayer(String playerId, Offset desiredDelta, {double radius = 18}) {
    final rules = _rules;
    final matchWorld = world;
    if (rules?.phase != MatchPhase.running || matchWorld == null) return null;
    return matchWorld.movePlayer(playerId, desiredDelta, radius);
  }

  /// Connects authoritative crystal damage to the canonical match tiebreak data.
  CrystalDamageResult damageCrystal({
    required String attackerId,
    required String crystalId,
    required double amount,
  }) {
    final rules = _rules;
    final matchWorld = world;
    if (rules?.phase != MatchPhase.running || matchWorld == null) {
      return const CrystalDamageResult.unknownCrystal();
    }
    final result = matchWorld.damageCrystal(
      attackerId: attackerId,
      crystalId: crystalId,
      amount: amount,
    );
    if (result.accepted && result.ownerId != null && result.livingCrystals != null) {
      rules!.setLivingCrystals(result.ownerId!, result.livingCrystals!);
      _queueFinishedSettlements();
    }
    return result;
  }

  CrystalRebuildResult rebuildCrystal({
    required String ownerId,
    required Offset position,
  }) {
    final rules = _rules;
    final matchWorld = world;
    if (rules?.phase != MatchPhase.running || matchWorld == null) {
      return CrystalRebuildResult.blocked;
    }
    final result = matchWorld.rebuildCrystal(ownerId: ownerId, position: position);
    if (result == CrystalRebuildResult.ok) {
      rules!.setLivingCrystals(ownerId, matchWorld.livingCrystals(ownerId));
      _queueFinishedSettlements();
    }
    return result;
  }

  @override
  void tick(Duration elapsed) {
    final rules = _rules;
    if (rules?.phase == MatchPhase.finished) {
      _settlementRetryElapsed += elapsed;
      if (_settlementRetryElapsed >= const Duration(seconds: 1)) {
        _settlementRetryElapsed = Duration.zero;
        _attemptPendingSettlements();
      }
      return;
    }
    if (rules?.phase != MatchPhase.running) return;
    rules!.advance(elapsed);
    if (rules.phase != MatchPhase.running) {
      combat?.clear();
      _queueFinishedSettlements();
      return;
    }
    final authority = combat;
    if (authority != null) {
      for (final player in _players) {
        if (!player.connected || (player.moveX == 0 && player.moveY == 0)) continue;
        try {
          authority.moveHero(
            player.id,
            Offset(player.moveX, player.moveY),
            elapsed,
          );
        } on StateError {
          player.moveX = 0;
          player.moveY = 0;
        }
      }
      authority.tick(elapsed);
      _syncCrystalStandings();
    }
    final matchWorld = world;
    if (matchWorld != null && elapsed.inMilliseconds > 0) {
      _worldNowMs += elapsed.inMilliseconds;
      final result = matchWorld.tick(
        deltaMs: elapsed.inMilliseconds,
        nowMs: _worldNowMs,
      );
      for (final entry in result.livingCrystals.entries) {
        rules.setLivingCrystals(entry.key, entry.value);
      }
      _queueFinishedSettlements();
    }
  }

  @override
  Map<String, Object?> snapshot() {
    final rules = _rules;
    return {
      'type': 'state',
      'roomCode': code,
      'durationMinutes': duration.minutes,
      'phase': rules?.phase.name ?? MatchPhase.waiting.name,
      'elapsedMs': rules?.elapsed.inMilliseconds ?? 0,
      'remainingMs': rules?.remaining.inMilliseconds ??
          duration.duration.inMilliseconds,
      'players': [
        for (final player in _players)
          {
            'id': player.id,
            'connected': player.connected,
            'heroId': player.heroId,
            'weaponId': player.weaponId,
            if (player.initialArmySelection != null)
              'initialArmy': {
                for (final type in MonsterType.values)
                  type.name: player.initialArmySelection!.counts[type] ?? 0,
              },
            if (player.lastCombatAction != null)
              'lastCombatAction': player.lastCombatAction,
            if (player.lastPurchase != null) 'lastPurchase': player.lastPurchase,
            if (player.lastRebuild != null) 'lastRebuild': player.lastRebuild,
          },
      ],
      if (rules?.result case final result?)
        'result': {
          'reason': result.reason.name,
          'winnerId': result.winnerId,
          'tiedPlayerIds': result.tiedPlayerIds,
          'standings': [
            for (final standing in result.standings)
              {
                'playerId': standing.playerId,
                'score': standing.score,
                'livingCrystals': standing.livingCrystals,
                'rank': standing.rank,
                'hasForfeited': standing.hasForfeited,
              },
          ],
        },
      if (combat case final matchCombat?)
        'combat': {
          'heroes': {
            for (final entry in matchCombat.heroes.entries)
              entry.key: {
                'id': entry.value.entityId,
                'health': entry.value.health,
                'maxHealth': entry.value.maxHealth,
                'level': entry.value.level,
                'isAlive': entry.value.isAlive,
                'respawnRemainingMs': entry.value.respawnRemaining.inMilliseconds,
                'protectionRemainingMs': entry.value.protectionRemaining.inMilliseconds,
                'weaponId': entry.value.combat.selectedWeapon.id,
                'comboIndex': entry.value.combat.comboIndex,
                'attackCooldownMs': entry.value.combat.attackCooldownRemainingMs,
                'energy': entry.value.combat.energy,
                'maxEnergy': entry.value.combat.maxEnergy,
                'ultimateCooldowns': entry.value.combat.ultimateCooldowns,
              },
          },
          'monsterProgression': {
            for (final entry in matchCombat.configuration.monsterProgressionByPlayer.entries)
              entry.key: entry.value.toSaveData(),
          },
          'monsters': [
            for (final unit in matchCombat.monsters.liveUnits)
              {
                'id': unit.id,
                'ownerId': unit.ownerId,
                'type': unit.type.name,
                'x': unit.positionX,
                'y': unit.positionY,
                'health': unit.health,
                'maxHealth': unit.stats.maxHealth,
                'targetId': unit.targetId,
              },
          ],
          'dyingMonsters': [
            for (final unit in matchCombat.monsters.dyingUnits)
              {
                'id': unit.id,
                'ownerId': unit.ownerId,
                'type': unit.type.name,
                'x': unit.positionX,
                'y': unit.positionY,
              },
          ],
          'projectiles': [
            for (final projectile in matchCombat.monsters.projectileManager.active)
              {'id': projectile.id, 'ownerId': projectile.ownerId,
               'targetId': projectile.targetId, 'x': projectile.positionX,
               'y': projectile.positionY},
          ],
        },
      if (world case final matchWorld?)
        'world': {
          'size': {
            'width': matchWorld.map.size.width,
            'height': matchWorld.map.size.height,
          },
          // Static geometry is part of the authoritative snapshot so every
          // client renders the same randomized battlefield as the server.
          'biomes': [
            for (final biome in matchWorld.map.biomes)
              {
                'kind': biome.kind.name,
                'x': biome.center.dx,
                'y': biome.center.dy,
                'radius': biome.radius,
              },
          ],
          'rivers': [
            for (final river in matchWorld.map.rivers)
              {
                'width': river.width,
                'points': [
                  for (final point in river.points)
                    {'x': point.dx, 'y': point.dy},
                ],
                'bridges': [
                  for (final bridge in river.bridges)
                    {
                      'x': bridge.center.dx,
                      'y': bridge.center.dy,
                      'width': bridge.width,
                      'depth': bridge.depth,
                    },
                ],
              },
          ],
          'obstacles': [
            for (final obstacle in matchWorld.map.obstacles)
              {
                'kind': obstacle.kind.name,
                'x': obstacle.position.dx,
                'y': obstacle.position.dy,
                'radius': obstacle.radius,
              },
          ],
          'mapPickups': [
            for (final pickup in matchWorld.map.pickups)
              {
                'kind': pickup.kind.name,
                'x': pickup.position.dx,
                'y': pickup.position.dy,
              },
          ],
          'resources': matchWorld.resources,
          'livingCrystals': {
            for (final player in _players)
              player.id: matchWorld.livingCrystals(player.id),
          },
          'playerPositions': {
            for (final entry in matchWorld.playerPositions.entries)
              entry.key: {'x': entry.value.dx, 'y': entry.value.dy},
          },
          'castles': [
            for (final castle in matchWorld.castles.castles)
              {
                'ownerId': castle.ownerId,
                'fallen': castle.fallen,
                'anchor': {'x': castle.anchor.dx, 'y': castle.anchor.dy},
                'walls': [
                  for (final wall in castle.walls)
                    {
                      'radius': wall.radius,
                      'startAngle': wall.startAngle,
                      'sweep': wall.sweep,
                    },
                ],
                'crystals': [
                  for (final crystal in castle.crystals)
                    {
                      'id': crystal.id,
                      'slot': crystal.slot,
                      'x': crystal.position.dx,
                      'y': crystal.position.dy,
                      'hp': crystal.hp,
                      'maxHp': crystal.maxHp,
                      'exposed': crystal.exposed,
                    },
                ],
              },
          ],
          'mines': [
            for (final mine in matchWorld.mines.mines)
              {
                'ownerId': mine.ownerId,
                'capturerId': mine.capturerId,
                'captureFraction': mine.captureFraction,
                'x': mine.position.dx,
                'y': mine.position.dy,
                'size': mine.size.name,
              },
          ],
          'resourcePickups': [
            for (final pickup in matchWorld.mines.pickups)
              {
                'id': pickup.id,
                'x': pickup.position.dx,
                'y': pickup.position.dy,
                'amount': pickup.amount,
              },
          ],
        },
      'participants': [
        if (rules != null)
          for (final participant in rules.participants)
            {
              'playerId': participant.playerId,
              'score': participant.score,
              'livingCrystals': participant.livingCrystals,
              'hasForfeited': participant.hasForfeited,
            },
      ],
    };
  }

  /// Builds a recipient-specific state projection. Enemy units and
  /// projectiles outside the existing map reveal radius are not sent over the
  /// network, rather than merely hidden by the local renderer.
  @override
  Map<String, Object?> snapshotFor(GameServerPlayer player) {
    final result = snapshot();
    final worldData = result['world'];
    final combatData = result['combat'];
    if (worldData is! Map || combatData is! Map) return result;

    final positions = worldData['playerPositions'];
    final localPosition = positions is Map ? positions[player.id] : null;
    final localX = localPosition is Map && localPosition['x'] is num
        ? (localPosition['x'] as num).toDouble()
        : null;
    final localY = localPosition is Map && localPosition['y'] is num
        ? (localPosition['y'] as num).toDouble()
        : null;

    bool visibleToPlayer(Object? raw) {
      if (raw is! Map) return false;
      if (raw['ownerId'] == player.id) return true;
      final x = raw['x'];
      final y = raw['y'];
      if (localX == null || localY == null || x is! num || y is! num) {
        return false;
      }
      final dx = x.toDouble() - localX;
      final dy = y.toDouble() - localY;
      return dx * dx + dy * dy <= enemyVisibleRadius * enemyVisibleRadius;
    }

    // Enemy hero locations and their live combat telemetry obey the same
    // reveal radius as enemy units. Public standings remain available.
    final worldCopy = Map<String, Object?>.from(worldData);
    final scopedPositions = Map<String, Object?>.from(
      positions is Map ? positions : const {},
    )..removeWhere((id, point) => id != player.id && !visibleToPlayer(point));
    worldCopy['playerPositions'] = scopedPositions;
    result['world'] = worldCopy;

    final scopedCombat = Map<String, Object?>.from(combatData);
    final heroes = combatData['heroes'];
    if (heroes is Map) {
      final scopedHeroes = Map<String, Object?>.from(heroes);
      scopedHeroes.removeWhere((id, _) =>
          id != player.id && !scopedPositions.containsKey(id));
      scopedCombat['heroes'] = scopedHeroes;
    }
    final monsters = combatData['monsters'];
    if (monsters is List) {
      scopedCombat['monsters'] = monsters.where(visibleToPlayer).toList();
    }
    final dying = combatData['dyingMonsters'];
    if (dying is List) {
      // Dying entries have no position; expose only the recipient's own units.
      scopedCombat['dyingMonsters'] =
          dying.where(visibleToPlayer).toList();
    }
    final projectiles = combatData['projectiles'];
    if (projectiles is List) {
      scopedCombat['projectiles'] =
          projectiles.where(visibleToPlayer).toList();
    }
    result['combat'] = scopedCombat;
    final accountProgress = _accountHeroProgress[player.id];
    if (accountProgress != null) {
      // Cloud profile details are private: include them only in this player's
      // recipient-scoped snapshot, never the shared match broadcast.
      result['accountProgression'] = accountProgress.toJson();
    }
    return result;
  }

  void _queueFinishedSettlements() {
    if (_settlementsQueued) return;
    final result = _rules?.result;
    final handler = _onMatchSettlement;
    if (result == null || handler == null) return;
    _settlementsQueued = true;
    for (final standing in result.standings) {
      final player = _find(standing.playerId);
      final accountId = player?.accountId;
      if (accountId == null || accountId.isEmpty) continue;
      _pendingSettlements[accountId] = _PendingMatchSettlement(
        accountId: accountId,
        standing: standing,
        finishReason: result.reason,
      );
    }
    _attemptPendingSettlements();
  }

  void _attemptPendingSettlements() {
    final handler = _onMatchSettlement;
    if (_settlementInFlight || handler == null || _pendingSettlements.isEmpty) {
      return;
    }
    unawaited(_persistPendingSettlements(handler));
  }

  Future<void> _persistPendingSettlements(
    MatchSettlementHandler handler,
  ) async {
    if (_settlementInFlight) return;
    _settlementInFlight = true;
    try {
      for (final pending in _pendingSettlements.values.toList()) {
        try {
          await handler(
            matchId: matchId,
            accountId: pending.accountId,
            standing: pending.standing,
            finishReason: pending.finishReason,
          );
          _pendingSettlements.remove(pending.accountId);
        } on Object catch (error) {
          _onMatchSettlementError?.call(error);
          // Keep the entry queued. The host's next ticks retry it; the
          // database RPC is idempotent if the previous response was lost.
        }
      }
    } finally {
      _settlementInFlight = false;
    }
  }

  void _syncCrystalStandings() {
    final rules = _rules;
    final matchWorld = world;
    if (rules == null || matchWorld == null) return;
    for (final id in matchWorld.playerIds) {
      if (rules.phase != MatchPhase.running) break;
      rules.setLivingCrystals(id, matchWorld.livingCrystals(id));
    }
    _queueFinishedSettlements();
  }

  _MatchPlayer? _find(String id) {
    for (final player in _players) {
      if (player.id == id) return player;
    }
    return null;
  }

  String _token() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}

class _MatchPlayer implements GameServerPlayer {
  _MatchPlayer({required this.id, required this.resumeToken, this.accountId});

  @override
  final String id;
  @override
  String resumeToken;
  final String? accountId;
  @override
  int lastSequence = 0;
  @override
  bool connected = true;
  String? heroId;
  String? weaponId;
  InitialArmySelection? initialArmySelection;
  double moveX = 0;
  double moveY = 0;
  Map<String, Object?>? lastCombatAction;
  Map<String, Object?>? lastPurchase;
  Map<String, Object?>? lastRebuild;
}

class _PendingMatchSettlement {
  const _PendingMatchSettlement({
    required this.accountId,
    required this.standing,
    required this.finishReason,
  });

  final String accountId;
  final MatchStanding standing;
  final MatchFinishReason finishReason;
}
