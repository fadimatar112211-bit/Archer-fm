import 'monster_animation.dart';
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

  /// Creates a correctly configured visual controller for one launch monster.
  /// Ranged deliberately receives no fabricated melee/death sheets.
  static MonsterAnimationController createAnimation(MonsterType type) {
    final config = forType(type);
    MonsterSpriteSheet sheet(
      String asset,
      Duration duration, {
      required bool loop,
    }) =>
        MonsterSpriteSheet(
          asset: asset,
          frameWidth: config.frameWidth,
          frameHeight: config.frameHeight,
          frameCount: config.frameCount,
          frameDuration: duration,
          loop: loop,
        );

    return MonsterAnimationController(
      type: type,
      walkSheet: sheet(
        config.idle,
        config.walkFrameDuration,
        loop: true,
      ),
      attackSheet: config.attack == null
          ? null
          : sheet(
              config.attack!,
              config.attackFrameDuration,
              loop: false,
            ),
      deathSheet: config.death == null
          ? null
          : sheet(
              config.death!,
              config.deathFrameDuration,
              loop: false,
            ),
    );
  }
}
