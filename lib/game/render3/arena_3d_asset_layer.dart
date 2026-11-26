import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../hero/hero3d.dart';
import '../../monsters/monster3d.dart';
import '../world/arena_map.dart' show enemyVisibleRadius;

/// Snapshot-driven 3D actor layer. The server snapshot remains authoritative:
/// this layer only animates and paints the already-received positions/health.
class Arena3DAssetLayer extends StatefulWidget {
  const Arena3DAssetLayer({
    super.key,
    required this.snapshot,
    required this.localPlayerId,
  });

  final Map<String, dynamic> snapshot;
  final String localPlayerId;

  @override
  State<Arena3DAssetLayer> createState() => _Arena3DAssetLayerState();
}

class _Arena3DAssetLayerState extends State<Arena3DAssetLayer>
    with SingleTickerProviderStateMixin {
  static const _heroIds = {'ranger', 'flame', 'shadow', 'storm'};
  static const _monsterIds = {
    'runner': 'werewolf',
    'tank': 'stone-golem',
    'stalker': 'blind-stalker',
    'ranged': 'bog-monster',
  };
  static const _maxAnimatedMonsters = 8;

  final Map<String, Hero3D> _heroes = {};
  final Map<String, Monster3D> _monsters = {};
  final Map<String, Offset> _lastHeroPositions = {};
  final Map<String, Offset> _lastMonsterPositions = {};
  final Map<String, double> _lastHeroHealth = {};
  final Map<String, double> _lastMonsterHealth = {};
  final Map<String, int> _lastCombo = {};
  final Map<String, List<double>> _lastUltimateCooldowns = {};

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  Map? _asMap(Object? value) => value is Map ? value : null;
  List _asList(Object? value) => value is List ? value : const [];

  double? _asDouble(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;

  Offset? _asPoint(Object? value) {
    final map = _asMap(value);
    final x = _asDouble(map?['x']);
    final y = _asDouble(map?['y']);
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  Map<String, dynamic> get _combat =>
      Map<String, dynamic>.from(_asMap(widget.snapshot['combat']) ?? const {});

  Map get _world => _asMap(widget.snapshot['world']) ?? const {};

  Map get _playerPositions => _asMap(_world['playerPositions']) ?? const {};

  Offset? get _localPosition => _asPoint(_playerPositions[widget.localPlayerId]);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _syncModels();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant Arena3DAssetLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncModels();
    _syncTicker();
  }

  String _heroIdForPlayer(String playerId) {
    for (final raw in _asList(widget.snapshot['players'])) {
      final player = _asMap(raw);
      if (player?['id'] == playerId || player?['playerId'] == playerId) {
        final id = player?['heroId']?.toString().toLowerCase();
        if (id != null && _heroIds.contains(id)) return id;
      }
    }
    return 'ranger';
  }

  String? _monsterModelId(Map unit) =>
      _monsterIds[unit['type']?.toString().toLowerCase()];

  bool _isVisibleMonster(Map unit, Offset? local) {
    final owner = unit['ownerId']?.toString();
    if (owner == widget.localPlayerId) return true;
    if (local == null) return false;
    final point = _asPoint(unit);
    return point != null && (point - local).distance <= enemyVisibleRadius;
  }

  List<Map> _visibleMonsterUnits() {
    final local = _localPosition;
    final units = <Map>[];
    for (final raw in _asList(_combat['monsters'])) {
      final unit = _asMap(raw);
      if (unit != null && _isVisibleMonster(unit, local)) units.add(unit);
    }
    for (final raw in _asList(_combat['dyingMonsters'])) {
      final unit = _asMap(raw);
      if (unit != null && _isVisibleMonster(unit, local)) units.add(unit);
    }
    units.sort((a, b) {
      final pa = _asPoint(a);
      final pb = _asPoint(b);
      if (pa == null || pb == null || local == null) return 0;
      return (pa - local).distanceSquared.compareTo((pb - local).distanceSquared);
    });
    return units.take(_maxAnimatedMonsters).toList(growable: false);
  }

  void _syncModels() {
    final heroStates = _asMap(_combat['heroes']) ?? const {};
    final wantedHeroes = <String>{};
    for (final entry in heroStates.entries) {
      final playerId = entry.key.toString();
      final state = _asMap(entry.value);
      if (state == null) continue;
      wantedHeroes.add(playerId);
      final heroId = _heroIdForPlayer(playerId);
      final existing = _heroes[playerId];
      if (existing == null || existing.id != heroId) {
        existing?.dispose();
        final model = Hero3D(heroId, height: 68)..onSound = (_) {};
        _heroes[playerId] = model;
        model.load().then((_) {
          if (mounted) setState(() {});
        }).catchError((Object error, StackTrace stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'Archer FM 3D asset loading',
              context: ErrorDescription('while loading hero "$heroId"'),
            ),
          );
        });
      }
    }
    for (final id in _heroes.keys.toList()) {
      if (!wantedHeroes.contains(id)) {
        _heroes.remove(id)?.dispose();
        _lastHeroPositions.remove(id);
        _lastHeroHealth.remove(id);
        _lastCombo.remove(id);
        _lastUltimateCooldowns.remove(id);
      }
    }

    final wantedMonsters = <String>{};
    for (final unit in _visibleMonsterUnits()) {
      final id = unit['id']?.toString();
      final modelId = _monsterModelId(unit);
      if (id == null || id.isEmpty || modelId == null) continue;
      wantedMonsters.add(id);
      final existing = _monsters[id];
      if (existing == null || existing.id != modelId) {
        existing?.dispose();
        final model = Monster3D(modelId, height: switch (modelId) {
          'stone-golem' => 64,
          'blind-stalker' => 50,
          'werewolf' => 55,
          _ => 54,
        })
          ..onSound = (_) {}
          ..isHeavyAoe = modelId == 'stone-golem'
          ..isStealth = modelId == 'blind-stalker';
        _monsters[id] = model;
        model.load().then((_) {
          if (mounted) setState(() {});
        }).catchError((Object error, StackTrace stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'Archer FM 3D asset loading',
              context: ErrorDescription('while loading monster "$modelId"'),
            ),
          );
        });
      }
    }
    for (final id in _monsters.keys.toList()) {
      if (!wantedMonsters.contains(id)) {
        _monsters.remove(id)?.dispose();
        _lastMonsterPositions.remove(id);
        _lastMonsterHealth.remove(id);
      }
    }
  }

  void _syncTicker() {
    final running = widget.snapshot['phase'] == 'running';
    if (running && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!running && _ticker.isActive) {
      _ticker.stop();
      _lastElapsed = Duration.zero;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastElapsed).inMicroseconds / 1000000)
        .clamp(0.0, 0.05)
        .toDouble();
    _lastElapsed = elapsed;
    _advanceHeroes(dt);
    _advanceMonsters(dt);
    if (mounted) setState(() {});
  }

  void _advanceHeroes(double dt) {
    final states = _asMap(_combat['heroes']) ?? const {};
    for (final entry in states.entries) {
      final id = entry.key.toString();
      final state = _asMap(entry.value);
      final model = _heroes[id];
      if (state == null || model == null || !model.isReady) continue;

      final point = _asPoint(_playerPositions[id]);
      var direction = Offset.zero;
      if (point != null) {
        final previous = _lastHeroPositions[id];
        if (previous != null) {
          final delta = point - previous;
          if (delta.distanceSquared > 0.04) direction = delta / delta.distance;
        }
        _lastHeroPositions[id] = point;
      }
      if (direction.distanceSquared > 0) model.face(direction);

      final health = _asDouble(state['health']) ?? 100;
      final previousHealth = _lastHeroHealth.putIfAbsent(id, () => health);
      final alive = state['isAlive'] == true;
      if (!alive && !model.isDead) {
        model.hurt(model.hp + 1);
      } else if (alive && model.isDead) {
        model.revive();
      } else if (alive && health < previousHealth - 0.1) {
        model.hurt(1);
        model.hp = 100; // Keep visual hit reactions independent of game HP.
      }
      _lastHeroHealth[id] = health;

      final combo = (state['comboIndex'] as num?)?.toInt() ?? 0;
      final previousCombo = _lastCombo.putIfAbsent(id, () => combo);
      if (combo != previousCombo && combo > 0) model.attack();
      _lastCombo[id] = combo;

      final cooldowns = _asList(state['ultimateCooldowns'])
          .map((value) => _asDouble(value) ?? 0)
          .toList(growable: false);
      final previousCooldowns = _lastUltimateCooldowns[id];
      if (previousCooldowns != null) {
        for (var i = 0; i < cooldowns.length && i < 4; i++) {
          final before = i < previousCooldowns.length ? previousCooldowns[i] : 0;
          if (before <= 0 && cooldowns[i] > 0) model.ultimate(i + 1);
        }
      }
      _lastUltimateCooldowns[id] = cooldowns;
      model.update(dt, direction);
    }
  }

  void _advanceMonsters(double dt) {
    final active = <String, Map>{};
    for (final raw in _asList(_combat['monsters'])) {
      final unit = _asMap(raw);
      final id = unit?['id']?.toString();
      if (unit != null && id != null) active[id] = unit;
    }
    final dying = <String>{};
    for (final raw in _asList(_combat['dyingMonsters'])) {
      final unit = _asMap(raw);
      final id = unit?['id']?.toString();
      if (unit != null && id != null) {
        active[id] = unit;
        dying.add(id);
      }
    }

    for (final entry in active.entries) {
      final id = entry.key;
      final unit = entry.value;
      final model = _monsters[id];
      if (model == null || !model.isReady) continue;
      final point = _asPoint(unit);
      var direction = Offset.zero;
      var speed = 0.0;
      if (point != null) {
        final previous = _lastMonsterPositions[id];
        if (previous != null) {
          final delta = point - previous;
          if (delta.distanceSquared > 0.01) {
            direction = delta / delta.distance;
            speed = delta.distance / math.max(dt, 0.001);
          }
        }
        _lastMonsterPositions[id] = point;
      }

      final health = _asDouble(unit['health']) ?? 100;
      final previousHealth = _lastMonsterHealth.putIfAbsent(id, () => health);
      if (dying.contains(id) || health <= 0) {
        if (!model.isDead) model.takeHit(model.hp + 1);
      } else if (health < previousHealth - 0.1) {
        model.takeHit(1);
      }
      model.hp = health;
      _lastMonsterHealth[id] = health;
      model.update(
        dt,
        moveDir: direction.distanceSquared > 0 ? direction : null,
        moveSpeed: speed,
        attacking: !dying.contains(id) &&
            direction.distanceSquared <= 0.01 &&
            unit['targetId'] != null,
      );
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final model in _heroes.values) {
      model.dispose();
    }
    for (final model in _monsters.values) {
      model.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _Arena3DActorPainter(
          snapshot: widget.snapshot,
          localPlayerId: widget.localPlayerId,
          heroes: _heroes,
          monsters: _monsters,
        ),
        child: const SizedBox.expand(),
      );
}

class _Arena3DActorPainter extends CustomPainter {
  _Arena3DActorPainter({
    required this.snapshot,
    required this.localPlayerId,
    required this.heroes,
    required this.monsters,
  });

  final Map<String, dynamic> snapshot;
  final String localPlayerId;
  final Map<String, Hero3D> heroes;
  final Map<String, Monster3D> monsters;

  Map? _map(Object? value) => value is Map ? value : null;
  List _list(Object? value) => value is List ? value : const [];
  double? _number(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;

  Offset? _point(Object? value) {
    final map = _map(value);
    final x = _number(map?['x']);
    final y = _number(map?['y']);
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  Offset _screen(Offset world, Size size, Size worldSize, Offset origin) {
    const cameraWidth = 960.0;
    const cameraHeight = 540.0;
    final scale = math.min(
      size.width / cameraWidth,
      size.height / (cameraHeight * 0.82),
    );
    return Offset(
      (world.dx - origin.dx) * scale,
      (world.dy - origin.dy) * scale * 0.82,
    );
  }

  Offset _cameraOrigin(Map world, Size worldSize, Size viewport) {
    const projectionYScale = 0.82;
    final scale = math.min(
      viewport.width / 960.0,
      viewport.height / (540.0 * projectionYScale),
    );
    final visibleWidth = viewport.width / scale;
    final visibleHeight = viewport.height / (scale * projectionYScale);
    final positions = _map(world['playerPositions']);
    final local = _point(positions?[localPlayerId]);
    final focus = local ?? Offset(worldSize.width / 2, worldSize.height / 2);
    return Offset(
      (focus.dx - visibleWidth / 2)
          .clamp(0.0, math.max(0.0, worldSize.width - visibleWidth))
          .toDouble(),
      (focus.dy - visibleHeight / 2)
          .clamp(0.0, math.max(0.0, worldSize.height - visibleHeight))
          .toDouble(),
    );
  }

  Color _ownerColor(String? id) {
    final players = _list(snapshot['players']);
    for (final raw in players) {
      final player = _map(raw);
      if (player?['id'] == id || player?['playerId'] == id) {
        const colors = <String, Color>{
          'ranger': Color(0xFF9BE845),
          'flame': Color(0xFFFF8A24),
          'shadow': Color(0xFFB98CF0),
          'storm': Color(0xFF48C8FF),
        };
        return colors[player?['heroId']?.toString()] ??
            const Color(0xFFE7D7B5);
      }
    }
    return const Color(0xFFE7D7B5);
  }

  bool _visible(Map unit, Offset? local) {
    if (unit['ownerId']?.toString() == localPlayerId) return true;
    final point = _point(unit);
    return local != null &&
        point != null &&
        (point - local).distance <= enemyVisibleRadius;
  }

  void _healthBar(Canvas canvas, Offset p, double width, double fraction) {
    final safe = fraction.clamp(0.0, 1.0).toDouble();
    final rect = Rect.fromLTWH(p.dx - width / 2, p.dy, width, 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = const Color(0xFF201C19),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top, rect.width * safe, rect.height),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF8DE36A),
    );
  }

  void _fallback(Canvas canvas, Offset p, Color color, double radius) {
    canvas.drawCircle(
      p + const Offset(0, 2),
      radius + 1,
      Paint()..color = const Color(0x77000000),
    );
    canvas.drawCircle(p, radius, Paint()..color = color);
    canvas.drawCircle(
      p,
      radius,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final world = _map(snapshot['world']);
    final mapSize = _map(world?['size']);
    final width = _number(mapSize?['width']);
    final height = _number(mapSize?['height']);
    if (world == null || width == null || height == null || width <= 0 || height <= 0) {
      return;
    }
    final worldSize = Size(width, height);
    final origin = _cameraOrigin(world, worldSize, size);
    Offset project(Offset point) => _screen(point, size, worldSize, origin);
    final local = _point(_map(world['playerPositions'])?[localPlayerId]);
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final combat = _map(snapshot['combat']);
    final monsterUnits = <Map>[
      for (final raw in _list(combat?['monsters']))
        if (_map(raw) != null) _map(raw)!,
      for (final raw in _list(combat?['dyingMonsters']))
        if (_map(raw) != null) _map(raw)!,
    ]..sort((a, b) {
        final pa = _point(a);
        final pb = _point(b);
        return (pa?.dy ?? 0).compareTo(pb?.dy ?? 0);
      });

    for (final unit in monsterUnits) {
      if (!_visible(unit, local)) continue;
      final id = unit['id']?.toString();
      final point = _point(unit);
      if (id == null || point == null) continue;
      final p = project(point);
      // Keep the top-right minimap readable.
      if (p.dx > size.width - 145 && p.dy < 88) continue;
      final model = monsters[id];
      if (model != null && model.isReady) {
        model.position = p;
        model.paint(canvas);
      } else {
        _fallback(canvas, p, _ownerColor(unit['ownerId']?.toString()), 6);
      }
      final hp = _number(unit['health']);
      final maxHp = _number(unit['maxHealth']);
      if (hp != null && maxHp != null && maxHp > 0) {
        _healthBar(canvas, p.translate(0, -modelHeight(model, 34) / 2 - 7), 28, hp / maxHp);
      }
    }

    final heroStates = _map(combat?['heroes']) ?? const {};
    final positions = _map(world['playerPositions']) ?? const {};
    final heroEntries = heroStates.entries.toList()
      ..sort((a, b) {
        final pa = _point(positions[a.key]);
        final pb = _point(positions[b.key]);
        return (pa?.dy ?? 0).compareTo(pb?.dy ?? 0);
      });
    for (final entry in heroEntries) {
      final id = entry.key.toString();
      final state = _map(entry.value);
      final point = _point(positions[id]);
      if (state == null || point == null) continue;
      final p = project(point);
      if (p.dx > size.width - 145 && p.dy < 88) continue;
      final model = heroes[id];
      if (model != null && model.isReady) {
        model.position = p;
        model.paint(canvas);
      } else {
        _fallback(canvas, p, _ownerColor(id), 10);
      }
      final hp = _number(state['health']);
      final maxHp = _number(state['maxHealth']);
      if (hp != null && maxHp != null && maxHp > 0) {
        _healthBar(
          canvas,
          p.translate(0, -(model?.height ?? 54) * 0.69),
          40,
          hp / maxHp,
        );
      }
    }
    canvas.restore();
  }

  double modelHeight(Monster3D? model, double fallback) =>
      model?.height ?? fallback;

  @override
  bool shouldRepaint(covariant _Arena3DActorPainter oldDelegate) => true;
}
