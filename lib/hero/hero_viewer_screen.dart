import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'hero_assets.dart';
import 'hero_catalog.dart';
import 'hero_manifest.dart';
import 'hero_stage.dart';
import 'sprite_player.dart';
import '../game/heroes/hero_roster.dart';
import '../game/heroes/hero_combat_runtime.dart';
import '../game/match/match_loadout_screen.dart';

const List<String> heroStates = [
  'idle',
  'walk',
  'run',
  'attack',
  'skill',
  'dodge',
  'hit',
  'death',
];

const Map<String, String> stateLabels = {
  'idle': 'وقوف',
  'walk': 'مشي',
  'run': 'جري',
  'attack': 'هجوم',
  'skill': 'مهارة',
  'dodge': 'تفادي',
  'hit': 'إصابة',
  'death': 'موت',
};

const List<String> heroDirections = ['n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw'];

const Map<String, String> directionLabels = {
  'n': 'شمال',
  'ne': 'شمال شرق',
  'e': 'شرق',
  'se': 'جنوب شرق',
  's': 'جنوب',
  'sw': 'جنوب غرب',
  'w': 'غرب',
  'nw': 'شمال غرب',
};

const Map<String, IconData> directionIcons = {
  'n': Icons.north,
  'ne': Icons.north_east,
  'e': Icons.east,
  'se': Icons.south_east,
  's': Icons.south,
  'sw': Icons.south_west,
  'w': Icons.west,
  'nw': Icons.north_west,
};

const Map<String, String> eventLabels = {
  // Ranger, ranged.
  'projectile_release': 'إطلاق سهم',
  'bow_draw': 'شد القوس',
  'volley_charge': 'تجميع طاقة',
  'volley_release': 'وابل سهام',
  // Shared melee choreography.
  'weapon_windup': 'رفع السلاح',
  'melee_impact': 'ضربة قريبة',
  'hit_react': 'ارتداد الإصابة',
  'dodge_start': 'بداية التفادي',
  'dodge_end': 'نهاية التفادي',
  // Flame.
  'inferno_charge': 'تجميع اللهب',
  'inferno_burst': 'انفجار الجحيم',
  // Shadow.
  'shadow_charge': 'تجميع الظل',
  'shadow_burst': 'اندفاع الظل',
  // Storm.
  'storm_charge': 'تجميع الصاعقة',
  'thunder_strike': 'ضربة الرعد',
  'death_complete': 'السقوط',
};

String _effectForEvent(String name) {
  switch (name) {
    case 'projectile_release':
      return 'release';
    case 'volley_release':
      return 'volley';
    case 'bow_draw':
    case 'volley_charge':
    case 'weapon_windup':
    case 'inferno_charge':
    case 'shadow_charge':
    case 'storm_charge':
      return 'charge';
    case 'melee_impact':
      return 'impact';
    case 'inferno_burst':
    case 'shadow_burst':
      return 'burst';
    case 'thunder_strike':
      return 'thunder';
    case 'hit_react':
      return 'hit';
    case 'dodge_start':
    case 'dodge_end':
      return 'streak';
    default:
      return 'release';
  }
}

String _ultimateEffectKind(String id) {
  const effects = <String, String>{
    'ranger_starfall': 'starfall',
    'ranger_piercing': 'piercing',
    'ranger_nature': 'nature',
    'ranger_apex': 'apex',
    'flame_eruption': 'eruption',
    'flame_comet': 'comet',
    'flame_brand': 'brand',
    'flame_phoenix': 'phoenix',
    'shadow_vanish': 'vanish',
    'shadow_cross': 'cross',
    'shadow_poison': 'poison',
    'shadow_execution': 'execution',
    'storm_bolt': 'thunder',
    'storm_chain': 'chain',
    'storm_field': 'field',
    'storm_tempest': 'tempest',
  };
  return effects[id] ?? 'burst';
}

class HeroViewerScreen extends StatefulWidget {
  const HeroViewerScreen({
    super.key,
    required this.loaderFactory,
    this.initialHero,
  });

  /// Builds a loader per hero. Tests inject a factory returning fake loaders.
  final HeroLoaderFactory loaderFactory;

  final HeroDefinition? initialHero;

  @override
  State<HeroViewerScreen> createState() => _HeroViewerScreenState();
}

class _HeroViewerScreenState extends State<HeroViewerScreen>
    with SingleTickerProviderStateMixin {
  late HeroDefinition _hero;
  late HeroAssetLoader _loader;
  late HeroCombatRuntime _combat;
  late final Ticker _ticker;

  final ValueNotifier<int> _clock = ValueNotifier<int>(0);
  final ValueNotifier<List<String>> _log = ValueNotifier<List<String>>([]);
  final List<StageEffect> _effects = [];
  final Set<String> _unavailable = <String>{};

  HeroManifest? _manifest;
  AtlasSheet? _sheet;
  SpritePlayer? _player;
  String _state = 'idle';
  String _direction = 's';
  String? _error;
  String? _errorDetail;
  String? _sheetError;
  bool _loadingSheet = false;
  double _speed = 1.0;
  Duration _lastTick = Duration.zero;
  int _loadToken = 0;

  HeroTheme get _theme => _hero.theme;

  /// Local visual-preview tuning only. Live matches always receive their
  /// approved energy and combo values from the authoritative server config.
  HeroCombatRuntime _createPreviewCombat(HeroDefinition hero) {
    final definition = heroCombatById(_heroId(hero.id));
    return HeroCombatRuntime(
      hero: definition,
      comboResetWindowMs: 1200,
      maxEnergy: 100,
      energyRegenerationPerSecond: 1,
      ultimateEnergyCosts: {
        for (final rosterHero in archerFmHeroes)
          for (final ultimate in rosterHero.ultimates) ultimate.id: 20,
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _hero = widget.initialHero ?? heroCatalog.first;
    _loader = widget.loaderFactory(_hero);
    _combat = _createPreviewCombat(_hero);
    _ticker = createTicker(_onTick)..start();
    _loadManifest();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _player?.dispose();
    _clock.dispose();
    _log.dispose();
    _loader.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    final player = _player;
    if (delta.inMilliseconds > 0) {
      _combat.advance(delta);
      if (player != null) {
        player.advance((delta.inMilliseconds * _speed).round());
      }
    }
    _clock.value = elapsed.inMilliseconds;
    _effects.removeWhere((effect) => !effect.isAlive(_clock.value));
  }

  Future<void> _loadManifest() async {
    final loader = _loader;
    final hero = _hero;
    final token = ++_loadToken;
    try {
      final manifest = await loader.loadManifest();
      if (!mounted || token != _loadToken) return;
      setState(() {
        _manifest = manifest;
        _error = null;
        _errorDetail = null;
        _unavailable.remove(hero.id);
      });
      await _select('idle', 's');
    } catch (error) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _unavailable.add(hero.id);
        _error = 'لم تُضمَّن أصول «${hero.nameAr}» في هذه النسخة بعد. '
            'بقية الأبطال يعملون بشكل كامل.';
        _errorDetail = '$error';
      });
    }
  }

  Future<void> _switchHero(HeroDefinition hero) async {
    if (hero.id == _hero.id) return;
    final previous = _loader;
    _loadToken++;
    setState(() {
      _hero = hero;
      _combat = _createPreviewCombat(hero);
      _loader = widget.loaderFactory(hero);
      _manifest = null;
      _sheet = null;
      _player?.dispose();
      _player = null;
      _state = 'idle';
      _direction = 's';
      _error = null;
      _errorDetail = null;
      _sheetError = null;
      _loadingSheet = false;
      _effects.clear();
      _log.value = const <String>[];
    });
    previous.dispose();
    await _loadManifest();
  }

  Future<void> _select(String state, String direction, {bool replay = false}) async {
    final manifest = _manifest;
    if (manifest == null) return;
    if (!replay && state == _state && direction == _direction && _player != null) return;
    final name = '${state}_$direction';
    final clip = manifest.clipFor(state, direction);
    if (clip == null) {
      setState(() {
        _error = 'لا توجد حركة مسماة $name في بيانات البطل';
      });
      return;
    }
    final token = ++_loadToken;
    final loader = _loader;
    setState(() {
      _state = state;
      _direction = direction;
      _loadingSheet = true;
      _sheetError = null;
      _error = null;
      _errorDetail = null;
    });
    AtlasSheet? sheet;
    String? sheetError;
    try {
      sheet = await loader.loadSheet(manifest, name);
    } catch (error) {
      sheetError = 'تعذّر تحميل صورة الحركة: $error';
    }
    if (!mounted || token != _loadToken) return;
    final player = SpritePlayer(clip: clip, onEvent: _handleEvent);
    setState(() {
      _player?.dispose();
      _player = player;
      _sheet = sheet;
      _sheetError = sheetError;
      _loadingSheet = false;
    });
  }

  void _handleEvent(AnimationEvent event) {
    final now = _clock.value;
    _effects.add(StageEffect(kind: _effectForEvent(event.name), startMs: now));
    final state = stateLabels[_state] ?? _state;
    final direction = directionLabels[_direction] ?? _direction;
    final label = eventLabels[event.name] ?? event.name;
    _log.value = <String>[
      '$state · $direction — $label',
      ..._log.value,
    ].take(6).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final manifest = _manifest;
    final theme = _theme;
    return Scaffold(
      backgroundColor: theme.stageBottom,
      appBar: AppBar(
        backgroundColor: theme.stageTop,
        foregroundColor: const Color(0xFFE4F2E7),
        title: Text('Archer FM · ${_hero.nameEn}'),
        actions: [
          IconButton(
            tooltip: 'تجهيز المباراة',
            icon: const Icon(Icons.sports_esports),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MatchLoadoutScreen(),
              ),
            ),
          ),
          if (manifest != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Center(
                child: Text(
                  '${manifest.clips.length} حركة',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeroPicker(),
                const SizedBox(height: 12),
                _buildStage(manifest),
                const SizedBox(height: 14),
                if (_error != null) _errorCard(_error!, _errorDetail),
                if (manifest == null && _error == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                _buildHeroCard(),
                const SizedBox(height: 12),
                _buildCombatPanel(),
                const SizedBox(height: 12),
                _buildStatePicker(),
                const SizedBox(height: 12),
                _buildControls(),
                const SizedBox(height: 12),
                _buildDirectionPicker(),
                const SizedBox(height: 12),
                _buildDetails(),
                const SizedBox(height: 12),
                _buildLog(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPicker() {
    final theme = _theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('البطل'),
        const SizedBox(height: 8),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: heroCatalog.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final hero = heroCatalog[index];
              return _HeroPickerCard(
                hero: hero,
                selected: hero.id == _hero.id,
                unavailable: _unavailable.contains(hero.id),
                onTap: () => _switchHero(hero),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'اختر بطلاً ثم استعرض حركاته الثماني في ثمانية اتجاهات. '
          'كل بطل يملك سلاحه ومهارته وتأثيراته الخاصة.',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: theme.accent.withAlpha(150),
          ),
        ),
      ],
    );
  }

  Widget _buildStage(HeroManifest? manifest) {
    final theme = _theme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 430),
      child: AspectRatio(
        aspectRatio: 1,
        child: AnimatedBuilder(
          animation: Listenable.merge([_clock, _player]),
          builder: (context, _) {
            final player = _player;
            return HeroStage(
              sheet: _sheet,
              frameId: player?.frameId,
              pivotX: manifest?.pivotX ?? 0.5,
              pivotY: manifest?.pivotY ?? 0.86,
              effects: _effects,
              timeMs: _clock.value,
              theme: theme,
              placeholder: _sheetError ??
                  (_loadingSheet
                      ? 'جارٍ تحميل الرسوم…'
                      : _error != null
                          ? 'أصول هذا البطل قيد الإنتاج'
                          : 'اختر حركة واتجاهاً لعرض البطل'),
            );
          },
        ),
      ),
    );
  }

  Widget _errorCard(String message, String? detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1515),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8C3B3B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF9D9D), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFFFC9C9),
                    fontSize: 13,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: Color(0xFFD99A9A),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final theme = _theme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.stageTop,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.accent.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.accentSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.accent.withAlpha(110)),
            ),
            child: Icon(_hero.icon, color: theme.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_hero.nameAr} · ${_hero.roleAr}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE4F2E7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_hero.weaponAr} · ${_hero.skillAr}',
                  style: TextStyle(fontSize: 12, color: theme.accent),
                ),
                const SizedBox(height: 6),
                Text(
                  _hero.descriptionAr,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.55,
                    color: Color(0xFFAFC8B6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  HeroId _heroId(String id) => HeroId.values.firstWhere(
        (value) => value.name == id,
      );

  Widget _buildCombatPanel() {
    final theme = _theme;
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final combat = _combat;
        final hpPercent = combat.targetHealth / combat.targetMaxHealth;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.stageTop,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.accent.withAlpha(90)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('ساحة اختبار القتال'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  Text('المستوى ${combat.level}/$heroLevelCap'),
                  Text('الصحة ${combat.health}'),
                  Text('السرعة ${combat.moveSpeed.toStringAsFixed(2)}'),
                  Text('الهدف ${combat.targetHealth}/${combat.targetMaxHealth}'),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: hpPercent,
                  minHeight: 8,
                  backgroundColor: const Color(0xFF442020),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
                ),
              ),
              const SizedBox(height: 10),
              const Text('السلاح', style: TextStyle(color: Color(0xFFBFD7C5))),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < combat.hero.weapons.length; i++)
                    ChoiceChip(
                      label: Text(combat.hero.weapons[i].nameAr),
                      selected: combat.selectedWeaponIndex == i,
                      onSelected: (_) => setState(() => combat.selectWeapon(i)),
                      showCheckmark: false,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: combat.attackCooldownRemainingMs > 0
                        ? null
                        : () {
                            final result = combat.attack();
                            _select('attack', _direction, replay: true);
                            setState(() {
                              _log.value = <String>[
                                '${result.messageAr} · ${result.damage} ضرر',
                                ..._log.value,
                              ].take(6).toList(growable: false);
                            });
                          },
                    icon: const Icon(Icons.gps_fixed),
                    label: Text(combat.attackCooldownRemainingMs > 0
                        ? 'انتظر ${(combat.attackCooldownRemainingMs / 1000).toStringAsFixed(1)}ث'
                        : 'هجوم · ضربة ${combat.comboIndex + 1}/5'),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      combat.resetTarget();
                      _log.value = ['تمت إعادة الهدف', ..._log.value]
                          .take(6).toList(growable: false);
                    }),
                    child: const Text('إعادة الهدف'),
                  ),
                  OutlinedButton(
                    onPressed: combat.level >= heroLevelCap
                        ? null
                        : () => setState(() {
                              final gained = combat.gainExperience(100);
                              _log.value = [
                                gained > 0
                                    ? 'ارتفع المستوى إلى ${combat.level}'
                                    : 'أضيفت خبرة للتقدم',
                                ..._log.value,
                              ].take(6).toList(growable: false);
                            }),
                    child: const Text('+100 خبرة تجريبية'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('الضربات الخاصة · مستقلة عن الكومبو',
                  style: TextStyle(color: Color(0xFFBFD7C5))),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < combat.hero.ultimates.length; i++)
                    OutlinedButton(
                      onPressed: combat.level < combat.hero.ultimates[i].unlockLevel ||
                              combat.ultimateCooldowns[i] > 0
                          ? null
                          : () {
                              final result = combat.useUltimate(i);
                              if (result.accepted) {
                                _effects.add(StageEffect(
                                  kind: _ultimateEffectKind(combat.hero.ultimates[i].id),
                                  startMs: _clock.value,
                                ));
                                _select('skill', _direction, replay: true);
                              }
                              setState(() {
                                _log.value = [
                                  '${result.messageAr} · ${result.damage} ضرر',
                                  ..._log.value,
                                ].take(6).toList(growable: false);
                              });
                            },
                      child: Text(
                        '${combat.hero.ultimates[i].nameAr} · م${combat.hero.ultimates[i].unlockLevel}'
                        '${combat.level < combat.hero.ultimates[i].unlockLevel ? ' · مقفلة' : combat.ultimateCooldowns[i] > 0 ? ' · تبريد' : ''}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'نموذج قتال تجريبي ضد هدف تدريبي؛ الخبرة هنا للاختبار فقط.',
                style: TextStyle(fontSize: 11, color: theme.accent.withAlpha(170)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatePicker() {
    final theme = _theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('الحركة'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final state in heroStates)
              ChoiceChip(
                label: Text(stateLabels[state]!),
                selected: _state == state,
                onSelected: (_) => _select(state, _direction),
                selectedColor: theme.accent,
                labelStyle: TextStyle(
                  color: _state == state
                      ? theme.stageBottom
                      : const Color(0xFFD7E8DB),
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: theme.stageTop,
                side: BorderSide(color: theme.accent.withAlpha(60)),
                showCheckmark: false,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildControls() {
    final player = _player;
    final theme = _theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.stageTop,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.accent.withAlpha(60)),
      ),
      child: Row(
        children: [
          if (player == null)
            const IconButton(
              onPressed: null,
              icon: Icon(Icons.play_arrow),
            )
          else
            AnimatedBuilder(
              animation: player,
              builder: (context, _) => IconButton(
                tooltip: player.playing ? 'إيقاف مؤقت' : 'تشغيل',
                onPressed: player.toggle,
                icon: Icon(
                  player.completed
                      ? Icons.replay
                      : player.playing
                          ? Icons.pause
                          : Icons.play_arrow,
                ),
              ),
            ),
          IconButton(
            tooltip: 'إعادة من البداية',
            onPressed: player == null ? null : player.restart,
            icon: const Icon(Icons.restart_alt),
          ),
          const Spacer(),
          const Text(
            'السرعة',
            style: TextStyle(fontSize: 12, color: Color(0xFF9FB8A6)),
          ),
          const SizedBox(width: 8),
          for (final speed in const [0.5, 1.0, 1.5, 2.0])
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: ChoiceChip(
                label: Text('${speed}x'),
                selected: _speed == speed,
                onSelected: (_) => setState(() => _speed = speed),
                selectedColor: theme.accent,
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: _speed == speed
                      ? theme.stageBottom
                      : const Color(0xFFD7E8DB),
                ),
                backgroundColor: theme.stageTop,
                side: BorderSide(color: theme.accent.withAlpha(60)),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDirectionPicker() {
    final theme = _theme;
    Widget cell(String direction) {
      final selected = _direction == direction;
      return Padding(
        padding: const EdgeInsets.all(3),
        child: Tooltip(
          message: directionLabels[direction]!,
          child: Material(
            color: selected ? theme.accent : theme.stageTop,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _select(_state, direction),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Icon(
                  directionIcons[direction],
                  size: 20,
                  color: selected
                      ? theme.stageBottom
                      : const Color(0xFFBFD7C5),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'الاتجاه · ${directionLabels[_direction] ?? _direction}',
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Row(children: [cell('nw'), cell('n'), cell('ne')]),
                Row(children: [cell('w'), _centerCell(), cell('e')]),
                Row(children: [cell('sw'), cell('s'), cell('se')]),
              ],
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'كل اتجاه عبارة عن دورة كاملة حول البطل، لذلك يمكن اختيار '
                'أي زاوية أثناء اللعب دون تغيير الأبعاد أو نقطة الارتكاز.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xFF9FB8A6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _centerCell() {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      child: const Icon(Icons.my_location, size: 18, color: Color(0xFF5B7F66)),
    );
  }

  Widget _buildDetails() {
    final player = _player;
    final theme = _theme;
    if (player == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final clip = player.clip;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.stageTop,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.accent.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        clip.name,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: theme.accent,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'الإطار ${player.frameIndex + 1}/${clip.frames.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFBFD7C5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'مدة الإطار ${clip.frameDurationMs} مللي ثانية · '
                '${clip.loop ? 'حركة متكررة' : 'حركة لمرة واحدة'} · '
                '${clip.events.length} حدث',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9FB8A6),
                ),
              ),
              if (_sheetError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _sheetError!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFFFB4A9),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLog() {
    final theme = _theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('سجل الأحداث'),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<String>>(
          valueListenable: _log,
          builder: (context, entries, _) {
            if (entries.isEmpty) {
              return const Text(
                'ستظهر هنا أحداث الحركة مثل إطلاق السهم أو الإصابة.',
                style: TextStyle(fontSize: 12, color: Color(0xFF7F9788)),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.bolt, size: 14, color: theme.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFCFE4D5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HeroPickerCard extends StatelessWidget {
  const _HeroPickerCard({
    required this.hero,
    required this.selected,
    required this.unavailable,
    required this.onTap,
  });

  final HeroDefinition hero;
  final bool selected;
  final bool unavailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = hero.theme;
    return Material(
      color: selected ? theme.accentSoft : theme.stageTop,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 168,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? theme.accent
                  : theme.accent.withAlpha(unavailable ? 35 : 70),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hero.icon,
                    size: 20,
                    color: unavailable
                        ? theme.accent.withAlpha(110)
                        : theme.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hero.nameEn,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: unavailable
                            ? const Color(0xFF8DA396)
                            : const Color(0xFFE4F2E7),
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, size: 16, color: theme.accent),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                hero.nameAr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFCFE4D5),
                ),
              ),
              const Spacer(),
              Text(
                unavailable ? 'الأصول قيد الإنتاج' : hero.roleAr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: unavailable
                      ? const Color(0xFF8DA396)
                      : theme.accent.withAlpha(200),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFFD7E8DB),
      ),
    );
  }
}
