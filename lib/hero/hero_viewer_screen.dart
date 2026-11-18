import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/render3/glb.dart';
import '../game/render3/hero3d_controller.dart';
import '../game/render3/hero3d_painter.dart';
import 'package:flutter/scheduler.dart';

import 'hero_assets.dart';
import 'hero_catalog.dart';
import 'hero_manifest.dart';
import 'hero_stage.dart';
import 'sprite_player.dart';

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
  late final Ticker _ticker;

  final ValueNotifier<int> _clock = ValueNotifier<int>(0);
  final ValueNotifier<List<String>> _log = ValueNotifier<List<String>>([]);
  final List<StageEffect> _effects = [];
  final Set<String> _unavailable = <String>{};

  HeroManifest? _manifest;
  Hero3DController? _hero3d;
  String? _hero3dError;
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

  @override
  void initState() {
    super.initState();
    _hero = widget.initialHero ?? heroCatalog.first;
    _loader = widget.loaderFactory(_hero);
    _ticker = createTicker(_onTick)..start();
    _loadManifest();
    _loadHero3D();
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
    if (player != null && delta.inMilliseconds > 0) {
      player.advance((delta.inMilliseconds * _speed).round());
    }
    _hero3d?.advance(elapsed.inMilliseconds, onEvent: _handle3DEvent);
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
      _loader = widget.loaderFactory(hero);
      _manifest = null;
      _hero3d = null;
      _hero3dError = null;
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
    await _loadHero3D();
  }

  Future<void> _loadHero3D() async {
    final hero = _hero;
    final paths = <String>[
      if (hero.id == 'ranger_new') 'assets/heroes/ranger_new/ranger_animated.glb',
      'assets/heroes/${hero.id}/model/${hero.id}_animated.glb',
    ];
    try {
      ByteData? data;
      for (final path in paths) {
        try { data = await rootBundle.load(path); break; } catch (_) {}
      }
      if (data == null) throw StateError('GLB missing for ${hero.id}');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final model = await GlbModel.load(bytes);
      final controller = Hero3DController(Hero3DModel(model));
      controller.model.calibrate();
      controller.playClip('idle', loop: true, pace: _speed, nowMs: _clock.value, events: const []);
      if (!mounted || hero.id != _hero.id) return;
      setState(() { _hero3d = controller; _hero3dError = null; });
    } catch (error) {
      if (!mounted || hero.id != _hero.id) return;
      setState(() => _hero3dError = '$error');
    }
  }

  Offset _directionVector(String direction) => switch (direction) {
    'n' => const Offset(0, -1), 'ne' => const Offset(1, -1),
    'e' => const Offset(1, 0), 'se' => const Offset(1, 1),
    's' => const Offset(0, 1), 'sw' => const Offset(-1, 1),
    'w' => const Offset(-1, 0), 'nw' => const Offset(-1, -1),
    _ => const Offset(0, 1),
  };
  Future<void> _select(String state, String direction) async {
    final manifest = _manifest;
    final hero3d = _hero3d;
    if (manifest == null && hero3d == null) return;
    if (state == _state &&
        direction == _direction &&
        (_player != null || hero3d != null)) {
      return;
    }

    final name = '${state}_${direction}';
    final clip = manifest?.clipFor(state, direction);
    final has3DClip = hero3d?.model.model.clips.containsKey(state) ?? false;
    if (clip == null && !has3DClip) {
      setState(() {
        _error = 'لا توجد حركة $name في بيانات الأطلس أو المجسم ثلاثي الأبعاد';
      });
      return;
    }

    final token = ++_loadToken;
    if (hero3d != null && has3DClip) {
      hero3d.playClip(
        state,
        loop: const ['idle', 'walk', 'run'].contains(state),
        pace: _speed,
        nowMs: _clock.value,
        events: Hero3DController.scheduleFor(manifest, state),
        durationMs: Hero3DController.durationFor(manifest, state),
      );
    }
    setState(() {
      _state = state;
      _direction = direction;
      _loadingSheet = manifest != null && clip != null;
      _sheetError = null;
      _error = null;
      _errorDetail = null;
    });

    // GLB-only previews must remain usable even when the optional atlas
    // manifest or directional sprite clip is unavailable.
    if (manifest == null || clip == null) {
      setState(() {
        _player?.dispose();
        _player = null;
        _sheet = null;
        _loadingSheet = false;
      });
      return;
    }

    AtlasSheet? sheet;
    String? sheetError;
    try {
      sheet = await _loader.loadSheet(manifest, name);
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

  void _handleEvent(AnimationEvent event) => _recordEvent(event.name);

  void _handle3DEvent(String eventName) => _recordEvent(eventName);

  void _recordEvent(String eventName) {
    final now = _clock.value;
    _effects.add(StageEffect(kind: _effectForEvent(eventName), startMs: now));
    final state = stateLabels[_state] ?? _state;
    final direction = directionLabels[_direction] ?? _direction;
    final label = eventLabels[eventName] ?? eventName;
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
            final hero3d = _hero3d;
            if (hero3d != null) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [theme.stageTop, theme.stageBottom]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: CustomPaint(
                  painter: _Hero3DPreviewPainter(controller: hero3d, facing: _directionVector(_direction), timeMs: _clock.value, theme: theme),
                  child: const SizedBox.expand(),
                ),
              );
            }
            return HeroStage(
              sheet: _sheet,
              frameId: player?.frameId,
              pivotX: manifest?.pivotX ?? 0.5,
              pivotY: manifest?.pivotY ?? 0.86,
              effects: _effects,
              timeMs: _clock.value,
              theme: theme,
              placeholder: _hero3dError != null ? 'تعذّر تحميل المجسم ثلاثي الأبعاد: $_hero3dError' : _sheetError ??
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
            onPressed: player?.restart,
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

class _Hero3DPreviewPainter extends CustomPainter {
  const _Hero3DPreviewPainter({required this.controller, required this.facing, required this.timeMs, required this.theme});
  final Hero3DController controller;
  final Offset facing;
  final int timeMs;
  final HeroTheme theme;
  @override
  void paint(Canvas canvas, Size size) {
    final ground = Paint()..color = theme.accent.withAlpha(24);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width / 2, size.height * .88), width: size.width * .55, height: size.height * .10), ground);
    controller.paint(canvas, anchor: Offset(size.width / 2, size.height * .88), facing: facing, scale: controller.scaleForPixelHeight(size.height * .68));
  }
  @override
  bool shouldRepaint(covariant _Hero3DPreviewPainter old) => old.controller != controller || old.facing != facing || old.timeMs != timeMs || old.theme != theme;
}
