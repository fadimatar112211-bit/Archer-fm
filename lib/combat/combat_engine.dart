import 'dart:math' as math;
import 'weapon.dart';

class CombatPoint {
  const CombatPoint(this.x,this.y);
  final double x,y;
  double distanceTo(CombatPoint other) { final dx=x-other.x, dy=y-other.y; return math.sqrt(dx*dx+dy*dy); }
}
class CombatTarget {
  const CombatTarget({required this.id,required this.position,required this.isAlive});
  final String id; final CombatPoint position; final bool isAlive;
}
class ManualAttackCommand {
  const ManualAttackCommand({required this.attackId,required this.actorId,required this.heroId,required this.weaponId,required this.weaponLevel,required this.atMs,required this.origin,required this.targets});
  final String attackId,actorId,heroId,weaponId;
  final int weaponLevel,atMs;
  final CombatPoint origin;
  final List<CombatTarget> targets;
}
enum AttackRejection { duplicate, unknownWeapon, wrongHero, locked, cooldown, noTarget }
class AttackResult {
  const AttackResult.accepted(this.attackId,this.damageByTarget): rejection=null;
  const AttackResult.rejected(this.attackId,this.rejection): damageByTarget=const {};
  final String attackId; final Map<String,int> damageByTarget; final AttackRejection? rejection;
  bool get accepted => rejection==null;
}

/// Resolves explicit player attack commands only. It never auto-fires.
class CombatEngine {
  final Set<String> _processedAttackIds={};
  final Map<String,int> _lastAttackAtByActor={};

  AttackResult resolve(ManualAttackCommand command) {
    if (_processedAttackIds.contains(command.attackId)) return AttackResult.rejected(command.attackId,AttackRejection.duplicate);
    _processedAttackIds.add(command.attackId);
    final matches=weaponCatalog.where((item)=>item.id==command.weaponId);
    if(matches.isEmpty) return AttackResult.rejected(command.attackId,AttackRejection.unknownWeapon);
    final weapon=matches.first;
    if(weapon.heroId!=command.heroId) return AttackResult.rejected(command.attackId,AttackRejection.wrongHero);
    if(command.weaponLevel<weapon.unlockLevel) return AttackResult.rejected(command.attackId,AttackRejection.locked);
    final stats=weapon.statsAt(command.weaponLevel);
    final last=_lastAttackAtByActor[command.actorId];
    if(last!=null && command.atMs-last<stats.cooldownMs) return AttackResult.rejected(command.attackId,AttackRejection.cooldown);
    final eligible=command.targets.where((t)=>t.isAlive && command.origin.distanceTo(t.position)<=stats.range).toList()
      ..sort((a,b)=>command.origin.distanceTo(a.position).compareTo(command.origin.distanceTo(b.position)));
    if(eligible.isEmpty) return AttackResult.rejected(command.attackId,AttackRejection.noTarget);
    _lastAttackAtByActor[command.actorId]=command.atMs;
    final hits=<String,int>{};
    for(final target in eligible.take(stats.targetCount)) { hits[target.id]=stats.damage; }
    return AttackResult.accepted(command.attackId,Map.unmodifiable(hits));
  }
  void resetActorCooldown(String actorId)=>_lastAttackAtByActor.remove(actorId);
}
