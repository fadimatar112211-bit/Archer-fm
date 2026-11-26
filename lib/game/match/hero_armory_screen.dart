import 'package:flutter/material.dart';

import '../heroes/hero_roster.dart';

/// Read-only catalogue backed by the canonical combat definitions.
/// Ownership, unlock prices and upgrades are intentionally not simulated here:
/// those transactions belong to the authenticated authoritative server.
class HeroArmoryScreen extends StatefulWidget {
  const HeroArmoryScreen({super.key});

  @override
  State<HeroArmoryScreen> createState() => _HeroArmoryScreenState();
}

class _HeroArmoryScreenState extends State<HeroArmoryScreen> {
  HeroCombatDefinition _hero = archerFmHeroes.first;

  String _rangeLabel(HeroWeaponRange range) => switch (range) {
        HeroWeaponRange.melee => 'قتال قريب',
        HeroWeaponRange.reach => 'مدى متوسط',
        HeroWeaponRange.ranged => 'قتال بعيد',
      };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ترسانة الأبطال'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'اختر بطلك لاستعراض أسلحته وقدراته',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final hero in archerFmHeroes)
                        ChoiceChip(
                          label: Text(hero.nameAr),
                          selected: _hero.id == hero.id,
                          onSelected: (_) => setState(() => _hero = hero),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _hero.nameAr,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(_hero.roleAr),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 14,
                            runSpacing: 6,
                            children: [
                              Text('الصحة الأساسية: ${_hero.baseHealth}'),
                              Text('سرعة الحركة: ${_hero.moveSpeed.toStringAsFixed(2)}'),
                              Text('مدى الهجوم: ${_hero.attackRange.toStringAsFixed(1)}'),
                              const Text('الحد الأعلى للمستوى: 40'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('أسلحة البطل', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  for (var i = 0; i < _hero.weapons.length; i++)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${i + 1}')),
                        title: Text(_hero.weapons[i].nameAr),
                        subtitle: Text(
                          '${_rangeLabel(_hero.weapons[i].range)} · '
                          'تبريد ${(_hero.weapons[i].cooldownMs / 1000).toStringAsFixed(2)} ث\n'
                          '${_hero.weapons[i].descriptionAr}',
                        ),
                        isThreeLine: true,
                        trailing: i == 0
                            ? const Chip(label: Text('السلاح الأساسي'))
                            : const Chip(label: Text('يتطلب فتحاً')),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text('الضربات الخاصة', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  for (final ultimate in _hero.ultimates)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.auto_awesome),
                        title: Text(ultimate.nameAr),
                        subtitle: Text(ultimate.descriptionAr),
                        trailing: Text('المستوى ${ultimate.unlockLevel}'),
                      ),
                    ),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('نظام الكومبو'),
                      subtitle: Text(
                        'خمس ضربات متتابعة مستقلة عن الضربات الخاصة. '
                        'فتح القدرات الخاصة يكون عند المستويات 1 و10 و20 و30.',
                      ),
                    ),
                  ),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.lock_outline),
                      title: Text('الفتح والتطوير'),
                      subtitle: Text(
                        'هذا الكتالوج للعرض فقط. شراء الأسلحة وترقيتها '
                        'يحتاجان تحققاً وحفظاً من الخادم، لذلك لا توجد أزرار شراء وهمية هنا.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
