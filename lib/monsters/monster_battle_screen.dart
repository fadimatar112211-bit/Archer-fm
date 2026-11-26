import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'monster_army.dart';
import 'monster_combat.dart';
import 'monster_combat_resolver.dart';
import 'monster_match_combat_loop.dart';
import 'monster_match_runtime.dart';
import 'monster_models.dart';
import 'monster_projectile_manager.dart';
import 'monster_ranged_attack_handler.dart';

class MonsterBattleScreen extends StatefulWidget {
  const MonsterBattleScreen({super.key});

  @override
  State<MonsterBattleScreen> createState() => _MonsterBattleScreenState();
}

class _MonsterBattleScreenState extends State<MonsterBattleScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  late MonsterMatchRuntime _runtime;
  late MonsterArmy _left;
  late MonsterArmy _right;
  final math.Random _rng = math.Random(7);
  int _tickCount = 0;
  String _log = 'المعركة بدأت';

  static MonsterCatalog _catalog() => MonsterCatalog({
        MonsterType.bogMonster: MonsterDefinition(
          type: MonsterType.bogMonster,
          baseStats: MonsterStats(
            maxHealth: 140,
            damage: 12,
            moveSpeed: 45,
            attackRange: 28,
            attackCooldown: const Duration(milliseconds: 900),
            purchaseCost: 30,
          ),
        ),
        MonsterType.werewolf: MonsterDefinition(
          type: MonsterType.werewolf,
          baseStats: MonsterStats(
            maxHealth: 100,
            damage: 14,
            moveSpeed: 75,
            attackRange: 24,
            attackCooldown: const Duration(milliseconds: 650),
            purchaseCost: 35,
          ),
        ),
        MonsterType.stoneGolem: MonsterDefinition(
          type: MonsterType.stoneGolem,
          baseStats: MonsterStats(
            maxHealth: 220,
            damage: 18,
            moveSpeed: 32,
            attackRange: 34,
            attackCooldown: const Duration(milliseconds: 1300),
            purchaseCost: 55,
          ),
        ),
        MonsterType.blindStalker: MonsterDefinition(
          type: MonsterType.blindStalker,
          baseStats: MonsterStats(
            maxHealth: 95,
            damage: 16,
            moveSpeed: 70,
            attackRange: 24,
            attackCooldown: const Duration(milliseconds: 700),
            purchaseCost: 40,
          ),
        ),
      });

  @override
  void initState() {
    super.initState();
    _setup();
    _ticker = createTicker(_onTick)..start();
  }

  void _setup() {
    final catalog = _catalog();
    // Left army: mixed 4 types (5 each)
    _left = MonsterArmy(
      ownerId: 'p1',
      idPrefix: 'p1',
      catalog: catalog,
      selection: InitialArmySelection({
        MonsterType.bogMonster: 5,
        MonsterType.werewolf: 5,
        MonsterType.stoneGolem: 5,
        MonsterType.blindStalker: 5,
      }),
      castleX: 120,
      castleY: 300,
    );
    // Right army: mixed 4 types
    _right = MonsterArmy(
      ownerId: 'p2',
      idPrefix: 'p2',
      catalog: catalog,
      selection: InitialArmySelection({
        MonsterType.bogMonster: 5,
        MonsterType.werewolf: 5,
        MonsterType.stoneGolem: 5,
        MonsterType.blindStalker: 5,
      }),
      castleX: 680,
      castleY: 300,
    );
    // thin out to keep perf reasonable: keep 3 per type
    void thin(MonsterArmy a) {
      final keep = <MonsterType, int>{for (final t in MonsterType.values) t: 0};
      for (final u in a.units.toList()) {
        if (keep[u.type]! >= 3) {
          u.applyDamage(u.health);
          a.removeDefeated(u.id);
        } else {
          keep[u.type] = keep[u.type]! + 1;
        }
      }
    }
    thin(_left);
    thin(_right);
    // position armies apart
    for (final u in _left.units) {
      u.positionX = 140 + _rng.nextDouble() * 120;
      u.positionY = 140 + _rng.nextDouble() * 320;
    }
    for (final u in _right.units) {
      u.positionX = 540 + _rng.nextDouble() * 120;
      u.positionY = 140 + _rng.nextDouble() * 320;
    }

    final pm = MonsterProjectileManager(maxActiveProjectiles: 64);
    _runtime = MonsterMatchRuntime(
      armies: [_left, _right],
      combatLoop: MonsterMatchCombatLoop(
        combat: const MonsterCombatController(),
        resolver: const MonsterCombatResolver(),
        rangedHandler: const MonsterRangedAttackHandler(),
        projectiles: pm,
        projectileSpeed: 220,
        projectileId: (n) => 'proj-$n',
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _tickCount++;
    final now = DateTime.now();

    // simple AI: move each alive unit toward nearest enemy
    final all = _runtime.liveUnits;
    for (final u in all) {
      if (!u.isAlive) continue;
      MonsterUnit? target;
      double best = double.infinity;
      for (final o in all) {
        if (o.ownerId == u.ownerId || !o.isAlive) continue;
        final dx = o.positionX - u.positionX;
        final dy = o.positionY - u.positionY;
        final d2 = dx * dx + dy * dy;
        if (d2 < best) { best = d2; target = o; }
      }
      if (target != null) {
        final dx = target.positionX - u.positionX;
        final dy = target.positionY - u.positionY;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d > u.stats.attackRange * 0.8) {
          final sp = u.stats.moveSpeed * dt;
          u.positionX += (dx / d) * sp;
          u.positionY += (dy / d) * sp;
        }
      }
    }

    _runtime.tick(now: now, elapsed: Duration(microseconds: (dt * 1e6).round()));
    if (_tickCount % 6 == 0 && mounted) setState(() {});
  }

  void _spawn(MonsterType type, String owner) {
    final army = owner == 'p1' ? _left : _right;
    final res = army.purchaseAtomically(
      type: type,
      currentResources: 9999,
      tryDebit: (_) => true,
      refund: (_) {},
    );
    if (res != null) {
      res.unit.positionX = owner == 'p1' ? 160 + _rng.nextDouble() * 80 : 560 + _rng.nextDouble() * 80;
      res.unit.positionY = 160 + _rng.nextDouble() * 280;
      setState(() => _log = 'تم استدعاء ${_name(type)}');
    }
  }

  String _name(MonsterType t) {
    switch (t) {
      case MonsterType.bogMonster: return 'وحش المستنقع';
      case MonsterType.werewolf: return 'المستذئب';
      case MonsterType.stoneGolem: return 'غولم الحجر';
      case MonsterType.blindStalker: return 'المطارد الأعمى';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B151D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A1E2D),
        title: const Text('ساحة الوحوش - Archer FM', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () { setState(_setup); }, child: const Text('إعادة', style: TextStyle(color: Color(0xFFFFB74D)))),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth;
                final h = c.maxHeight;
                Offset toScreen(double x, double y) => Offset(x / 800 * w, y / 600 * h);
                return Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0xFF2D2433), Color(0xFF1A141A)],
                    ),
                    border: Border.all(color: const Color(0xFF5D4A52)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(children: [
                      Positioned.fill(child: CustomPaint(painter: _ArenaPainter())),
                      _runtime.buildBattleLayer(
                        worldToScreen: toScreen,
                        unitSize: 64,
                        projectileSize: 8,
                        onCombatHit: (attackerId, center, radius, damage) {
                          final attacker = _runtime.liveUnits.where((u) => u.id == attackerId).cast<MonsterUnit?>().firstWhere((u) => u != null, orElse: () => null);
                          if (attacker == null) return;
                          for (final u in _runtime.liveUnits) {
                            if (u.ownerId == attacker.ownerId || !u.isAlive) continue;
                            final dx = u.positionX - attacker.positionX;
                            final dy = u.positionY - attacker.positionY;
                            if (dx*dx + dy*dy <= (radius*1.2)*(radius*1.2)) {
                              u.applyDamage(damage);
                            }
                          }
                        },
                      ),
                      Positioned(top: 8, right: 8, child: _info()),
                    ]),
                  ),
                );
              }),
            ),
            _controls(),
          ],
        ),
      ),
    );
  }

  Widget _info() {
    final leftAlive = _left.aliveCount;
    final rightAlive = _right.aliveCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
      child: Text('P1: $leftAlive  |  P2: $rightAlive  •  $_log',
          style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }

  Widget _controls() {
    Widget btn(MonsterType t, Color c) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        onPressed: () => _spawn(t, 'p1'),
        style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: const Size(0, 32), textStyle: const TextStyle(fontSize: 11)),
        child: Text(_name(t)),
      ),
    );
    return Container(
      color: const Color(0xFF241A24),
      padding: const EdgeInsets.all(6),
      child: Wrap(alignment: WrapAlignment.center, children: [
        const Padding(padding: EdgeInsets.all(6), child: Text('استدعاء P1:', style: TextStyle(color: Colors.white70, fontSize: 11))),
        btn(MonsterType.bogMonster, const Color(0xFF5D7A3A)),
        btn(MonsterType.werewolf, const Color(0xFF7A5D3A)),
        btn(MonsterType.stoneGolem, const Color(0xFF6A6A6A)),
        btn(MonsterType.blindStalker, const Color(0xFF5A3A7A)),
      ]),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x22FFFFFF)..strokeWidth = 1;
    for (var i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var i = 1; i < 6; i++) {
      final y = size.height * i / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
