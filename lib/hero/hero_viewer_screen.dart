import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'hero_catalog.dart';
import 'hero3d.dart';

/// Placeholder type kept for backward-compatible constructor signature.
/// The old sprite system used it; Hero3D loads its own .bin assets.
typedef HeroLoaderFactory = dynamic;

class HeroViewerScreen extends StatefulWidget {
  const HeroViewerScreen({
    super.key,
    this.loaderFactory,
    this.initialHero,
  });

  final HeroLoaderFactory? loaderFactory;
  final HeroDefinition? initialHero;

  @override
  State<HeroViewerScreen> createState() => _HeroViewerScreenState();
}

class _HeroViewerScreenState extends State<HeroViewerScreen>
    with SingleTickerProviderStateMixin {
  late HeroDefinition _hero;
  late Hero3D _hero3d;
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  Size _stageSize = const Size(400, 400);

  Duration _lastTick = Duration.zero;
  Offset _stick = Offset.zero;
  Offset _stickOrigin = Offset.zero;
  bool _stickActive = false;
  String _lastAnim = 'idle';
  final List<String> _log = <String>[];

  static const List<String> _movementOrder = [
    'idle',
    'run',
    'attack1',
    'attack2',
    'attack3',
    'attack4',
    'attack5',
    'dash',
    'hurt',
    'death',
    'ult1',
    'ult2',
    'ult3',
    'ult4',
  ];

  static const Map<String, String> _movementLabels = {
    'idle': 'وقوف',
    'run': 'جري',
    'attack1': 'كومبو 1',
    'attack2': 'كومبو 2',
    'attack3': 'كومبو 3',
    'attack4': 'كومبو 4',
    'attack5': 'كومبو 5',
    'dash': 'اندفاع',
    'hurt': 'إصابة',
    'death': 'موت',
    'ult1': 'مهارة 1',
    'ult2': 'مهارة 2',
    'ult3': 'مهارة 3',
    'ult4': 'مهارة 4',
  };

  static const Map<String, String> _soundToAsset = {
    'swish': 'audio/flame/swish.wav',
    'boom': 'audio/flame/boom.wav',
    'charge': 'audio/flame/charge.wav',
    'step': 'audio/flame/step.wav',
    'hit': 'audio/flame/hit.wav',
    'hurt': 'audio/flame/hurt.wav',
    'death': 'audio/flame/death.wav',
  };

  @override
  void initState() {
    super.initState();
    _hero = widget.initialHero ?? heroCatalog.first;
    _hero3d = _createHero(_hero);
    _ticker = createTicker(_onTick)..start();
  }

  Hero3D _createHero(HeroDefinition hero) {
    final h = Hero3D(hero.id, height: 150);
    h.position = const Offset(260, 360);
    h.onSound = _onSound;
    h.load().then((_) {
      if (mounted) setState(() {});
    });
    return h;
  }

  void _onSound(String sound) {
    final asset = _soundToAsset[sound];
    if (asset == null) return;
    // Flame audio assets are bundled and mapped; playback is best-effort.
    // In this environment no audio plugin is available in cache, so we
    // keep the integration point without crashing.
    _log.insert(0, 'صوت: ${sound.split('.').first}');
    if (_log.length > 8) _log.removeRange(8, _log.length);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _hero3d.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _lastTick = elapsed;
    final move = _stickActive ? _stick : Offset.zero;
    _hero3d.update(dt, move);
    // Keep hero centered in viewer stage for stable preview.
    _hero3d.position = Offset(_stageSize.width * 0.5, _stageSize.height * 0.82);
    _hero3d.height = _stageSize.height * 0.42;
    if (_hero3d.anim != _lastAnim) {
      _lastAnim = _hero3d.anim;
      _log.insert(0, '${_hero.nameAr} · ${_movementLabels[_lastAnim] ?? _lastAnim}');
      if (_log.length > 8) _log.removeRange(8, _log.length);
    }
    _frame.value++;
  }

  void _switchHero(HeroDefinition hero) {
    if (hero.id == _hero.id) return;
    setState(() {
      _hero = hero;
      _lastAnim = 'idle';
      _log.clear();
      _hero3d.dispose();
      _hero3d = _createHero(hero);
    });
  }

  void _playMovement(String key) {
    switch (key) {
      case 'idle':
        _hero3d.revive(_hero3d.hp <= 0 ? 100 : _hero3d.hp);
        // revive sets idle; if alive it also sets idle via timers clear+set. 
        // For alive case, force idle by using revive-like behavior:
        if (!_hero3d.isDead) {
          _hero3d.revive(_hero3d.hp);
        }
        break;
      case 'run':
        // Run is driven by movement input; give a brief nudge.
        _stick = const Offset(0, 1);
        _stickActive = true;
        Future<void>.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            _stickActive = false;
            _stick = Offset.zero;
          }
        });
        break;
      case 'attack1':
      case 'attack2':
      case 'attack3':
      case 'attack4':
      case 'attack5':
        _hero3d.attack();
        break;
      case 'dash':
        _hero3d.dash();
        break;
      case 'hurt':
        _hero3d.hurt(20);
        break;
      case 'death':
        _hero3d.hurt(_hero3d.hp > 0 ? _hero3d.hp : 100);
        break;
      case 'ult1':
        _hero3d.ultimate(1);
        break;
      case 'ult2':
        _hero3d.ultimate(2);
        break;
      case 'ult3':
        _hero3d.ultimate(3);
        break;
      case 'ult4':
        _hero3d.ultimate(4);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _hero.theme;
    return Scaffold(
      backgroundColor: theme.stageBottom,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              _buildHeader(theme),
              Expanded(
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _buildStage(theme)),
                    Expanded(flex: 2, child: _buildControls(theme)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(HeroTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: theme.stageTop,
      child: Row(
        children: [
          Icon(_hero.icon, color: theme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Archer FM · ${_hero.nameAr}',
              style: const TextStyle(color: Color(0xFFE4F2E7), fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            _hero3d.isReady ? 'Hero3D جاهز' : 'جارٍ التحميل…',
            style: TextStyle(color: theme.accent.withAlpha(180), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStage(HeroTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.stageTop, theme.stageMid, theme.stageBottom],
            ),
          ),
          child: GestureDetector(
            onPanStart: (d) => _stickOrigin = d.localPosition,
            onPanUpdate: (d) {
              _stickActive = true;
              _stick = (d.localPosition - _stickOrigin) / 50;
            },
            onPanEnd: (_) {
              _stickActive = false;
              _stick = Offset.zero;
            },
            onPanCancel: () {
              _stickActive = false;
              _stick = Offset.zero;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                _stageSize = constraints.biggest;
                return ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  builder: (context, _, __) {
                    return CustomPaint(
                      painter: _Hero3DPainter(_hero3d, theme),
                      size: Size.infinite,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(HeroTheme theme) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _sectionTitle('الأبطال'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final hero in heroCatalog)
              ChoiceChip(
                label: Text(hero.nameAr),
                selected: hero.id == _hero.id,
                onSelected: (_) => _switchHero(hero),
                selectedColor: hero.theme.accent,
                labelStyle: TextStyle(
                  color: hero.id == _hero.id ? hero.theme.stageBottom : const Color(0xFFE4F2E7),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                backgroundColor: theme.stageTop,
                side: BorderSide(color: hero.theme.accent.withAlpha(90)),
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 10),
        _buildHeroInfo(theme),
        const SizedBox(height: 10),
        _sectionTitle('الحركات'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final key in _movementOrder)
              _moveButton(key, theme),
          ],
        ),
        const SizedBox(height: 10),
        _sectionTitle('سجل'),
        const SizedBox(height: 6),
        for (final line in _log.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(line, style: TextStyle(color: theme.accent.withAlpha(190), fontSize: 11)),
          ),
      ],
    );
  }

  Widget _buildHeroInfo(HeroTheme theme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.stageTop,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.accent.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_hero.nameAr} · ${_hero.roleAr}',
              style: const TextStyle(color: Color(0xFFE4F2E7), fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4),
          Text('${_hero.weaponAr} · ${_hero.skillAr}',
              style: TextStyle(color: theme.accent, fontSize: 12)),
          const SizedBox(height: 4),
          Text(_hero.descriptionAr,
              style: const TextStyle(color: Color(0xFFAFC8B6), fontSize: 11, height: 1.4)),
          const SizedBox(height: 6),
          ValueListenableBuilder<int>(
            valueListenable: _frame,
            builder: (context, _, __) => Text(
              'الحركة: ${_movementLabels[_hero3d.anim] ?? _hero3d.anim} · HP: ${_hero3d.hp}',
              style: TextStyle(color: theme.accent.withAlpha(200), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moveButton(String key, HeroTheme theme) {
    final label = _movementLabels[key] ?? key;
    return ElevatedButton(
      onPressed: () => _playMovement(key),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.stageTop,
        foregroundColor: const Color(0xFFE4F2E7),
        side: BorderSide(color: theme.accent.withAlpha(80)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 34),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(color: Color(0xFFD7E8DB), fontSize: 13, fontWeight: FontWeight.w700));
  }
}

class _Hero3DPainter extends CustomPainter {
  _Hero3DPainter(this.hero, this.theme);
  final Hero3D hero;
  final HeroTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    hero.paint(canvas);
  }

  @override
  bool shouldRepaint(covariant _Hero3DPainter oldDelegate) => true;
}
