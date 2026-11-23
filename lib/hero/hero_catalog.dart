import 'package:flutter/material.dart';

/// Visual identity of one playable hero.
///
/// The catalogue is the single place that knows a hero's folder layout, Arabic
/// label, weapon/skill copy and UI accent. The viewer, stage painter and effect
/// layer read from it, so adding a fifth hero is a data change plus a rendered
/// asset folder instead of a new screen.
@immutable
class HeroTheme {
  const HeroTheme({
    required this.accent,
    required this.accentSoft,
    required this.effect,
    required this.stageTop,
    required this.stageMid,
    required this.stageBottom,
  });

  /// Selection/UI accent (chips, headers, focus rings).
  final Color accent;

  /// Translucent accent used for the stage glow.
  final Color accentSoft;

  /// Colour of event flashes, projectile rings and weapon trails.
  final Color effect;

  final Color stageTop;
  final Color stageMid;
  final Color stageBottom;
}

@immutable
class HeroDefinition {
  const HeroDefinition({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.roleAr,
    required this.weaponAr,
    required this.skillAr,
    required this.descriptionAr,
    required this.icon,
    required this.theme,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String roleAr;
  final String weaponAr;
  final String skillAr;
  final String descriptionAr;
  final IconData icon;
  final HeroTheme theme;

  /// Bundled folder for the runtime manifest and packed atlases.
  String get assetRoot => 'assets/heroes/$id/renders';

  String get manifestPath => '$assetRoot/${id}_manifest.json';
}

const HeroTheme rangerNewTheme = HeroTheme(
  accent: Color(0xFF62E86C),
  accentSoft: Color(0x2662E86C),
  effect: Color(0xFF62E86C),
  stageTop: Color(0xFF0B1A10),
  stageMid: Color(0xFF14301C),
  stageBottom: Color(0xFF07110A),
);

const HeroTheme flameTheme = HeroTheme(
  accent: Color(0xFFFF9A3C),
  accentSoft: Color(0x26FF8A24),
  effect: Color(0xFFFF8A24),
  stageTop: Color(0xFF1C0D0A),
  stageMid: Color(0xFF3A1A12),
  stageBottom: Color(0xFF120706),
);

const HeroTheme shadowTheme = HeroTheme(
  accent: Color(0xFFB98CF0),
  accentSoft: Color(0x26A87BE8),
  effect: Color(0xFFA87BE8),
  stageTop: Color(0xFF130C1D),
  stageMid: Color(0xFF241636),
  stageBottom: Color(0xFF0A0611),
);

const HeroTheme stormTheme = HeroTheme(
  accent: Color(0xFF6FE8FF),
  accentSoft: Color(0x266FE8FF),
  effect: Color(0xFF48C8FF),
  stageTop: Color(0xFF071A22),
  stageMid: Color(0xFF103642),
  stageBottom: Color(0xFF041017),
);

/// The playable roster.
///
/// Exactly four selectable heroes. The reference-quality Ranger is the
/// canonical and only playable Ranger entry; legacy Ranger assets were retired
/// for compatibility tests and provenance, but are not a fifth selectable hero.
/// Names, weapons and skills mirror the production brief.
const List<HeroDefinition> heroCatalog = [
  HeroDefinition(
    id: 'flame',
    nameAr: 'فارس اللهب',
    nameEn: 'Flame',
    roleAr: 'قريب المدى · إلحاق ضرر',
    weaponAr: 'سيف اللهب العظيم',
    skillAr: 'انفجار الجحيم',
    descriptionAr:
        'فارس مدرّع يقاتل من مسافة قريبة. يرفع سيفه المشتعل ثم يهبط بضربة '
        'أرضية تصنع موجة نار حوله.',
    icon: Icons.local_fire_department,
    theme: flameTheme,
  ),
  HeroDefinition(
    id: 'shadow',
    nameAr: 'ظل الليل',
    nameEn: 'Shadow',
    roleAr: 'قريب المدى · اغتيال',
    weaponAr: 'خنجران توأمان',
    skillAr: 'اندفاع الظل',
    descriptionAr:
        'صيّاد مقنّع يختفي خلف عباءته الممزقة. يضرب بخنجرين بالتتابع، ثم '
        'يندفع عبر الأعداء في دائرة ظلام.',
    icon: Icons.dark_mode,
    theme: shadowTheme,
  ),
  HeroDefinition(
    id: 'storm',
    nameAr: 'حامل العاصفة',
    nameEn: 'Storm',
    roleAr: 'متوسط المدى · تحكم',
    weaponAr: 'رمح الصاعقة',
    skillAr: 'ضربة الرعد',
    descriptionAr:
        'محارب يحمل رمحاً كهربائياً. يضرب من مسافة أطول من السيف، وتستدعي '
        'مهارته صاعقة تنزل على الأرض أمامه.',
    icon: Icons.bolt,
    theme: stormTheme,
  ),
  HeroDefinition(
    id: 'ranger_new',
    nameAr: 'الرامي',
    nameEn: 'Ranger',
    roleAr: 'بعيد المدى · توازن',
    weaponAr: 'قوس الطاقة الخضراء',
    skillAr: 'وابل السهام',
    descriptionAr:
        'النسخة النهائية من الرامي، مبنية على المجسّم الأصلي بكل تفاصيله '
        'وخاماته مع نظام العظام والحركات الثمانية المرخصة: تنقّل، هجوم '
        'بالسهم، ومهارة الوابل.',
    icon: Icons.north_east,
    theme: rangerNewTheme,
  ),
];

HeroDefinition heroById(String id) {
  return heroCatalog.firstWhere(
    (hero) => hero.id == id,
    orElse: () => throw ArgumentError.value(id, 'id', 'Unknown hero id'),
  );
}
