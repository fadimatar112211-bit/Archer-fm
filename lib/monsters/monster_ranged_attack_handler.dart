import 'monster_combat.dart';
import 'monster_models.dart';
import 'monster_projectiles.dart';

/// Converts a ranged unit's combat intent into a server-owned projectile.
/// The match loop remains responsible for calling this only after accepting
/// the intent from its authoritative combat controller.
class MonsterRangedAttackHandler {
  const MonsterRangedAttackHandler();

  MonsterProjectile? tryCreate({
    required MonsterCombatIntent intent,
    required MonsterUnit source,
    required MonsterPositionedDamageTarget? target,
    required String projectileId,
    required double projectileSpeed,
  }) {
    if (!source.isAlive ||
        source.type != MonsterType.ranged ||
        source.ownerId.isEmpty ||
        !source.positionX.isFinite ||
        !source.positionY.isFinite ||
        intent.monsterId != source.id ||
        intent.targetId.isEmpty ||
        !intent.damage.isFinite ||
        intent.damage <= 0 ||
        intent.damage != source.stats.damage ||
        projectileId.isEmpty ||
        !projectileSpeed.isFinite ||
        projectileSpeed <= 0 ||
        target == null ||
        target.id != intent.targetId ||
        target.ownerId.isEmpty ||
        !target.isAlive ||
        target.ownerId == source.ownerId ||
        !target.positionX.isFinite ||
        !target.positionY.isFinite) {
      return null;
    }

    return MonsterProjectile(
      id: projectileId,
      source: source,
      targetId: target.id,
      projectileSpeed: projectileSpeed,
      positionX: source.positionX,
      positionY: source.positionY,
    );
  }
}
