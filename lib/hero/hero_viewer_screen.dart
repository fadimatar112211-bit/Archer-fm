import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'hero_assets.dart';
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
  'projectile_release': 'إطلاق سهم',
  'bow_draw': 'شد القوس',
  'volley_charge': 'تجميع طاقة',
  'volley_release': 'وابل سهام',
  'dodge_start': 'بداية التفادي',
  'dodge_end': 'نهاية التفادي',
  'hit_react': 'ارتداد الإصابة',
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
      return 'charge';
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
  const HeroViewerScreen({super.key, required this.loader});

  final HeroAssetLoader loader;

  @override
  State<HeroViewerScreen> createState() => _HeroViewerScreenState();
}

class _HeroViewerScreenState extends State<HeroViewerScreen>
    with SingleTickerProviderStateMixin {
  late final HeroAssetLoader _loader;
  late final Ticker _ticker;

  final ValueNotifier<int> _clock = ValueNotifier<int>(0);
  final ValueNotifier<List<String>> _log = ValueNotifier<List<String>>([]);
  final List<StageEffect> _effects = [];

  HeroManifest? _manifest;
  AtlasSheet? _sheet;
  SpritePlayer? _player;
  String _state = 'idle';
  String _direction = 's';
  String? _error;
  String? _sheetError;
  bool _loadingSheet = false;
  double _speed = 1.0;
  Duration _lastTick = Duration.zero;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _loader = widget.loader;
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
    if (player != null && delta.inMilliseconds > 0) {
      player.advance((delta.inMilliseconds * _speed).round());
    }
    _clock.value = elapsed.inMilliseconds;
    _effects.removeWhere((effect) => !effect.isAlive(_clock.value));
  }

  Future<void> _loadManifest() async {
    try {
      final manifest = await _loader.loadManifest();
      if (!mounted) return;
      setState(() {
        _manifest = manifest;
        _error = null;
      });
      await _select('idle', 's');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل بيانات البطل: $error';
      });
    }
  }

  Future<void> _select(String state, String direction) async {
    final manifest = _manifest;
    if (manifest == null) return;
    if (state == _state && direction == _direction && _player != null) return;
    final name = '${state}_$direction';
    final clip = manifest.clipFor(state, direction);
    if (clip == null) {
      setState(() {
        _error = 'لا توجد حركة مسماة $name في بيانات البطل';
      });
      return;
    }
    final token = ++_loadToken;
    setState(() {
      _state = state;
      _direction = direction;
      _loadingSheet = true;
      _sheetError = null;
      _error = null;
    });
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
    return Scaffold(
      backgroundColor: const Color(0xFF07110C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1A12),
        foregroundColor: const Color(0xFFE4F2E7),
        title: const Text('Archer FM · Ranger'),
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
                _buildStage(manifest),
                const SizedBox(height: 14),
                if (_error != null) _errorCard(_error!),
                if (manifest == null && _error == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
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

  Widget _buildStage(HeroManifest? manifest) {
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
              placeholder: _sheetError ??
                  (_loadingSheet
                      ? 'جارٍ تحميل الرسوم…'
                      : 'اختر حركة واتجاهاً لعرض البطل'),
            );
          },
        ),
      ),
    );
  }

  Widget _errorCard(String message) {
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
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFFC9C9), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatePicker() {
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
                selectedColor: const Color(0xFF9BE845),
                labelStyle: TextStyle(
                  color: _state == state
                      ? const Color(0xFF07110C)
                      : const Color(0xFFD7E8DB),
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: const Color(0xFF14261B),
                side: const BorderSide(color: Color(0xFF2B4634)),
                showCheckmark: false,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildControls() {
    final player = _player;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2016),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF24402E)),
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
                selectedColor: const Color(0xFF3F6B4C),
                labelStyle: const TextStyle(fontSize: 11),
                backgroundColor: const Color(0xFF14261B),
                side: const BorderSide(color: Color(0xFF2B4634)),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDirectionPicker() {
    Widget cell(String direction) {
      final selected = _direction == direction;
      return Padding(
        padding: const EdgeInsets.all(3),
        child: Tooltip(
          message: directionLabels[direction]!,
          child: Material(
            color: selected
                ? const Color(0xFF9BE845)
                : const Color(0xFF14261B),
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
                      ? const Color(0xFF07110C)
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
            color: const Color(0xFF0F2016),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF24402E)),
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
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Color(0xFF9BE845),
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
                        const Icon(
                          Icons.bolt,
                          size: 14,
                          color: Color(0xFF9BE845),
                        ),
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
