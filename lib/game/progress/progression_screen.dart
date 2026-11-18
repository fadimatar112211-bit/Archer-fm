import 'package:flutter/material.dart';

import '../../hero/hero_catalog.dart';
import '../combat/hero_kit.dart';
import '../combat/hero_weapons.dart';
import '../monsters/monster_models.dart';
import 'equipment.dart';
import 'hero_progress.dart';
import 'progression.dart';
import 'xp.dart';

/// Permanent progression hub: separate tabs for heroes, monsters, equipment,
/// weapons and chests, plus the account power and the four material wallets.
///
/// Everything here is confirmed by `PROJECT_STATUS.md` §Progression:
/// separate hero and monster upgrade pages, six equipment slots, five rarities,
/// equipment levels capped at 40, duplicate items turned into materials,
/// unwanted equipment sold, chests containing equipment/weapons only, and
/// every upgrade category requiring its own material in addition to currency.
class ProgressionScreen extends StatefulWidget {
  const ProgressionScreen({
    super.key,
    required this.hero,
    this.store,
    this.initialHeroId,
  });

  final HeroDefinition hero;
  final ProgressStore? store;

  /// Hero page to open first; defaults to [hero].
  final String? initialHeroId;

  @override
  State<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends State<ProgressionScreen> {
  late final ProgressStore store;
  late String heroId;

  ProgressionController? controller;
  HeroProgress _base = HeroProgress.initial;
  MonsterUpgrades _upgrades = MonsterUpgrades();
  bool _loading = true;

  static const List<String> _playableHeroIds = [
    'ranger_new',
    'flame',
    'shadow',
    'storm',
  ];

  @override
  void initState() {
    super.initState();
    store = widget.store ?? SharedPreferencesProgressStore();
    heroId = widget.initialHeroId ?? widget.hero.id;
    _load(heroId);
  }

  HeroDefinition get hero => heroById(heroId);

  Color get accent => hero.theme.accent;

  HeroKit get kit => kitForHero(heroId);

  int weaponUpgradeLevel(String weaponId) =>
      (_base.weaponLevels[weaponId] ?? 0).clamp(0, 10);

  int weaponUpgradeCurrencyCost(int level) => 120 + level * 80;

  int weaponUpgradeMaterialCost(int level) => 1 + level ~/ 3;

  Future<void> _upgradeWeapon(String weaponId) async {
    final current = controller;
    if (current == null) return;
    final level = weaponUpgradeLevel(weaponId);
    if (level >= 10) return;
    final currency = weaponUpgradeCurrencyCost(level);
    final material = weaponUpgradeMaterialCost(level);
    if (!current.spendCurrency(currency) ||
        !current.spendMaterial(ProgressionMaterial.equipment, material)) {
      _showInsufficient();
      return;
    }
    final next = <String, int>{..._base.weaponLevels, weaponId: level + 1};
    setState(() => _base = _base.copyWith(weaponLevels: next));
    await _save();
  }

  Future<void> _load(String id) async {
    final saved = await store.load(id);
    if (!mounted) return;
    setState(() {
      heroId = id;
      _base = saved ?? HeroProgress.initial;
      _upgrades = MonsterUpgrades({
        for (final type in MonsterType.values)
          if (_base.armyLevels[type.name] != null)
            type: _base.armyLevels[type.name]!,
      });
      controller = saved == null
          ? ProgressionController(heroId: id)
          : ProgressionController.fromProgress(id, saved);
      _loading = false;
    });
  }

  Future<void> _save() async {
    final current = controller;
    if (current == null) return;
    final updated = _base.copyWith(
      essence: current.currency,
      materials: {
        for (final entry in current.materials.entries)
          entry.key.name: entry.value,
      },
      equipment: List<EquipmentItem>.of(current.equipment),
      equipped: {
        for (final entry in current.equipped.entries)
          entry.key.name: entry.value,
      },
      capacityLevel: current.capacityLevel,
      heroUpgradeLevel: current.heroUpgradeLevel,
      armyLevels: _upgrades.toMap(),
    );
    _base = updated;
    await store.save(heroId, updated);
  }

  void _mutate(VoidCallback change) {
    setState(change);
    _save();
  }

  void _switchHero(String id) {
    if (id == heroId) return;
    setState(() => _loading = true);
    _load(id);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            title: Text('التطوير الدائم — ${hero.nameAr}'),
            backgroundColor: Colors.black.withValues(alpha: 0.4),
            bottom: TabBar(
              isScrollable: true,
              indicatorColor: accent,
              tabs: const [
                Tab(text: 'الأبطال'),
                Tab(text: 'الوحوش'),
                Tab(text: 'المعدات'),
                Tab(text: 'الأسلحة'),
                Tab(text: 'الصناديق'),
              ],
            ),
          ),
          body: _loading || controller == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _heroSelector(),
                    _walletBar(),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _heroTab(),
                          _monsterTab(),
                          _equipmentTab(weapons: false),
                          _heroWeaponsTab(),
                          _chestsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ---- Header ---------------------------------------------------------------

  Widget _heroSelector() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.black.withValues(alpha: 0.2),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final id in _playableHeroIds)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                key: ValueKey('progression_hero_$id'),
                selected: id == heroId,
                selectedColor: heroById(id).theme.accent.withValues(alpha: 0.3),
                label: Text(heroById(id).nameAr),
                onSelected: (_) => _switchHero(id),
              ),
            ),
        ],
      ),
    );
  }

  Widget _walletBar() {
    final current = controller!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black.withValues(alpha: 0.3),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'القوة ${current.accountPower}',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            'الجوهر ${current.currency}',
            style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
          ),
          for (final material in ProgressionMaterial.values)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Color(material.color).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${material.nameAr} ${current.materialOf(material)}',
                style: TextStyle(
                  color: Color(material.color),
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- Heroes ---------------------------------------------------------------

  Widget _heroTab() {
    final current = controller!;
    final xp = _base.heroXp;
    final last = _base.lastXpGain;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _infoCard([
          Text(
            '${hero.nameAr} — ${hero.roleAr}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Text('${hero.weaponAr} · ${hero.skillAr}'),
          Text(
            'المستوى ${xp.level}/$heroMaxLevel · الإصابات ${_base.kills}',
          ),
          Text(
            xp.isMax
                ? 'الخبرة الإجمالية ${xp.totalXp} · وصل إلى المستوى الأقصى'
                : 'الخبرة ${xp.xp}/${xp.required} · المتبقي ${xp.remaining} · '
                    'الإجمالي ${xp.totalXp}',
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              key: const ValueKey('progression_hero_xp_bar'),
              value: xp.progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: accent,
            ),
          ),
          if (last != null)
            Text(
              'آخر مكسب: ${last.heroXp} خبرة من ${last.matchId}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
        ]),
        _sectionTitle('القدرات الأربع'),
        _infoCard([
          for (final ability in kit.abilities)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    xp.level >= ability.unlockLevel
                        ? Icons.check_circle
                        : Icons.lock,
                    size: 15,
                    color: xp.level >= ability.unlockLevel
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${ability.nameAr} — ${ability.descAr}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Text(
                    xp.level >= ability.unlockLevel
                        ? 'مفتوحة'
                        : 'المستوى ${ability.unlockLevel}',
                    style: TextStyle(
                      fontSize: 11,
                      color: xp.level >= ability.unlockLevel
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ),
        ]),
        _sectionTitle('تحسين البطل'),
        _upgradeRow(
          key: const ValueKey('upgrade_hero'),
          title: 'تحسين البطل',
          detail: 'المستوى ${current.heroUpgradeLevel}/$maxHeroUpgradeLevel',
          effect: 'صحة +${(current.heroUpgradeLevel * 1.5).toStringAsFixed(1)}% · '
              'ضرر +${(current.heroUpgradeLevel * 1.0).toStringAsFixed(1)}%',
          currencyCost: current.heroUpgradeCurrencyCost,
          material: ProgressionMaterial.hero,
          materialCost: current.heroUpgradeMaterialCost,
          maxed: current.heroUpgradeLevel >= maxHeroUpgradeLevel,
          canAfford: current.canUpgradeHero,
          onPressed: () => _mutate(() {
            if (!current.upgradeHero()) _showInsufficient();
          }),
        ),
        _sectionTitle('سعة الموارد'),
        _upgradeRow(
          key: const ValueKey('upgrade_capacity'),
          title: 'سعة الحمل',
          detail:
              '${current.carryCapacity} موارد · المستوى ${current.capacityLevel}/$maxCapacityLevel',
          effect: 'كل مستوى يضيف $capacityUpgradeStep سعة للحمل',
          currencyCost: current.capacityCurrencyCost,
          material: ProgressionMaterial.capacity,
          materialCost: current.capacityMaterialCost,
          maxed: current.capacityLevel >= maxCapacityLevel,
          canAfford: current.canUpgradeCapacity,
          onPressed: () => _mutate(() {
            if (!current.upgradeCapacity()) _showInsufficient();
          }),
        ),
        _sectionTitle('المواد'),
        _infoCard([
          for (final material in ProgressionMaterial.values)
            Text(
              '${material.nameAr}: ${current.materialOf(material)}',
              style: TextStyle(color: Color(material.color)),
            ),
        ]),
      ],
    );
  }

  // ---- Monsters -------------------------------------------------------------

  Widget _monsterTab() {
    final current = controller!;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _infoCard([
          const Text(
            'لكل نوع صفحة ترقية مستقلة. تحتفظ الوحوش المشتراة بخصائصها، '
            'والترقية تنطبق على كل شراء جديد.',
          ),
          Text(
            'أنسجة الوحوش المتاحة: '
            '${current.materialOf(ProgressionMaterial.monster)}',
            style: const TextStyle(color: Color(0xFFFF7A5A)),
          ),
        ]),
        for (final type in MonsterType.values) _monsterRow(type),
      ],
    );
  }

  Widget _monsterRow(MonsterType type) {
    final current = controller!;
    final def = MonsterCatalog.def(type);
    final level = _upgrades.levelOf(type);
    final maxed = level >= MonsterUpgrades.maxLevel;
    final cost = _upgrades.upgradeCost(type);
    final materialCost = 1 + (level - 1) ~/ 5;
    final materials = current.materialOf(ProgressionMaterial.monster);
    final affordable = !maxed && current.currency >= cost && materials >= materialCost;
    final stats = MonsterStats.of(type, level);
    final xp = _base.monsterXpState(type);
    return _card(
      key: ValueKey('monster_row_${type.name}'),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Color(def.color),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${def.nameAr} — المستوى $level',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${def.roleAr} · HP ${stats.maxHp.round()} · '
                  'ضرر ${stats.damage.round()}',
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  xp.isMax
                      ? 'خبرة القتال ${xp.xp} · المستوى ${xp.level}/$monsterXpMaxLevel'
                      : 'خبرة القتال ${xp.currentXp}/${xp.required} · '
                          'المستوى ${xp.level}/$monsterXpMaxLevel · '
                          'المتبقي ${xp.remaining}',
                  key: ValueKey('monster_xp_${type.name}'),
                  style: const TextStyle(fontSize: 11, color: Color(0xFFFFB27A)),
                ),
                LinearProgressIndicator(
                  value: xp.progress,
                  minHeight: 5,
                  backgroundColor: Colors.white24,
                  color: Color(def.color),
                ),
                Text(
                  maxed
                      ? 'الأنسجة: $materials'
                      : 'التكلفة: $cost جوهر + $materialCost أنسجة '
                          '(لديك $materials)',
                  style: TextStyle(
                    fontSize: 11,
                    color: affordable ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            key: ValueKey('progression_upgrade_${type.name}'),
            onPressed: maxed
                ? null
                : () => _mutate(() {
                      if (current.spendCurrency(cost) &&
                          current.spendMaterial(
                            ProgressionMaterial.monster,
                            materialCost,
                          )) {
                        _upgrades.upgrade(type, essence: cost);
                      } else {
                        _showInsufficient();
                      }
                    }),
            child: Text(maxed ? 'الأقصى' : 'ترقية'),
          ),
        ],
      ),
    );
  }

  // ---- Equipment / weapons --------------------------------------------------

  /// The three hero-specific weapons are separate from random weapon drops in
  /// the equipment inventory: their unlocks are tied to hero level and their
  /// mastery levels are persisted in the cloud-ready save payload.
  Widget _heroWeaponsTab() {
    final current = controller!;
    final xp = _base.heroXp;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _infoCard([
          Text('أسلحة ${hero.nameAr} — ثلاثة أسلحة ثابتة'),
          Text(
            'المستوى الحالي ${xp.level} · خامات المعدات '
            '${current.materialOf(ProgressionMaterial.equipment)}',
          ),
          const Text(
            'إتقان السلاح: +2% ضرر لكل مستوى (0–10). '
            'المضاعفات الأساسية للسلاح لا تتغير.',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ]),
        for (final weapon in kit.weapons)
          _heroWeaponRow(weapon, xp.level),
        _sectionTitle('أسلحة المعدات من الصناديق'),
        ..._equipmentChildren(weapons: true),
      ],
    );
  }

  Widget _heroWeaponRow(HeroWeapon weapon, int heroLevel) {
    final unlocked = weapon.unlockedAt(heroLevel);
    final mastery = weaponUpgradeLevel(weapon.id);
    final currency = weaponUpgradeCurrencyCost(mastery);
    final material = weaponUpgradeMaterialCost(mastery);
    final maxed = mastery >= 10;
    final affordable = controller!.currency >= currency &&
        controller!.materialOf(ProgressionMaterial.equipment) >= material;
    return _card(
      key: ValueKey('hero_weapon_${weapon.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                unlocked ? Icons.check_circle : Icons.lock,
                size: 16,
                color: unlocked ? Colors.greenAccent : Colors.orangeAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  weapon.nameAr,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                unlocked
                    ? 'مفتوح · إتقان $mastery/10'
                    : 'يُفتح في المستوى ${weapon.unlockLevel}',
                style: TextStyle(
                  fontSize: 11,
                  color: unlocked ? Colors.greenAccent : Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            weapon.descAr,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
          Text(
            'ضرر ×${weapon.damageMultiplier.toStringAsFixed(2)} · '
            'معدل ×${weapon.rateMultiplier.toStringAsFixed(2)} · '
            'مدى ×${weapon.rangeMultiplier.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 6),
          OutlinedButton(
            key: ValueKey('upgrade_weapon_${weapon.id}'),
            onPressed: !unlocked || maxed
                ? null
                : () => _upgradeWeapon(weapon.id),
            child: Text(
              maxed
                  ? 'الإتقان الأقصى'
                  : unlocked
                      ? 'ترقية الإتقان ($currency + $material)'
                      : 'مغلق — المستوى ${weapon.unlockLevel}',
              style: TextStyle(
                color: unlocked && affordable ? null : Colors.orangeAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ListView _equipmentTab({required bool weapons}) => ListView(
        padding: const EdgeInsets.all(12),
        children: _equipmentChildren(weapons: weapons),
      );

  List<Widget> _equipmentChildren({required bool weapons}) {
    final current = controller!;
    final items = current.equipment
        .where((item) =>
            weapons ? item.slot == EquipmentSlot.weapon : item.slot != EquipmentSlot.weapon)
        .toList()
      ..sort((a, b) {
        final bySlot = a.slot.index.compareTo(b.slot.index);
        return bySlot != 0 ? bySlot : b.rarity.index.compareTo(a.rarity.index);
      });
    return [
      _infoCard([
        Text(
          weapons
              ? 'الأسلحة: السلاح المجهّز يضيف ضرراً. السقف مستوى '
                  '$equipmentMaxLevel.'
              : 'المعدات: الخوذة والدرع والقلادة تضيف صحة، الحذاء سرعة، '
                  'والخاتم ضرراً. السقف مستوى $equipmentMaxLevel.',
        ),
        Text('المملوك: ${items.length} · خامات المعدات: '
            '${current.materialOf(ProgressionMaterial.equipment)}'),
      ]),
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('لا يوجد شيء بعد — افتح الصناديق داخل المباراة.'),
          ),
        ),
      for (final item in items) _equipmentRow(item),
    ];
  }

  Widget _equipmentRow(EquipmentItem item) {
    final current = controller!;
    final equipped = current.equippedIn(item.slot)?.id == item.id;
    final maxed = item.isMaxLevel;
    final currencyCost = item.upgradeCurrencyCost;
    final materialCost = item.upgradeMaterialCost;
    final affordable = current.canUpgradeItem(item);
    return _card(
      key: ValueKey('equipment_row_${item.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Color(item.rarity.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${item.rarity.nameAr} ${item.slot.nameAr} — '
                  'المستوى ${item.cappedLevel}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (equipped)
                const Chip(
                  label: Text('مجهّز', style: TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _bonusText(item),
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (equipped)
                OutlinedButton(
                  key: ValueKey('unequip_${item.id}'),
                  onPressed: () => _mutate(() => current.unequip(item.slot)),
                  child: const Text('إزالة'),
                )
              else
                FilledButton(
                  key: ValueKey('equip_${item.id}'),
                  onPressed: () => _mutate(() => current.equip(item.id)),
                  child: const Text('تجهيز'),
                ),
              OutlinedButton(
                key: ValueKey('upgrade_item_${item.id}'),
                onPressed: maxed
                    ? null
                    : () => _mutate(() {
                          if (!current.upgradeItem(item.id)) {
                            _showInsufficient();
                          }
                        }),
                child: Text(
                  maxed
                      ? 'المستوى الأقصى'
                      : 'ترقية ($currencyCost + $materialCost)',
                  style: TextStyle(
                    color: affordable ? null : Colors.orangeAccent,
                  ),
                ),
              ),
              TextButton(
                key: ValueKey('sell_${item.id}'),
                onPressed: equipped
                    ? null
                    : () => _mutate(() {
                          if (current.sell(item.id)) {
                            _toast('بِيع مقابل ${item.sellValue} جوهر');
                          }
                        }),
                child: Text('بيع (${item.sellValue})'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _bonusText(EquipmentItem item) {
    final parts = <String>[];
    if (item.hpBonusFraction > 0) {
      parts.add('صحة +${(item.hpBonusFraction * 100).toStringAsFixed(1)}%');
    }
    if (item.damageBonusFraction > 0) {
      parts.add('ضرر +${(item.damageBonusFraction * 100).toStringAsFixed(1)}%');
    }
    if (item.moveBonusFraction > 0) {
      parts.add('سرعة +${(item.moveBonusFraction * 100).toStringAsFixed(1)}%');
    }
    return parts.isEmpty ? 'لا خصائص' : parts.join(' · ');
  }

  // ---- Chests ---------------------------------------------------------------

  Widget _chestsTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _infoCard([
          const Text(
            'الصناديق تظهر على الخريطة وتُفتح بلمسها داخل المباراة.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'تحتوي معدات وأسلحة فقط. العنصر المكرر (نفس الفتحة والندرة) '
            'يتحول تلقائياً إلى خامات معدات، وغير المرغوب يمكن بيعه.',
          ),
          Text(
            'عناصرك: ${controller!.equipment.length} · '
            'خامات المعدات: '
            '${controller!.materialOf(ProgressionMaterial.equipment)}',
          ),
        ]),
        _sectionTitle('احتمالات الندرة داخل الصندوق'),
        for (final rarity in EquipmentRarity.values)
          _card(
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(rarity.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(rarity.nameAr)),
                Text(
                  '${rarity.chestWeight}%',
                  style: TextStyle(color: Color(rarity.color)),
                ),
                const SizedBox(width: 12),
                Text(
                  'خامات مكررة ${rarity.duplicateMaterialValue} · '
                  'بيع ${rarity.baseSellValue}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        _sectionTitle('الفتحات'),
        _infoCard([
          for (final slot in EquipmentSlot.values) Text(slot.nameAr),
        ]),
      ],
    );
  }

  // ---- Shared widgets -------------------------------------------------------

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(
          title,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );

  Widget _infoCard(List<Widget> children) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final child in children)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: child,
              ),
          ],
        ),
      );

  Widget _card({Key? key, required Widget child}) => Container(
        key: key,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: child,
      );

  Widget _upgradeRow({
    Key? key,
    required String title,
    required String detail,
    required String effect,
    required int currencyCost,
    required ProgressionMaterial material,
    required int materialCost,
    required bool maxed,
    required bool canAfford,
    required VoidCallback onPressed,
  }) {
    final current = controller!;
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(detail),
                Text(effect, style: const TextStyle(fontSize: 11)),
                Text(
                  maxed
                      ? 'وصلت للحد الأقصى'
                      : 'التكلفة: $currencyCost جوهر + $materialCost '
                          '${material.nameAr} (لديك '
                          '${current.materialOf(material)})',
                  style: TextStyle(
                    fontSize: 11,
                    color: maxed || canAfford
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            key: key,
            onPressed: maxed ? null : onPressed,
            child: Text(maxed ? 'الأقصى' : 'ترقية'),
          ),
        ],
      ),
    );
  }

  void _showInsufficient() => _toast('الجوهر أو المواد غير كافية');

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}
