import 'dart:math';
import 'dart:ui';

import '../heroes/hero_roster.dart';
import '../world/arena_map.dart';
import '../world/castle_system.dart';
import '../match/match_rules.dart';
import 'match_world_authority.dart';
import 'match_combat_authority.dart';
import '../../monsters/monster_models.dart';
import '../../monsters/monster_army.dart';
import 'websocket_game_host.dart';

/// Concrete four-player match session used by [WebSocketGameHost].
///
/// Client commands may choose a valid hero/loadout, start a full lobby, or
/// forfeit. Scores and crystal counts are updated only through trusted
/// server-side methods called by the authoritative combat/castle systems.
class AuthoritativeMatchSession implements GameServerSession {
  AuthoritativeMatchSession({
    required this.code,
    int durationMinutes = 30,
    Random? random,
    bool Function(String playerId, String weaponId)? canUseWeapon,
    ArenaMap Function()? mapFactory,
    MatchCombatConfiguration? combatConfiguration,
  })  : _mapFactory = mapFactory,
        _combatConfiguration = combatConfiguration,
        duration = MatchDuration.fromMinutes(durationMinutes),
        _random = random ?? Random.secure(),
        _canUseWeapon = canUseWeapon;

  /// Creates the production-style room factory with an explicitly supplied
  /// approved combat catalog and tuning. No provisional balance is selected
  /// by the transport or this session.
  static GameServerSessionFactory configuredFactory({
    required MatchCombatConfiguration combatConfiguration,
    bool Function(String playerId, String weaponId)? canUseWeapon,
    ArenaMap Function()? mapFactory,
  }) {
    return (roomCode, message) => AuthoritativeMatchSession.fromCreateMessage(
          roomCode,
          message,
          canUseWeapon: canUseWeapon,
          mapFactory: mapFactory,
          combatConfiguration: combatConfiguration,
        );
  }

  factory AuthoritativeMatchSession.fromCreateMessage(
    String roomCode,
    Map<String, dynamic> message, {
    bool Function(String playerId, String weaponId)? canUseWeapon,
    ArenaMap Function()? mapFactory,
    MatchCombatConfiguration? combatConfiguration,
  }) {
    final requestedDuration = message['durationMinutes'];
    if (requestedDuration != null && requestedDuration is! int) {
      throw const FormatException('durationMinutes must be an integer.');
    }
    return AuthoritativeMatchSession(
      code: roomCode,
      durationMinutes: requestedDuration as int? ?? 30,
      canUseWeapon: canUseWeapon,
      mapFactory: mapFactory,
      combatConfiguration: combatConfiguration,
    );
  }

  @override
  final String code;
  final MatchDuration duration;
  final ArenaMap Function()? _mapFactory;
  final MatchCombatConfiguration? _combatConfiguration;
  MatchCombatAuthority? combat;
  MatchWorldAuthority? world;
  int _worldNowMs = 0;
  final Random _random;
  final bool Function(String playerId, String weaponId)? _canUseWeapon;
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
          _players.every((player) => !player.connected));

  @override
  GameServerPlayer? join() {
    if (_rules != null || _players.length >= 4) return null;
    final number = _nextPlayerNumber++;
    final player = _MatchPlayer(
      id: 'p$number',
      resumeToken: _token(),
    );
    _players.add(player);
    return player;
  }

  @override
  GameServerPlayer? resume(String resumeToken) {
    for (final player in _players) {
      if (player.resumeToken == resumeToken) {
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
        if (!isStartingWeapon && !(_canUseWeapon?.call(current.id, weaponId) ?? false)) {
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
              initialArmies: {
                for (final item in _players)
                  item.id: item.initialArmySelection!,
              },
              configuration: config,
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
    return rules.setLivingCrystals(playerId, count);
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
    }
    return result;
  }

  @override
  void tick(Duration elapsed) {
    final rules = _rules;
    if (rules?.phase != MatchPhase.running) return;
    rules!.advance(elapsed);
    if (rules.phase != MatchPhase.running) {
      combat?.clear();
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
                'weaponId': entry.value.combat.selectedWeapon.id,
                'comboIndex': entry.value.combat.comboIndex,
                'attackCooldownMs': entry.value.combat.attackCooldownRemainingMs,
                'ultimateCooldowns': entry.value.combat.ultimateCooldowns,
              },
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
              {'id': unit.id, 'ownerId': unit.ownerId, 'type': unit.type.name},
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

  void _syncCrystalStandings() {
    final rules = _rules;
    final matchWorld = world;
    if (rules == null || matchWorld == null) return;
    for (final id in matchWorld.playerIds) {
      rules.setLivingCrystals(id, matchWorld.livingCrystals(id));
    }
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
  _MatchPlayer({required this.id, required this.resumeToken});

  @override
  final String id;
  @override
  final String resumeToken;
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
}
