import 'package:archer_fm/combat/combat_engine.dart';
import 'package:archer_fm/combat/weapon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('three distinct weapons exist for every hero', () {
    for(final hero in ['ranger','flame','shadow','storm']) { expect(weaponsForHero(hero),hasLength(3)); }
    expect(weaponCatalog.map((w)=>w.id).toSet(),hasLength(12));
  });
  test('weapon progression is bounded at level 40', () {
    final w=weaponById('ranger_bow');
    expect(w.statsAt(40).damage,greaterThan(w.statsAt(1).damage));
    expect(()=>w.statsAt(41),throwsRangeError);
    expect(()=>w.upgradeCost(40),throwsStateError);
  });
  group('manual combat engine',(){
    late CombatEngine engine;
    setUp(()=>engine=CombatEngine());
    ManualAttackCommand cmd({String id='a1',String actor='p1',String hero='ranger',String weapon='ranger_bow',int level=1,int time=1000,List<CombatTarget>? targets})=>ManualAttackCommand(
      attackId:id,actorId:actor,heroId:hero,weaponId:weapon,weaponLevel:level,atMs:time,origin:const CombatPoint(0,0),
      targets:targets??const [CombatTarget(id:'near',position:CombatPoint(3,0),isAlive:true)]);
    test('one explicit attack returns one damage event',(){final r=engine.resolve(cmd());expect(r.accepted,isTrue);expect(r.damageByTarget,{'near':28});});
    test('attack id cannot be applied twice',(){engine.resolve(cmd());expect(engine.resolve(cmd()).rejection,AttackRejection.duplicate);});
    test('rejects mismatched hero and locked weapon',(){
      expect(engine.resolve(cmd(hero:'flame')).rejection,AttackRejection.wrongHero);
      expect(engine.resolve(cmd(id:'a2',weapon:'ranger_volley')).rejection,AttackRejection.locked);
    });
    test('enforces cooldown and range',(){
      expect(engine.resolve(cmd()).accepted,isTrue);
      expect(engine.resolve(cmd(id:'a2',time:1100)).rejection,AttackRejection.cooldown);
      expect(engine.resolve(cmd(id:'a3',actor:'p2',targets:const [CombatTarget(id:'far',position:CombatPoint(99,0),isAlive:true)])).rejection,AttackRejection.noTarget);
    });
    test('piercing selects nearest live targets up to target cap',(){
      final r=engine.resolve(cmd(weapon:'ranger_volley',level:10,targets:const [
        CombatTarget(id:'third',position:CombatPoint(3,0),isAlive:true),
        CombatTarget(id:'first',position:CombatPoint(1,0),isAlive:true),
        CombatTarget(id:'second',position:CombatPoint(2,0),isAlive:true),
        CombatTarget(id:'dead',position:CombatPoint(.5,0),isAlive:false),
        CombatTarget(id:'far',position:CombatPoint(80,0),isAlive:true),
      ]));
      expect(r.damageByTarget.keys,['first','second','third']);
    });
  });
}
