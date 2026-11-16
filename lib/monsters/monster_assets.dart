import 'monster_models.dart';

class MonsterAnimationAssets {
  const MonsterAnimationAssets({
    required this.idle,
    required this.attack,
    required this.death,
  });

  final String idle;
  final String? attack;
  final String? death;
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
