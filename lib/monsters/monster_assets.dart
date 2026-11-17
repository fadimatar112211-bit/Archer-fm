import 'monster_models.dart';

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

  static const Map<MonsterType, MonsterAnimationAssets> assets = {
    MonsterType.runner: MonsterAnimationAssets(
      idle: 'assets/monsters/legacy/enemy_runner.svg',
      attack: 'assets/monsters/legacy/enemy_runner_attack.svg',
      death: 'assets/monsters/legacy/enemy_runner_death.svg',
    ),
    MonsterType.tank: MonsterAnimationAssets(
      idle: 'assets/monsters/legacy/enemy_tank.svg',
      attack: 'assets/monsters/legacy/enemy_tank_attack.svg',
      death: 'assets/monsters/legacy/enemy_tank_death.svg',
    ),
    MonsterType.stalker: MonsterAnimationAssets(
      idle: 'assets/monsters/legacy/enemy_stalker.svg',
      attack: 'assets/monsters/legacy/enemy_stalker_attack.svg',
      death: 'assets/monsters/legacy/enemy_stalker_death.svg',
    ),
    // The legacy ranged sheet exists, but dedicated ranged attack/death
    // sheets were not found. Keep those states unset rather than mislabel
    // a melee animation as a ranged one.
    MonsterType.ranged: MonsterAnimationAssets(
      idle: 'assets/monsters/legacy/enemy_ranged.svg',
      attack: null,
      death: null,
    ),
  };

  static MonsterAnimationAssets forType(MonsterType type) => assets[type]!;
}
