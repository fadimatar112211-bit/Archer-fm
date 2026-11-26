import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../hero/hero3d.dart';
import '../hero/hero_viewer_screen.dart';
import '../monsters/monster3d.dart';
import '../monsters/monster_assets.dart';
import '../monsters/monster_models.dart';
import 'arena_camera.dart';
import 'arena_map.dart';
import 'arena_match.dart';

class ArenaScreen extends StatefulWidget {
  const ArenaScreen({super.key});

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen> with SingleTickerProviderStateMixin {
  ArenaMap? _map;
  ArenaMatch? _match;
  ArenaCamera _camera = ArenaCamera();
  ui.Picture? _terrain;

  final Map<String, Hero3D> _heroes = {};
  final Map<String, Monster3D> _monsters = {};
  final Map<String, (double, double)> _lastMonsterPositions = {};
  final Map<String, double> _monsterDeathTimers = {};

  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  Offset _stick = Offset.zero;
  Offset _stickOrigin = Offset.zero;
  bool _stickActive = false;
  bool _attackCooldownReady = true;
  double _attackCooldown = 0;

  String? _error;
  bool _loading = true;

  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final map = await ArenaMap.load();
      final match = ArenaMatch(map: map);
      _camera.targetX = match.localHero.x;
      _camera.targetY = match.localHero.y;
      final terrain = _buildTerrain(map);
      for (var i = 0; i < match.heroes.length; i++) {
        final state = match.heroes[i];
        final hero = Hero3D(state.heroId, height: 90);
        hero.onSound = (_) {};
        hero.load().then((_) {
          if (mounted) setState(() {});
        }).catchError((_) {});
        _heroes[state.id] = hero;
      }
      if (!mounted) return;
      setState(() {
        _map = map;
        _match = match;
        _terrain = terrain;
        _loading = false;
      });
      _ticker = createTicker(_onTick)..start();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    for (final hero in _heroes.values) {
      hero.dispose();
    }
    for (final monster in _monsters.values) {
      monster.dispose();
    }
    _match?.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _lastTick = elapsed;
    final match = _match;
    if (match == null) return;

    if (_stickActive) {
      match.moveHeroBy(match.localHero, _stick.dx, _stick.dy, Duration(microseconds: (dt * 1e6).round()));
    }
    _attackCooldown = math.max(0, _attackCooldown - dt);
    _attackCooldownReady = _attackCooldown <= 0;

    match.update(Duration(microseconds: (dt * 1e6).round()));

    // Hero visual state.
    for (final state in match.heroes) {
      final hero = _heroes[state.id];
      if (hero == null || !hero.isReady) continue;
      if (!state.isAlive) {
        if (!hero.isDead) hero.hurt(hero.hp > 0 ? hero.hp : 100);
      } else if (hero.isDead) {
        hero.revive(state.health);
      } else {
        hero.hp = state.health;
      }
      final moving = state.isAlive && state.path.isNotEmpty;
      hero.update(dt, moving ? Offset(state.facingX, state.facingY) : Offset.zero);
    }

    // Monster views.
    final attackingIds = match.attackingMonsterIds;
    for (final unit in match.liveMonsters) {
      final view = _ensureMonster(unit);
      if (view == null) continue;
      if (view.isReady) {
        view.hp = unit.health;
        final previous = _lastMonsterPositions[unit.id];
        var moving = false;
        Offset direction = Offset.zero;
        if (previous != null) {
          final dx = unit.positionX - previous.$1;
          final dy = unit.positionY - previous.$2;
          if (dx * dx + dy * dy > 0.0001) {
            moving = true;
            final length = math.sqrt(dx * dx + dy * dy);
            direction = Offset(dx / length, dy / length);
          }
        }
        _lastMonsterPositions[unit.id] = (unit.positionX, unit.positionY);
        view.update(
          dt,
          moveDir: moving ? direction : null,
          attacking: attackingIds.contains(unit.id),
        );
      }
    }

    // Dying monsters.
    for (final unit in match.dyingMonsters) {
      final view = _monsters[unit.id] ?? _ensureMonster(unit);
      if (view == null) continue;
      if (!_monsterDeathTimers.containsKey(unit.id)) {
        _monsterDeathTimers[unit.id] = 2.3;
        if (view.isReady && !view.isDead) view.takeHit(view.hp + 1);
      }
      if (view.isReady) view.update(dt);
      final remaining = (_monsterDeathTimers[unit.id] ?? 0) - dt;
      _monsterDeathTimers[unit.id] = remaining;
      if (remaining <= 0) {
        match.runtime.completeDeathAnimation(unit.id);
        _monsterDeathTimers.remove(unit.id);
        _monsters.remove(unit.id)?.dispose();
        _lastMonsterPositions.remove(unit.id);
      }
    }

    // Camera follow.
    final heroState = match.localHero;
    _camera.targetX += (heroState.x - _camera.targetX) * 0.12;
    _camera.targetY += (heroState.y - _camera.targetY) * 0.12;

    // Log tail from match.
    if (match.events.isNotEmpty && (_log.isEmpty || _log.first != match.events.first)) {
      _log.insert(0, match.events.first);
      if (_log.length > 8) _log.removeRange(8, _log.length);
    }

    if (mounted) setState(() {});
  }

  Monster3D? _ensureMonster(MonsterUnit unit) {
    var view = _monsters[unit.id];
    if (view != null) return view;
    final asset = MonsterAssetCatalog.forType3D(unit.type);
    view = Monster3D(asset.id, height: asset.heightScale);
    view.isStealth = asset.role == 'stealth';
    view.isHeavyAoe = asset.role == 'heavy';
    final ownerId = unit.ownerId;
    view.onHit = (center, radius, damage) {
      final match = _match;
      if (match == null) return;
      final world = _camera.screenToWorld(center, context.size ?? Size.zero);
      final meters = radius / _camera.zoom;
      for (final other in match.liveMonsters) {
        if (other.ownerId == ownerId || !other.isAlive) continue;
        final dx = other.positionX - world.$1;
        final dy = other.positionY - world.$2;
        if (dx * dx + dy * dy <= (meters * 1.2) * (meters * 1.2)) {
          other.applyDamage(damage);
        }
      }
      for (final hero in match.heroes) {
        if (hero.ownerId == ownerId || !hero.isAlive) continue;
        final dx = hero.x - world.$1;
        final dy = hero.y - world.$2;
        if (dx * dx + dy * dy <= (meters * 1.2) * (meters * 1.2)) {
          hero.applyDamage(damage);
        }
      }
    };
    view.load().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {});
    _monsters[unit.id] = view;
    return view;
  }

  void _attack() {
    final match = _match;
    if (match == null || !_attackCooldownReady) return;
    final result = match.attackWithHero(match.localHero);
    _attackCooldown = 0.35;
    _attackCooldownReady = false;
    _log.insert(0, result ? 'هجوم' : 'لا هدف');
    if (_log.length > 8) _log.removeRange(8, _log.length);
  }

  void _handleMapTap(Offset localPosition, Size size) {
    final match = _match;
    if (match == null) return;
    final world = _camera.screenToWorld(localPosition, size);
    match.moveHeroTo(match.localHero, world.$1, world.$2);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B1310),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _map == null || _match == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B1310),
        body: Center(
          child: Text(_error ?? 'تعذر تحميل الخريطة', style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    final map = _map!;
    final match = _match!;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1310),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(builder: (context, constraints) {
                final viewport = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _handleMapTap(details.localPosition, viewport),
                  child: CustomPaint(
                    painter: _ArenaPainter(
                      map: map,
                      match: match,
                      camera: _camera,
                      terrain: _terrain,
                      heroes: _heroes,
                      monsters: _monsters,
                      viewport: viewport,
                    ),
                    size: viewport,
                  ),
                );
              }),
            ),
            _buildHud(map, match, size),
            _buildControls(match, size),
          ],
        ),
      ),
    );
  }

  Widget _buildHud(ArenaMap map, ArenaMatch match, Size size) {
    final hero = match.localHero;
    final crystals = match.aliveCrystalsCount('P1');
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${map.name} · بلورات P1: $crystals/7 · HP: ${hero.health}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: Text(
              'وحوش: ${match.liveMonsters.length} · ${_log.isEmpty ? 'جاهز' : _log.first}',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(ArenaMatch match, Size size) {
    return Positioned(
      bottom: 10,
      left: 10,
      right: 10,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildJoystick(),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      _camera.zoom -= 2;
                      _camera.clampZoom();
                    },
                    icon: const Icon(Icons.remove, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () {
                      _camera.zoom += 2;
                      _camera.clampZoom();
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _attack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB23A3A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('هجوم'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HeroViewerScreen()),
                  );
                },
                child: const Text('الأبطال', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJoystick() {
    return GestureDetector(
      onPanStart: (details) {
        _stickOrigin = details.localPosition;
        _stickActive = true;
      },
      onPanUpdate: (details) {
        final delta = details.localPosition - _stickOrigin;
        final length = delta.distance;
        if (length > 42) {
          _stick = delta / length * 42;
        } else {
          _stick = delta;
        }
      },
      onPanEnd: (_) {
        _stick = Offset.zero;
        _stickActive = false;
      },
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38),
        ),
        child: Center(
          child: Transform.translate(
            offset: _stick,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white54,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  ui.Picture _buildTerrain(ArenaMap map) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var row = 0; row < ArenaMap.size; row++) {
      for (var col = 0; col < ArenaMap.size; col++) {
        final cell = ArenaCell(col, row);
        final z = map.charAt(col, row) == '~' ? -0.8 : map.heightAtCell(cell);
        final char = map.charAt(col, row);
        Color color;
        switch (char) {
          case '=':
            color = const Color(0xFFC9A86A);
            break;
          case 'B':
          case 'b':
            color = const Color(0xFF8B5A2B);
            break;
          case '.':
            color = Color.lerp(
              const Color(0xFF3F6B35),
              const Color(0xFF6FA05A),
              (z / 1.5).clamp(0.0, 1.0),
            )!;
            break;
          case ':':
            color = const Color(0xFF6D6255);
            break;
          case '~':
            color = const Color(0xFF2F6D8E);
            break;
          case '#':
            color = const Color(0xFF7A6A55);
            break;
          case 'R':
            color = const Color(0xFF5A534A);
            break;
          case 'C':
            color = const Color(0xFF4A3F55);
            break;
          case 'T':
            color = const Color(0xFF55606A);
            break;
          case 'K':
            color = const Color(0xFF5A3F6A);
            break;
          default:
            color = const Color(0xFF334033);
        }
        final bl = map.cellCorner(col, row);
        final br = map.cellCorner(col, row, right: true);
        final tr = map.cellCorner(col, row, right: true, top: true);
        final tl = map.cellCorner(col, row, top: true);
        final p0 = ArenaCamera.project(bl.$1, bl.$2, z);
        final p1 = ArenaCamera.project(br.$1, br.$2, z);
        final p2 = ArenaCamera.project(tr.$1, tr.$2, z);
        final p3 = ArenaCamera.project(tl.$1, tl.$2, z);
        final path = ui.Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close();
        canvas.drawPath(path, Paint()..color = color);
      }
    }
    // faint grid
    final gridPaint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (var i = 0; i <= ArenaMap.size; i++) {
      final a = ArenaCamera.project(-48 + i.toDouble(), -48, 0);
      final b = ArenaCamera.project(-48 + i.toDouble(), 48, 0);
      canvas.drawLine(a, b, gridPaint);
      final c = ArenaCamera.project(-48, -48 + i.toDouble(), 0);
      final d = ArenaCamera.project(48, -48 + i.toDouble(), 0);
      canvas.drawLine(c, d, gridPaint);
    }
    return recorder.endRecording();
  }
}

class _ArenaPainter extends CustomPainter {
  _ArenaPainter({
    required this.map,
    required this.match,
    required this.camera,
    required this.terrain,
    required this.heroes,
    required this.monsters,
    required this.viewport,
  });

  final ArenaMap map;
  final ArenaMatch match;
  final ArenaCamera camera;
  final ui.Picture? terrain;
  final Map<String, Hero3D> heroes;
  final Map<String, Monster3D> monsters;
  final Size viewport;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final target = ArenaCamera.project(camera.targetX, camera.targetY, 0);
    canvas.translate(size.width / 2 - target.dx * (camera.zoom / ArenaCamera.baseScale),
        size.height / 2 - target.dy * (camera.zoom / ArenaCamera.baseScale));
    canvas.scale(camera.zoom / ArenaCamera.baseScale);
    if (terrain != null) canvas.drawPicture(terrain!);
    canvas.restore();

    // Depth-sorted dynamic objects.
    final drawables = <_Drawable>[];

    // Obstacles.
    for (final wall in map.walls) {
      drawables.add(_Drawable(
        camera.worldToScreen(wall.rect.centerX, wall.rect.centerY, 0, size).dy,
        (canvas) => _drawPrism(canvas, camera, size, wall.rect, 1.8, const Color(0xFF8A7A62)),
      ));
    }
    for (final rock in map.rocks) {
      drawables.add(_Drawable(
        camera.worldToScreen(rock.rect.centerX, rock.rect.centerY, 0, size).dy,
        (canvas) => _drawPrism(canvas, camera, size, rock.rect, 1.0, const Color(0xFF5A534A)),
      ));
    }
    for (final tower in map.towers) {
      drawables.add(_Drawable(
        camera.worldToScreen(tower.rect.centerX, tower.rect.centerY, 0, size).dy,
        (canvas) => _drawPrism(canvas, camera, size, tower.rect, 5.0, const Color(0xFF6A7A8A)),
      ));
    }
    for (final player in map.players) {
      drawables.add(_Drawable(
        camera.worldToScreen(player.castle.centerX, player.castle.centerY, 0, size).dy,
        (canvas) => _drawPrism(canvas, camera, size, player.castle, 6.0, Color(player.colorValue)),
      ));
    }
    for (final crystal in map.crystals) {
      if (!crystal.isAlive) continue;
      final color = Color(map.players.firstWhere((p) => p.id == crystal.ownerId).colorValue);
      drawables.add(_Drawable(
        camera.worldToScreen(crystal.x, crystal.y, 0, size).dy,
        (canvas) {
          final center = camera.worldToScreen(crystal.x, crystal.y, 3.0, size);
          final ground = camera.worldToScreen(crystal.x, crystal.y, 0, size);
          final paint = Paint()..color = color;
          final path = ui.Path()
            ..moveTo(center.dx, center.dy - 18)
            ..lineTo(center.dx + 12, center.dy)
            ..lineTo(center.dx, center.dy + 12)
            ..lineTo(center.dx - 12, center.dy)
            ..close();
          canvas.drawPath(path, paint);
          // health bar
          final barWidth = 26.0;
          final left = ground.dx - barWidth / 2;
          final top = ground.dy - 30;
          canvas.drawRect(Rect.fromLTWH(left, top, barWidth, 4), Paint()..color = Colors.black54);
          canvas.drawRect(Rect.fromLTWH(left, top, barWidth * crystal.healthFraction, 4), Paint()..color = Colors.greenAccent);
        },
      ));
    }
    for (final camp in map.camps) {
      final state = match.camps.firstWhere((c) => c.camp.id == camp.id, orElse: () => match.camps.first);
      final color = _campColor(camp.type);
      drawables.add(_Drawable(
        camera.worldToScreen(camp.x, camp.y, 0, size).dy,
        (canvas) {
          final center = camera.worldToScreen(camp.x, camp.y, 0.5, size);
          canvas.drawCircle(center, 6, Paint()..color = color);
          if (state.aliveCount == 0) {
            final text = TextPainter(
              text: TextSpan(
                text: state.timer.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            text.paint(canvas, Offset(center.dx - text.width / 2, center.dy - 18));
          }
        },
      ));
    }
    for (final point in map.controlPoints) {
      drawables.add(_Drawable(
        camera.worldToScreen(point.x, point.y, 0, size).dy,
        (canvas) {
          final center = camera.worldToScreen(point.x, point.y, 0, size);
          canvas.drawCircle(center, point.captureRadius * (camera.zoom / ArenaCamera.baseScale), Paint()
            ..color = const Color(0x55FFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
        },
      ));
    }

    // Heroes.
    for (final state in match.heroes) {
      final hero = heroes[state.id];
      if (hero == null) continue;
      final screen = camera.worldToScreen(state.x, state.y, 0, size);
      drawables.add(_Drawable(
        screen.dy,
        (canvas) {
          final heroSize = 46.0;
          hero.position = Offset(heroSize / 2, heroSize * 0.88);
          hero.height = heroSize * 0.85;
          canvas.save();
          canvas.translate(screen.dx - heroSize / 2, screen.dy - heroSize);
          hero.paint(canvas);
          canvas.restore();
          // health bar
          final barWidth = 28.0;
          canvas.drawRect(Rect.fromLTWH(screen.dx - barWidth / 2, screen.dy - 52, barWidth, 4), Paint()..color = Colors.black54);
          canvas.drawRect(Rect.fromLTWH(screen.dx - barWidth / 2, screen.dy - 52, barWidth * state.healthFraction, 4), Paint()..color = Colors.lightGreenAccent);
        },
      ));
    }

    // Monsters.
    for (final unit in [...match.liveMonsters, ...match.dyingMonsters]) {
      final view = monsters[unit.id];
      if (view == null || !view.isReady) continue;
      final screen = camera.worldToScreen(unit.positionX, unit.positionY, 0, size);
      if (screen.dx < -80 || screen.dx > size.width + 80 || screen.dy < -80 || screen.dy > size.height + 80) {
        continue;
      }
      drawables.add(_Drawable(
        screen.dy,
        (canvas) {
          final monsterSize = 42.0;
          view.position = Offset(monsterSize / 2, monsterSize * 0.88);
          view.height = monsterSize * 0.85;
          canvas.save();
          canvas.translate(screen.dx - monsterSize / 2, screen.dy - monsterSize);
          view.paint(canvas);
          canvas.restore();
          if (unit.isAlive) {
            final barWidth = 24.0;
            final fraction = (unit.health / unit.stats.maxHealth).clamp(0.0, 1.0);
            canvas.drawRect(Rect.fromLTWH(screen.dx - barWidth / 2, screen.dy - 46, barWidth, 3), Paint()..color = Colors.black54);
            canvas.drawRect(Rect.fromLTWH(screen.dx - barWidth / 2, screen.dy - 46, barWidth * fraction, 3), Paint()..color = Colors.redAccent);
          }
        },
      ));
    }

    // Projectiles.
    for (final projectile in match.projectiles) {
      final screen = camera.worldToScreen(projectile.positionX, projectile.positionY, 0.5, size);
      canvas.drawCircle(screen, 4, Paint()..color = const Color(0xFF7DEBFF));
    }

    drawables.sort((a, b) => a.depth.compareTo(b.depth));
    for (final drawable in drawables) {
      drawable.paint(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) => true;
}

class _Drawable {
  _Drawable(this.depth, this.paint);
  final double depth;
  final void Function(Canvas canvas) paint;
}

void _drawPrism(Canvas canvas, ArenaCamera camera, Size size, ArenaRect rect, double height, Color color) {
  final bl0 = camera.worldToScreen(rect.left, rect.bottom, 0, size);
  final br0 = camera.worldToScreen(rect.right, rect.bottom, 0, size);
  final tr0 = camera.worldToScreen(rect.right, rect.top, 0, size);
  final bl1 = camera.worldToScreen(rect.left, rect.bottom, height, size);
  final br1 = camera.worldToScreen(rect.right, rect.bottom, height, size);
  final tr1 = camera.worldToScreen(rect.right, rect.top, height, size);
  final tl1 = camera.worldToScreen(rect.left, rect.top, height, size);

  final sidePaint = Paint()..color = color.withValues(alpha: 0.72);
  final topPaint = Paint()..color = color;

  // South face
  canvas.drawPath(
    ui.Path()
      ..moveTo(bl0.dx, bl0.dy)
      ..lineTo(br0.dx, br0.dy)
      ..lineTo(br1.dx, br1.dy)
      ..lineTo(bl1.dx, bl1.dy)
      ..close(),
    sidePaint,
  );
  // East face
  canvas.drawPath(
    ui.Path()
      ..moveTo(br0.dx, br0.dy)
      ..lineTo(tr0.dx, tr0.dy)
      ..lineTo(tr1.dx, tr1.dy)
      ..lineTo(br1.dx, br1.dy)
      ..close(),
    sidePaint,
  );
  // Top
  canvas.drawPath(
    ui.Path()
      ..moveTo(tl1.dx, tl1.dy)
      ..lineTo(tr1.dx, tr1.dy)
      ..lineTo(br1.dx, br1.dy)
      ..lineTo(bl1.dx, bl1.dy)
      ..close(),
    topPaint,
  );
}

Color _campColor(ArenaCampType type) {
  switch (type) {
    case ArenaCampType.goblin:
      return const Color(0xFF7A5D3A);
    case ArenaCampType.wolf:
      return const Color(0xFF8A6A3A);
    case ArenaCampType.golem:
      return const Color(0xFF6A6A6A);
    case ArenaCampType.crystalDrake:
      return const Color(0xFF5A3A7A);
  }
}
