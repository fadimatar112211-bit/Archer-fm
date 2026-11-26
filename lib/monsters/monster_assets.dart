import 'monster_models.dart';

class Monster3DAssets {
  const Monster3DAssets({
    required this.id,
    required this.bin,
    required this.glb,
    required this.role,
    this.heightScale = 90,
  });
  final String id;
  final String bin;
  final String glb;
  final String role; // normal, fast, heavy, stealth
  final double heightScale;
}

/// Legacy 2D animation assets kept for compatibility with animation tests.
class MonsterAnimationAssets {
  const MonsterAnimationAssets({
    required this.idle,
    required this.attack,
    required this.death,
    this.frameWidth = 96,
    this.frameHeight = 96,
    this.frameCount = 4,
    this.walkFrameDuration = const Duration(milliseconds: 110),
    this.attackFrameDuration = const Duration(milliseconds: 85),
    this.deathFrameDuration = const Duration(milliseconds: 100),
  });

  final String idle;
  final String? attack;
  final String? death;
  final int frameWidth;
  final int frameHeight;
  final int frameCount;
  final Duration walkFrameDuration;
  final Duration attackFrameDuration;
  final Duration deathFrameDuration;
}

class MonsterAssetCatalog {
  MonsterAssetCatalog._();

  static const Map<MonsterType, Monster3DAssets> assets3d = {
    MonsterType.bogMonster: Monster3DAssets(
      id: 'bog-monster',
      bin: 'assets/monsters/bog-monster/bog-monster.bin',
      glb: 'assets/monsters/bog-monster/bog-monster.glb',
      role: 'normal',
      heightScale: 80,
    ),
    MonsterType.werewolf: Monster3DAssets(
      id: 'werewolf',
      bin: 'assets/monsters/werewolf/werewolf.bin',
      glb: 'assets/monsters/werewolf/werewolf.glb',
      role: 'fast',
      heightScale: 78,
    ),
    MonsterType.stoneGolem: Monster3DAssets(
      id: 'stone-golem',
      bin: 'assets/monsters/stone-golem/stone-golem.bin',
      glb: 'assets/monsters/stone-golem/stone-golem.glb',
      role: 'heavy',
      heightScale: 95,
    ),
    MonsterType.blindStalker: Monster3DAssets(
      id: 'blind-stalker',
      bin: 'assets/monsters/blind-stalker/blind-stalker.bin',
      glb: 'assets/monsters/blind-stalker/blind-stalker.glb',
      role: 'stealth',
      heightScale: 72,
    ),
  };

  // Legacy SVG map kept so older animation tests/code still resolve.
  static const Map<MonsterType, MonsterAnimationAssets> assets = {
    MonsterType.werewolf: MonsterAnimationAssets(
      idle: 'assets/monsters/legacy/enemy_runner.svg',
      attack: 'assets/monsters/legacy/enemy_runner_attack.svg',
      death: 'assets/monsters/legacy/enemy_runner_death.svg',
    ),
    MonsterType.stoneGolem: MonsterAnimationAssets(
      idle: 'assets/monsters/legacy/enemy_tank.svg',
      attack: 'assets/monsters/legacy/enemy_tank_attack.svg',
      death: 'assets/monsters/legacy/enemy_tank_death.svg',
    ),
    MonsterType.blindStalker: MonsterAnimationAssets(
      idle: 'assets/monsters/legacy/enemy_stalker.svg',
      attack: 'assets/monsters/legacy/enemy_stalker_attack.svg',
      death: 'assets/monsters/legacy/enemy_stalker_death.svg',
    ),
    MonsterType.bogMonster: MonsterAnimationAssets(
      idle: 'assets/monsters/legacy/enemy_ranged.svg',
      attack: null,
      death: null,
    ),
  };

  static MonsterAnimationAssets forType(MonsterType type) => assets[type]!;
  static Monster3DAssets forType3D(MonsterType type) => assets3d[type]!;
}
