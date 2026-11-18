import 'package:flutter/material.dart';

import '../hero/hero_assets.dart';
import '../hero/hero_catalog.dart';
import 'combat/hero_kit.dart';
import 'game_screen.dart';
import 'monsters/monster_models.dart';
import 'progress/hero_progress.dart';
import 'world/game_world.dart';

/// Pre-match setup: pick one of the four heroes and freely distribute the 20
/// free starting monsters across the four approved types (the confirmed rule
/// "any distribution among the four types"). The chosen distribution is passed
/// to `GameWorld` as `startingArmy`, so no code path silently replaces it.
class ArmySelectionScreen extends StatefulWidget {
  const ArmySelectionScreen({
    super.key,
    required this.loaderFactory,
    this.store,
  });

  final HeroLoaderFactory loaderFactory;
  final ProgressStore? store;

  @override
  State<ArmySelectionScreen> createState() => _ArmySelectionScreenState();
}

class _ArmySelectionScreenState extends State<ArmySelectionScreen> {
  static const playableIds = ['ranger_new', 'flame', 'shadow', 'storm'];
  static const int total = GameWorld.startingArmySize;

  late HeroDefinition _hero;
  late Map<MonsterType, int> _counts;
  int _heroLevel = 1;
  late String _weaponId;

  @override
  void initState() {
    super.initState();
    _hero = heroCatalog.firstWhere((h) => playableIds.contains(h.id));
    _counts = Map<MonsterType, int>.from(MonsterCatalog.defaultStartingArmy);
    _weaponId = kitForHero(_hero.id).weapons.first.id;
    _loadLevel();
  }

  /// Weapon locks follow the hero's saved level; a missing store means the
  /// starting level (only the first weapon is available).
  Future<void> _loadLevel() async {
    final progress = await widget.store?.load(_hero.id);
    if (!mounted) return;
    setState(() {
      _heroLevel = progress?.level ?? 1;
      final weapons = kitForHero(_hero.id).weapons;
      if (!weapons.any((w) => w.id == _weaponId && w.unlockedAt(_heroLevel))) {
        _weaponId = weapons.first.id;
      }
    });
  }

  void _selectHero(HeroDefinition hero) {
    setState(() {
      _hero = hero;
      _weaponId = kitForHero(hero.id).weapons.first.id;
      _heroLevel = 1;
    });
    _loadLevel();
  }

  int get _assigned => _counts.values.fold(0, (sum, n) => sum + n);

  void _set(MonsterType type, int value) {
    final others = _assigned - _counts[type]!;
    final next = value.clamp(0, total - others);
    setState(() => _counts[type] = next);
  }

  void _start() {
    // The constructor pads to 20 if a caller passes a short map, but the UI
    // always hands over an exact 20 so the player's distribution is exact.
    final army = Map<MonsterType, int>.from(_counts);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: GameScreen(
            hero: _hero,
            loaderFactory: widget.loaderFactory,
            store: widget.store,
            startingArmy: army,
            weaponId: _weaponId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختيار البطل والجيش'),
        backgroundColor: const Color(0x33000000),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('البطل',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView.separated(
                key: const ValueKey('hero_strip'),
                scrollDirection: Axis.horizontal,
                itemCount: heroCatalog.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final hero = heroCatalog[index];
                  final playable = playableIds.contains(hero.id);
                  return ChoiceChip(
                    key: ValueKey('select_hero_${hero.id}'),
                    avatar: Icon(hero.icon, color: hero.theme.accent, size: 18),
                    label: Text(hero.nameAr),
                    selected: hero.id == _hero.id,
                    onSelected: playable ? (_) => _selectHero(hero) : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text('السلاح (واحد من ثلاثة)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Text('مستوى البطل $_heroLevel',
                    key: const ValueKey('hero_level'),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            for (final weapon in kitForHero(_hero.id).weapons)
              Card(
                key: ValueKey('weapon_${weapon.id}'),
                color: weapon.id == _weaponId
                    ? const Color(0x339BE845)
                    : const Color(0x11FFFFFF),
                child: ListTile(
                  leading: const Icon(Icons.sports_esports),
                  title: Text(weapon.nameAr,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    weapon.unlockedAt(_heroLevel)
                        ? weapon.descAr
                        : 'يُفتح عند المستوى ${weapon.unlockLevel}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: weapon.unlockedAt(_heroLevel)
                      ? Icon(
                          weapon.id == _weaponId
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: const Color(0xFF9BE845),
                        )
                      : const Icon(Icons.lock, color: Colors.white54),
                  onTap: weapon.unlockedAt(_heroLevel)
                      ? () => setState(() => _weaponId = weapon.id)
                      : null,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text('الجيش الابتدائي (20 مجاناً)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Text(
                  'الموزَّع: $_assigned/$total',
                  key: const ValueKey('army_total'),
                  style: TextStyle(
                    color: _assigned == total ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final type in MonsterType.values)
              Card(
                color: const Color(0x22FFFFFF),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.shield,
                          color: Color(MonsterCatalog.def(type).color)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(MonsterCatalog.def(type).nameAr,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            Text(MonsterCatalog.def(type).roleAr,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        key: ValueKey('dec_${type.name}'),
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _counts[type]! > 0
                            ? () => _set(type, _counts[type]! - 1)
                            : null,
                      ),
                      Text('${_counts[type]}',
                          key: ValueKey('count_${type.name}'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        key: ValueKey('inc_${type.name}'),
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _assigned < total
                            ? () => _set(type, _counts[type]! + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('start_with_army'),
              onPressed: _assigned == total ? _start : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('ابدأ المباراة'),
            ),
          ],
        ),
      ),
    );
  }
}
