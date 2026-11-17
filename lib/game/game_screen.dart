import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../hero/hero_assets.dart';
import '../hero/hero_catalog.dart';
import '../hero/hero_manifest.dart';
import '../hero/sprite_player.dart';
import 'arena_painter.dart';
import 'combat/hero_kit.dart';
import 'progress/hero_progress.dart';
import 'world/game_world.dart';

/// Fixed simulation step of the game loop.
const int _stepMs = 16;

/// The live battle screen: joystick movement, manual bow attacks, the five-hit
/// combo chain, the four Ranger abilities, enemy waves and the HUD.
///
/// The hero sprite comes from the same production atlas pipeline as the viewer
/// (`ranger_new` face-welded renders). The sprite layer forwards the exact
/// weapon frames (`bow_draw`, `projectile_release`, `volley_charge`,
/// `volley_release`) to the simulation, so arrows always leave the bow on the
/// frame the animation releases the string.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.hero,
    this.kit,
    this.loaderFactory = defaultHeroLoaderFactory,
    this.store,
    this.worldFactory,
  });

  final HeroDefinition hero;
  final HeroKit? kit;
  final HeroLoaderFactory loaderFactory;
  final ProgressStore? store;

  /// Injectable world constructor for tests (deterministic spawns).
  final GameWorld Function(HeroKit kit)? worldFactory;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  /// Weapon-energy accent of the active hero's kit.
  Color get accentColor => Color(kit.accentColor);
  late final HeroKit kit;
  late final GameWorld world;
  late final HeroAssetLoader loader;
  late final ProgressStore store;

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  int _accumulatorMs = 0;

  HeroManifest? manifest;
  final Map<String, AtlasSheet> _sheets = {};
  final List<String> _sheetOrder = [];
  static const int _maxSheets = 16;

  SpritePlayer? _player;
  String? _clipName;

  /// Clip currently authored as non-looping and still playing out.
  String? _busyClip;

  /// Joystick vector before normalization (magnitude decides walk vs run).
  Offset _moveRaw = Offset.zero;
  Offset _stickCenter = Offset.zero;
  bool _stickActive = false;
  bool _attackHeld = false;

  /// World timestamp until which the hit-react clip should be respected.
  int _hitReactUntilMs = 0;

  final List<FloatLabel> _labels = [];
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    kit = widget.kit ?? kitForHero(widget.hero.id);
    world = widget.worldFactory?.call(kit) ??
        GameWorld(kit: kit);
    loader = widget.loaderFactory(widget.hero);
    store = widget.store ?? SharedPreferencesProgressStore();
    _restoreProgress();
    _loadManifest();
    _ticker = createTicker(_tick);
    _ticker!.start();
  }

  @override
  void dispose() {
    _ticker?.stop();
    _toastTimer?.cancel();
    _persistProgress();
    for (final sheet in _sheets.values) {
      sheet.dispose();
    }
    _sheets.clear();
    loader.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _restoreProgress() async {
    final saved = await store.load(widget.hero.id);
    if (saved == null) return;
    setState(() {
      world.level = saved.level.clamp(1, 40);
      world.xp = saved.xp;
      world.kills = saved.kills;
    });
  }

  Future<void> _persistProgress() async {
    await store.save(
      widget.hero.id,
      HeroProgress(level: world.level, xp: world.xp, kills: world.kills),
    );
  }

  Future<void> _loadManifest() async {
    try {
      final loaded = await loader.loadManifest();
      if (!mounted) return;
      setState(() => manifest = loaded);
    } catch (error) {
      _showToast('تعذّر تحميل ملفات البطل: $error');
    }
  }

  // ---- Game loop -----------------------------------------------------------

  void _tick(Duration elapsed) {
    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    final deltaMs = delta.inMilliseconds.clamp(0, 100);
    _accumulatorMs += deltaMs;
    var stepped = false;
    while (_accumulatorMs >= _stepMs) {
      _accumulatorMs -= _stepMs;
      world.update(_stepMs);
      stepped = true;
    }
    if (stepped) {
      _handleWorldEvents();
      if (_attackHeld) _tryAttack();
      _updateSprite(deltaMs);
      _pruneLabels();
    }
  }

  void _handleWorldEvents() {
    for (final event in world.drainEvents()) {
      switch (event) {
        case EnemyKilledEvent(:final xpGained):
          _labels.add(
            FloatLabel(
              text: '+$xpGained XP',
              worldPosition: world.player.position - const Offset(0, 40),
              bornAtMs: world.nowMs,
              color: accentColor.withValues(alpha: 0.85),
            ),
          );
        case LevelUpEvent(:final newLevel, :final unlockedAbilityIds):
          _showToast('المستوى $newLevel!');
          if (unlockedAbilityIds.isNotEmpty) {
            final names = unlockedAbilityIds
                .map((id) => kit.abilityById(id)?.nameAr ?? id)
                .join(' · ');
            _showToast('قدرة جديدة: $names');
          }
          _persistProgress();
        case PlayerDamagedEvent(:final amount):
          _hitReactUntilMs = world.nowMs + 320;
          _labels.add(
            FloatLabel(
              text: '-${amount.round()}',
              worldPosition: world.player.position,
              bornAtMs: world.nowMs,
              color: const Color(0xFFFF8A80),
            ),
          );
        case PlayerDiedEvent():
          _showToast('سقط البطل — عودة بعد لحظات');
          _persistProgress();
        case PlayerRespawnedEvent():
          _showToast('عدت إلى المعركة');
        case AbilityReadyEvent(:final abilityId):
          final name = kit.abilityById(abilityId)?.nameAr;
          if (name != null) _showToast('القدرة "$name" متاحة الآن');
      }
    }
  }

  void _pruneLabels() {
    _labels.removeWhere(
      (label) => world.nowMs - label.bornAtMs > FloatLabel.lifetimeMs,
    );
  }

  // ---- Input ------------------------------------------------------------------

  void _tryAttack() {
    if (_busyClip != null || manifest == null) return;
    if (!world.requestAttack()) return;
    _playClip('attack', pace: world.currentAttackRate());
  }

  void _onAbilityTap(String abilityId) {
    if (_busyClip != null || manifest == null) return;
    final def = kit.abilityById(abilityId);
    if (def == null) return;
    final accepted = world.useAbility(abilityId);
    if (accepted == null) {
      if (def.unlockLevel > world.level) {
        _showToast('تُفتح عند المستوى ${def.unlockLevel}');
      } else if (world.player.energy < def.energyCost) {
        _showToast('الطاقة غير كافية');
      }
      return;
    }
    _playClip(
      def.usesAttackClip ? 'attack' : 'skill',
      pace: world.currentAttackRate(),
    );
  }

  void _onDodgeTap() {
    if (_busyClip != null || manifest == null) return;
    if (world.requestDodge()) {
      _playClip('dodge', pace: 1.0);
    } else {
      _showToast('المراوغة قيد الانتظار');
    }
  }

  // ---- Sprite control ---------------------------------------------------------

  void _updateSprite(int deltaMs) {
    final m = manifest;
    if (m == null) return;
    final player = world.player;

    final desired = _desiredState();
    final desiredDir = GameWorld.octantNames[
        GameWorld.octantIndexOf(player.facing)];
    final desiredName = '${desired}_$desiredDir';

    final busy = _busyClip != null &&
        _player != null &&
        !_player!.completed;
    if (busy) {
      // Advance the active non-loop clip with its pace.
      final pace = _clipName?.startsWith('attack') == true ||
              _clipName?.startsWith('skill') == true
          ? world.currentAttackRate()
          : 1.0;
      _player?.advance((deltaMs * pace).round());
      return;
    }
    if (_busyClip != null) {
      _busyClip = null;
      _hitReactUntilMs = 0;
    }
    if (_clipName != desiredName) {
      _playClip(desired, pace: 1.0, directionLocked: desiredDir);
    }
    _player?.advance(deltaMs);
  }

  /// Picks the sprite state the simulation implies right now.
  String _desiredState() {
    final player = world.player;
    if (player.dead) return 'death';
    if (world.nowMs < _hitReactUntilMs) return 'hit';
    if (player.dodgeBurstUntilMs > world.nowMs) return 'dodge';
    if (_moveRaw.distance > 0.15) {
      return _moveRaw.distance > 0.72 ? 'run' : 'walk';
    }
    return 'idle';
  }

  void _playClip(
    String state, {
    required double pace,
    String? directionLocked,
  }) {
    final m = manifest;
    if (m == null) return;
    final dir = directionLocked ??
        GameWorld.octantNames[GameWorld.octantIndexOf(world.player.facing)];
    final name = '${state}_$dir';
    final clip = m.clipFor(state, dir);
    if (clip == null) return;
    final player = _player;
    if (player == null || _clipName != name) {
      final fresh = SpritePlayer(
        clip: clip,
        onEvent: _handleSpriteEvent,
      );
      _player?.dispose();
      _player = fresh;
      _clipName = name;
      _loadSheet(name);
    } else {
      player.restart();
    }
    if (!clip.loop) _busyClip = name;
  }

  void _handleSpriteEvent(AnimationEvent event) {
    switch (event.name) {
      case 'projectile_release':
      case 'melee_impact':
        if (world.pendingAbilityId == 'piercing_shot' ||
            world.pendingAbilityId == 'flame_slash' ||
            world.pendingAbilityId == 'twin_fangs') {
          world.releaseWeaponPayload(volley: false);
        } else if (kit.attackStyle == AttackStyle.melee) {
          world.releaseMeleeSwing();
        } else {
          world.releaseArrow();
        }
      case 'volley_release':
      case 'inferno_burst':
      case 'shadow_burst':
        world.releaseWeaponPayload(volley: true);
      default:
        // Weapon draw cues (`bow_draw`, `volley_charge`, `weapon_windup`,
        // `inferno_charge`); effects are painted from the weapon state.
        break;
    }
  }

  Future<void> _loadSheet(String animation) async {
    final m = manifest;
    if (m == null) return;
    if (_sheets.containsKey(animation)) {
      _touchSheet(animation);
      if (mounted) setState(() {});
      return;
    }
    try {
      final sheet = await loader.loadSheet(m, animation);
      if (!mounted) {
        sheet.dispose();
        return;
      }
      if (_sheets[animation] != null) {
        // Another load for the same key already finished.
        sheet.dispose();
        return;
      }
      _sheets[animation] = sheet;
      _sheetOrder.add(animation);
      _evictOverflow();
      setState(() {});
    } catch (error) {
      _showToast('تعذّر تحميل الأطلس: $error');
    }
  }

  void _touchSheet(String animation) {
    _sheetOrder.remove(animation);
    _sheetOrder.add(animation);
  }

  void _evictOverflow() {
    while (_sheetOrder.length > _maxSheets) {
      final evicted = _sheetOrder.removeAt(0);
      final sheet = _sheets.remove(evicted);
      sheet?.dispose();
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    setState(() => _toast = message);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ---- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeSheet = _clipName == null ? null : _sheets[_clipName!];
    final combo = world.combo;
    final comboText = combo.chainLength > 0 &&
            combo.lastHitAtMs != null &&
            world.nowMs - combo.lastHitAtMs! <= combo.windowMs
        ? 'الضربة ${combo.chainLength}/5 · '
            '${(kit.comboHit(combo.chainLength).multiplier * 100).round()}%'
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF07110A),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            // Arena.
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ArenaPainter(
                    world: world,
                    presentation: ArenaPresentation(
                      kit: kit,
                      theme: theme,
                      sheet: activeSheet,
                      frameId: _player?.frameId,
                      pivotX: manifest?.pivotX ?? 0.5,
                      pivotY: manifest?.pivotY ?? 0.86,
                      frameWidth: manifest?.frameWidth ?? 192,
                      frameHeight: manifest?.frameHeight ?? 192,
                      labels: _labels,
                      timeMs: world.nowMs,
                      comboText: comboText,
                    ),
                  ),
                ),
              ),
            ),
            // Top HUD.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _statusPanel(theme)),
                          const SizedBox(width: 10),
                          _statsPanel(theme, comboText: comboText),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Joystick zone (left half, lower part).
            Positioned(
              left: 0,
              bottom: 0,
              width: MediaQuery.sizeOf(context).width * 0.55,
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  _stickActive = true;
                  _stickCenter = event.position;
                  _updateStick(event.position);
                },
                onPointerMove: (event) {
                  if (_stickActive) _updateStick(event.position);
                },
                onPointerUp: (_) => _resetStick(),
                onPointerCancel: (_) => _resetStick(),
                child: CustomPaint(
                  painter: _JoystickPainter(
                    active: _stickActive,
                    center: _stickActive
                        ? _stickCenter
                        : Offset.zero,
                    knob: _stickActive
                        ? _stickCenter +
                            _clampStick(_moveRaw)
                        : Offset.zero,
                    accent: accentColor,
                  ),
                ),
              ),
            ),
            // Controls (bottom-right).
            Positioned(
              right: 16,
              bottom: 24,
              child: _controlCluster(theme),
            ),
            // Exit button.
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.white70,
                  tooltip: 'خروج',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            // Toast.
            if (_toast != null)
              Positioned(
                top: 84,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _toast!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Offset _clampStick(Offset raw) {
    final length = raw.distance;
    if (length <= 56) return raw;
    return raw / length * 56;
  }

  void _updateStick(Offset position) {
    final raw = position - _stickCenter;
    if (raw.distance < 8) {
      setState(() => _moveRaw = Offset.zero);
      world.setMoveInput(Offset.zero);
      return;
    }
    setState(() => _moveRaw = raw);
    world.setMoveInput(raw);
  }

  void _resetStick() {
    _stickActive = false;
    _moveRaw = Offset.zero;
    world.setMoveInput(Offset.zero);
    if (mounted) setState(() {});
  }

  // ---- HUD panels -----------------------------------------------------------------

  Widget _statusPanel(ThemeData theme) {
    final player = world.player;
    final hpRatio = (player.hp / kit.baseMaxHp).clamp(0.0, 1.0);
    final energyRatio = (player.energy / kit.baseMaxEnergy).clamp(0.0, 1.0);
    final xpNeeded = GameWorld.xpForLevel(world.level);
    final xpRatio = world.level >= 40 ? 1.0 : world.xp / xpNeeded;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Color(0xFFFF5A4A), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: _bar(hpRatio, const Color(0xFF7CFF6B),
                    const Color(0xFFFF5A4A)),
              ),
              const SizedBox(width: 6),
              Text(
                '${player.hp.round()}/${kit.baseMaxHp.round()}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.bolt, color: Color(0xFFE8FF6B), size: 16),
              const SizedBox(width: 6),
              Expanded(child: _bar(energyRatio, const Color(0xFFE8FF6B),
                  const Color(0xFFE8FF6B))),
              const SizedBox(width: 6),
              Text(
                '${player.energy.round()}/${kit.baseMaxEnergy.round()}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'المستوى ${world.level}${world.level >= 40 ? ' (الأقصى)' : ''}',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: xpRatio.clamp(0.0, 1.0),
                    backgroundColor: const Color(0x22FFFFFF),
                    valueColor: AlwaysStoppedAnimation(accentColor),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                world.level >= 40
                    ? 'مكتمل'
                    : '${world.xp}/${GameWorld.xpForLevel(world.level)}',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(double ratio, Color fullColor, Color lowColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio.clamp(0.0, 1.0),
        backgroundColor: const Color(0x22FFFFFF),
        valueColor: AlwaysStoppedAnimation(
          Color.lerp(lowColor, fullColor, ratio.clamp(0.0, 1.0))!,
        ),
        minHeight: 8,
      ),
    );
  }

  Widget _statsPanel(ThemeData theme, {String? comboText}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'إصابات: ${world.kills} · ضرر: ${world.totalDamageDealt.round()}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          if (comboText != null) ...[
            const SizedBox(height: 4),
            Text(
              comboText,
              style: TextStyle(
                color: accentColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() => BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      );

  Widget _controlCluster(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final ability in kit.abilities)
                  _AbilityButton(
                    def: ability,
                    level: world.level,
                    readyAtMs:
                        world.abilityReadyAtMs[ability.id] ?? 0,
                    nowMs: world.nowMs,
                    energy: world.player.energy,
                    accent: accentColor,
                    onTap: () => _onAbilityTap(ability.id),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            _roundButton(
              icon: Icons.airline_stops,
              label: 'مراوغة',
              size: 56,
              color: const Color(0xFF6FE8FF),
              onTap: _onDodgeTap,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _attackButton(),
      ],
    );
  }

  Widget _attackButton() {
    return Listener(
      key: const ValueKey('btn_attack'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        _attackHeld = true;
        _tryAttack();
      },
      onPointerUp: (_) => _attackHeld = false,
      onPointerCancel: (_) => _attackHeld = false,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Color.lerp(accentColor, Colors.white, 0.25)!,
              accentColor.withValues(alpha: 0.85),
            ],
          ),
          border: Border.all(
            color: Color.lerp(accentColor, Colors.white, 0.45)!,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.4),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gps_fixed, color: Colors.white, size: 30),
              Text(
                'هجوم',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required String label,
    required double size,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: const ValueKey('btn_dodge'),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.5),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: size * 0.4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: size * 0.16),
            ),
          ],
        ),
      ),
    );
  }
}

class _AbilityButton extends StatelessWidget {
  const _AbilityButton({
    required this.def,
    required this.level,
    required this.readyAtMs,
    required this.nowMs,
    required this.energy,
    required this.accent,
    required this.onTap,
  });

  final AbilityDef def;
  final int level;
  final int readyAtMs;
  final int nowMs;
  final double energy;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = def.unlockLevel > level;
    final cooldownMs = readyAtMs - nowMs;
    final cooldownRatio =
        locked ? 0.0 : (cooldownMs / def.cooldownMs).clamp(0.0, 1.0);
    final noEnergy = !locked && energy < def.energyCost;
    final enabled = !locked && cooldownMs <= 0 && !noEnergy;
    final color = locked ? const Color(0xFF6B7263) : accent;

    return Padding(
      key: ValueKey('ability_${def.id}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.55),
                  border: Border.all(
                    color: enabled ? color : color.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: locked
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline,
                                color: Color(0xFF9BA394), size: 16),
                            Text(
                              'م${def.unlockLevel}',
                              style: const TextStyle(
                                color: Color(0xFF9BA394),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        )
                      : Icon(
                          Icons.auto_awesome,
                          color: noEnergy
                              ? color.withValues(alpha: 0.4)
                              : color,
                          size: 20,
                        ),
                ),
              ),
              if (cooldownRatio > 0)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CooldownSweep(
                      ratio: cooldownRatio,
                      color: color.withValues(alpha: 0.35),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CooldownSweep extends CustomPainter {
  _CooldownSweep({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      Offset.zero & size,
      -math.pi / 2,
      2 * math.pi * ratio,
      false,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _CooldownSweep old) => old.ratio != ratio;
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.active,
    required this.center,
    required this.knob,
    required this.accent,
  });

  final bool active;
  final Offset center;
  final Offset knob;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    canvas.drawCircle(
      center,
      56,
      Paint()
        ..color = accent.withValues(alpha: 0.14)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      56,
      Paint()
        ..color = accent.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(knob, 22, Paint()..color = accent.withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter old) => true;
}
