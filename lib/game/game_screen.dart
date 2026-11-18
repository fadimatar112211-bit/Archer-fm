import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../audio_service.dart';
import '../hero/hero_assets.dart';
import '../hero/hero_catalog.dart';
import '../hero/hero_manifest.dart';
import '../hero/sprite_player.dart';
import 'arena_painter.dart';
import 'combat/hero_kit.dart';
import 'minimap.dart';
import 'monsters/monster_models.dart';
import 'progress/equipment.dart';
import 'progress/hero_progress.dart';
import 'progress/progression.dart';
import 'settings.dart';
import 'render3/glb.dart';
import 'render3/hero3d_controller.dart';
import 'render3/hero3d_painter.dart';
import 'world/arena_map.dart';
import 'world/castle_system.dart';
import 'world/game_world.dart';
import 'world/mine_system.dart';

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
    this.hero3dBytes,
    this.hero3dController,
    this.onNetworkTick,
    this.onWorldEvent,
    this.onNetworkAttack,
    this.settingsStore,
    this.startingArmy,
    this.weaponId,
  });

  final HeroDefinition hero;
  final HeroKit? kit;
  final HeroLoaderFactory loaderFactory;
  final ProgressStore? store;

  /// Injectable world constructor for tests (deterministic spawns).
  final GameWorld Function(HeroKit kit)? worldFactory;

  /// Injectable GLB bytes for the in-game 3D hero (tests); when null the real
  /// bundled model under `assets/heroes/<id>/model/` is used and the screen
  /// falls back to the atlas sprite if it is missing.
  final Future<Uint8List?> Function(HeroDefinition hero)? hero3dBytes;

  /// Injectable pre-built 3D hero controller (tests): skips the async GLB
  /// load entirely, which cannot complete inside a widget test's fake async
  /// zone without `tester.runAsync`.
  final Hero3DController? hero3dController;

  /// Optional multiplayer hooks. The local simulation always runs; these
  /// forward intent and events to the authoritative host when present.
  final void Function(Offset position, int atMs)? onNetworkTick;
  final void Function(WorldEvent event)? onWorldEvent;
  final VoidCallback? onNetworkAttack;

  /// Injectable control settings store (tests); defaults to shared prefs.
  final SettingsStore? settingsStore;

  /// Optional free 20-monster starting army chosen before the match. When
  /// omitted the balanced default is used, so all existing callers are intact.
  final Map<MonsterType, int>? startingArmy;

  /// Weapon chosen before the match from the hero's three options.
  final String? weaponId;

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

  /// Permanent account progression (currency, materials, equipment, upgrades)
  /// loaded from [store] at startup and saved back when the match ends.
  late ProgressionController progression;

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  int _accumulatorMs = 0;

  /// Player-adjusted control layout, loaded at startup and reapplied live.
  GameSettings _settings = const GameSettings();
  late final SettingsStore _settingsStore;
  late final AudioService _audio;

  HeroManifest? manifest;
  final Map<String, AtlasSheet> _sheets = {};
  final List<String> _sheetOrder = [];
  static const int _maxSheets = 16;

  SpritePlayer? _player;
  String? _clipName;

  /// In-game 3D hero controller; null until the GLB loads, in which case the
  /// atlas sprite path is used instead.
  Hero3DController? _hero3d;

  /// Clip currently authored as non-looping and still playing out.
  String? _busyClip;

  /// Armed by the rebuild button: the next arena tap chooses the crystal spot.
  bool _placingCrystal = false;

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
    kit = widget.kit ??
        kitForHero(widget.hero.id).withWeapon(widget.weaponId);
    world = widget.worldFactory?.call(kit) ??
        GameWorld(kit: kit, startingArmy: widget.startingArmy);
    loader = widget.loaderFactory(widget.hero);
    store = widget.store ?? SharedPreferencesProgressStore();
    _settingsStore = widget.settingsStore ?? SharedPreferencesSettingsStore();
    _audio = AudioScope.of(context);
    progression = ProgressionController(heroId: widget.hero.id);
    _restoreProgress();
    _loadSettings();
    _loadManifest();
    _loadHero3D();
    _ticker = createTicker(_tick);
    _ticker!.start();
  }

  @override
  void dispose() {
    _ticker?.stop();
    _toastTimer?.cancel();
    _audio.stopMusic();
    // Credit everything earned in this match (also when the player lost or
    // left early) before saving the permanent profile.
    world.settleMatch();
    _syncWorldToProgression();
    _persistProgress();
    for (final sheet in _sheets.values) {
      sheet.dispose();
    }
    _sheets.clear();
    loader.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final loaded = await _settingsStore.load();
    if (!mounted) return;
    setState(() => _settings = loaded);
    // The user may have changed the toggles from the menu since app startup.
    await _audio.setMusicEnabled(loaded.musicEnabled);
    await _audio.setSfxEnabled(loaded.sfxEnabled);
    if (loaded.musicEnabled) _audio.playMusic(MusicTrack.battle);
  }

  Future<void> _restoreProgress() async {
    final saved = await store.load(widget.hero.id);
    if (saved == null) return;
    if (!mounted) return;
    setState(() {
      world.level = saved.level.clamp(1, 40);
      world.xp = saved.xp;
      world.kills = saved.kills;
      world.upgrades.loadFromMap(saved.armyLevels);
      progression = ProgressionController.fromProgress(widget.hero.id, saved);
      _syncProgressionToWorld();
      world.applyProgression(
        bonuses: progression.bonuses,
        carryCapacity: progression.carryCapacity,
      );
    });
  }

  /// The world's wallet is a working copy; the controller is authoritative
  /// between matches.
  void _syncProgressionToWorld() {
    world.essence = progression.currency;
    world.materials
      ..clear()
      ..addAll(progression.materials);
  }

  void _syncWorldToProgression() {
    progression.currency = world.essence;
    for (final entry in world.materials.entries) {
      progression.materials[entry.key] = entry.value;
    }
  }

  Future<void> _persistProgress() async {
    _syncWorldToProgression();
    await store.save(
      widget.hero.id,
      HeroProgress(
        level: world.level,
        xp: world.xp,
        kills: world.kills,
        armyLevels: world.upgrades.toMap(),
        essence: progression.currency,
        materials: {
          for (final entry in progression.materials.entries)
            entry.key.name: entry.value,
        },
        equipment: progression.equipment,
        equipped: {
          for (final entry in progression.equipped.entries)
            entry.key.name: entry.value,
        },
        capacityLevel: progression.capacityLevel,
        heroUpgradeLevel: progression.heroUpgradeLevel,
      ),
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

  /// Loads the hero's real GLB (bones/rig/animations) and switches the hero's
  /// in-arena visual to the 3D model. Falls back to the atlas sprite when no
  /// model is bundled for this hero.
  Future<void> _loadHero3D() async {
    if (widget.hero3dController != null) {
      _hero3d = widget.hero3dController;
      return;
    }
    Uint8List? bytes;
    try {
      if (widget.hero3dBytes != null) {
        bytes = await widget.hero3dBytes!(widget.hero);
      } else {
        for (final path in _glbCandidatePaths(widget.hero.id)) {
          try {
            final data = await rootBundle.load(path);
            bytes = data.buffer.asUint8List();
            break;
          } catch (_) {
            // Try the next candidate.
          }
        }
      }
    } catch (_) {
      bytes = null;
    }
    if (!mounted || bytes == null) return; // atlas fallback stays active
    try {
      final model = await GlbModel.load(bytes);
      if (!mounted) return;
      setState(() => _hero3d = Hero3DController(Hero3DModel(model)));
    } catch (error) {
      debugPrint('hero3d load failed: $error');
    }
  }

  /// Candidate GLB locations per hero id, newest convention first.
  static List<String> _glbCandidatePaths(String heroId) => [
        'assets/heroes/$heroId/model/${heroId}_animated.glb',
        'assets/heroes/$heroId/${heroId}_animated.glb',
        // The reference ranger ships at its production path.
        if (heroId == 'ranger_new')
          'assets/heroes/ranger_new/ranger_animated.glb',
      ];

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
      widget.onNetworkTick?.call(world.player.position, world.nowMs);
      _handleWorldEvents();
      if (_attackHeld) _tryAttack();
      _updateSprite(deltaMs);
      _pruneLabels();
    }
  }

  void _handleWorldEvents() {
    for (final event in world.drainEvents()) {
      widget.onWorldEvent?.call(event);
      switch (event) {
        case EnemyKilledEvent(:final xpGained):
          _audio.play(SoundCue.enemyKilled);
          _labels.add(
            FloatLabel(
              text: '+$xpGained XP',
              worldPosition: world.player.position - const Offset(0, 40),
              bornAtMs: world.nowMs,
              color: accentColor.withValues(alpha: 0.85),
            ),
          );
        case ArmyMonsterLostEvent(:final type):
          _showToast('سقط ${MonsterCatalog.def(type).nameAr} — اشترِ بديلًا');
        case LevelUpEvent(:final newLevel, :final unlockedAbilityIds):
          _audio.play(SoundCue.levelUp);
          _showToast('المستوى $newLevel!');
          if (unlockedAbilityIds.isNotEmpty) {
            final names = unlockedAbilityIds
                .map((id) => kit.abilityById(id)?.nameAr ?? id)
                .join(' · ');
            _showToast('قدرة جديدة: $names');
          }
          _persistProgress();
        case PlayerDamagedEvent(:final amount):
          _audio.play(SoundCue.playerHit);
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
          _audio.play(SoundCue.playerDeath);
          _showToast('سقط البطل — عودة بعد لحظات');
          _persistProgress();
        case PlayerRespawnedEvent():
          _audio.play(SoundCue.respawn);
          _showToast('عدت إلى المعركة');
        case AbilityReadyEvent(:final abilityId):
          final name = kit.abilityById(abilityId)?.nameAr;
          if (name != null) _showToast('القدرة "$name" متاحة الآن');
        case MineCapturedEvent(:final size, :final ownerId):
          final label = switch (size) {
            MineSize.small => 'منجم صغير',
            MineSize.medium => 'منجم متوسط',
            MineSize.large => 'منجم كبير',
          };
          _showToast(
            ownerId == MineController.localPlayerId
                ? 'سيطرت على $label'
                : 'خصم سيطر على $label',
          );
        case MineResourceCollectedEvent(:final amount):
          _labels.add(
            FloatLabel(
              text: '+$amount موارد',
              worldPosition: world.player.position - const Offset(0, 30),
              bornAtMs: world.nowMs,
              color: const Color(0xFFFFD257),
            ),
          );
        case CrystalDestroyedEvent(:final ownerId, :final slot):
          // Required notification cue. There is deliberately no separate
          // warning when one of our crystals is merely attacked, and no cue
          // for mine captures (both forbidden by the specification).
          _audio.play(SoundCue.crystalDestroyed);
          _labels.add(
            FloatLabel(
              text: 'كريستال ${slot + 1} تحطم',
              worldPosition: world.player.position - const Offset(0, 46),
              bornAtMs: world.nowMs,
              color: ownerId == MineController.localPlayerId
                  ? const Color(0xFFFF8A80)
                  : const Color(0xFFFFD257),
            ),
          );
        case CastleFellEvent(:final ownerId):
          _showToast(
            ownerId == MineController.localPlayerId
                ? 'سقطت قلعتك — أعد بناء أول كريستال'
                : 'سقطت قلعة خصم',
          );
        case CrystalRebuiltEvent(:final cost):
          _audio.play(SoundCue.crystalRebuilt);
          _showToast('أُعيد بناء كريستال مقابل $cost موارد');
        case ChestOpenedEvent(:final item):
          _audio.play(SoundCue.chestOpened);
          final outcome = progression.addEquipment(item);
          _syncProgressionToWorld();
          if (outcome.isDuplicate) {
            _labels.add(
              FloatLabel(
                text: '+${outcome.materialGained} خامات معدات',
                worldPosition: world.player.position - const Offset(0, 36),
                bornAtMs: world.nowMs,
                color: Color(item.rarity.color),
              ),
            );
            _showToast(
              'معدات مكررة: ${item.rarity.nameAr} ${item.slot.nameAr} '
              '→ ${outcome.materialGained} خامات',
            );
          } else {
            _labels.add(
              FloatLabel(
                text: '${item.rarity.nameAr} ${item.slot.nameAr}',
                worldPosition: world.player.position - const Offset(0, 36),
                bornAtMs: world.nowMs,
                color: Color(item.rarity.color),
              ),
            );
            _showToast(
              'صندوق: ${item.rarity.nameAr} ${item.slot.nameAr} '
              '(المستوى ${item.cappedLevel})',
            );
          }
          _persistProgress();
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
    widget.onNetworkAttack?.call();
    _audio.play(SoundCue.attack);
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
    _audio.play(SoundCue.ability);
    _playClip(
      def.usesAttackClip ? 'attack' : 'skill',
      pace: world.currentAttackRate(),
    );
  }

  // ---- Sprite control ---------------------------------------------------------

  void _updateSprite(int deltaMs) {
    final m = manifest;
    if (m == null) return;
    final player = world.player;

    // In-game 3D hero path: drive the real model's pose from the same state
    // machine, with identical gameplay-event timing.
    final hero3d = _hero3d;
    if (hero3d != null) {
      final busy = _busyClip != null && !hero3d.completed;
      if (busy) {
        // The active non-loop clip keeps its own pace.
        hero3d.advance(world.nowMs, onEvent: _handleCombatEvent);
        return;
      }
      if (_busyClip != null) {
        _busyClip = null;
        _hitReactUntilMs = 0;
      }
      final desired = _desiredState();
      if (hero3d.clipState != desired) {
        _playClip(desired, pace: 1.0);
      }
      hero3d.advance(world.nowMs, onEvent: _handleCombatEvent);
      return;
    }

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
    if (player.disabledAt(world.nowMs)) return 'hit';
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

    // In-game 3D hero: pose the real model instead of the sprite atlas.
    final hero3d = _hero3d;
    if (hero3d != null) {
      final loop = _stateIsLooping(state);
      hero3d.playClip(
        state,
        loop: loop,
        pace: pace,
        nowMs: world.nowMs,
        events: Hero3DController.scheduleFor(m, state),
        durationMs: Hero3DController.durationFor(m, state),
      );
      _clipName = name;
      if (!loop) _busyClip = name;
      return;
    }

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

  /// Whether [state] loops, per the manifest's atlas clips (same timing as the
  /// GLB clips).
  bool _stateIsLooping(String state) {
    for (final clip in manifest?.clips.values ?? const <AnimationClip>[]) {
      if (clip.name.startsWith('${state}_')) return clip.loop;
    }
    return state == 'idle' || state == 'run' || state == 'walk';
  }

  void _handleSpriteEvent(AnimationEvent event) {
    _handleCombatEvent(event.name);
  }

  void _handleCombatEvent(String eventName) {
    switch (eventName) {
      case 'projectile_release':
      case 'melee_impact':
        if (world.pendingAbilityId == 'piercing_shot' ||
            world.pendingAbilityId == 'flame_slash' ||
            world.pendingAbilityId == 'twin_fangs' ||
            world.pendingAbilityId == 'thunder_thrust') {
          world.releaseWeaponPayload(volley: false);
        } else if (kit.attackStyle == AttackStyle.melee) {
          world.releaseMeleeSwing();
        } else {
          world.releaseArrow();
        }
      case 'volley_release':
      case 'inferno_burst':
      case 'shadow_burst':
      case 'storm_burst':
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => _onArenaTap(
                      details.localPosition,
                      constraints.biggest,
                    ),
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
                            hero3d: _hero3d,
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _armyPanel(theme),
                          const Spacer(),
                          _monsterUpgradeButton(theme),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _minePanel(theme),
                          const SizedBox(width: 6),
                          _castlePanel(theme),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Minimap (bottom center, clear of both control zones).
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(child: ArenaMinimap(world: world)),
              ),
            ),
            // Joystick zone — always opposite the attack cluster.
            Positioned(
              left: _settings.controlSide == ControlSide.right ? 0 : null,
              right: _settings.controlSide == ControlSide.left ? 0 : null,
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
                    scale: _settings.joystickScale,
                  ),
                ),
              ),
            ),
            // Controls — side and vertical offset follow the saved settings.
            Positioned(
              right: _settings.controlSide == ControlSide.right ? 16 : null,
              left: _settings.controlSide == ControlSide.left ? 16 : null,
              bottom: (24 + _settings.verticalOffset).clamp(
                8.0,
                MediaQuery.sizeOf(context).height - 80,
              ),
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
            // Build-mode hint.
            if (_placingCrystal)
              Positioned(
                top: 120,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _placingCrystal = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xDD000000),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF9BE845),
                        ),
                      ),
                      child: const Text(
                        'المس داخل أراضيك لبناء كريستال · اضغط هنا للإلغاء',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
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
    final hpRatio = (player.hp / world.maxHp).clamp(0.0, 1.0);
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
                '${player.hp.round()}/${world.maxHp.round()}',
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

  Widget _armyPanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: _panelDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'الجيش ${world.army.length}',
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          for (final type in MonsterType.values) ...[
            _buyMonsterButton(type),
            const SizedBox(width: 4),
          ],
          const SizedBox(width: 2),
          Text(
            'موارد ${world.resources} · جوهر ${world.essence + world.pendingEssence}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _onArenaTap(Offset local, Size size) {
    if (!_placingCrystal) return;
    final point = arenaToWorld(local, size, world);
    final result = world.rebuildCrystalAt(point);
    switch (result) {
      case CrystalRebuildResult.ok:
        setState(() => _placingCrystal = false);
      case CrystalRebuildResult.notEnoughResources:
        _showToast('الموارد غير كافية (${world.crystalRebuildCost})');
      case CrystalRebuildResult.atMax:
        _showToast('لديك سبعة كريستالات بالفعل');
      case CrystalRebuildResult.outsideTerritory:
        _showToast('ابنِ داخل أراضيك حول قلعتك');
      case CrystalRebuildResult.blocked:
        _showToast('المكان غير خالٍ — اختر أرضاً جافة مكشوفة');
    }
  }

  Widget _castlePanel(ThemeData theme) {
    final castle = world.playerCastle;
    final cost = world.crystalRebuildCost;
    final affordable = world.resources >= cost && castle.aliveCount < 7;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: _panelDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.castle, size: 14, color: Color(0xFF9BE845)),
          const SizedBox(width: 4),
          Text(
            castle.fallen
                ? 'قلعتك ساقطة'
                : 'قلعتك ${castle.aliveCount}/$castleCrystalCount',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            key: const ValueKey('rebuild_crystal'),
            onTap: affordable
                ? () => setState(() => _placingCrystal = !_placingCrystal)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _placingCrystal
                    ? const Color(0xFF9BE845)
                    : affordable
                        ? const Color(0x339BE845)
                        : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF9BE845)
                      .withValues(alpha: affordable ? 0.9 : 0.25),
                ),
              ),
              child: Text(
                _placingCrystal
                    ? 'اختر مكاناً…'
                    : 'كريستال بـ$cost',
                style: TextStyle(
                  color: _placingCrystal
                      ? const Color(0xFF10240F)
                      : affordable
                          ? const Color(0xFFD7FFC0)
                          : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _minePanel(ThemeData theme) {
    final mine = world.currentMine;
    final capacity = world.mineSystem.carryCapacity;
    final capturing = mine != null &&
        mine.capturerId == MineController.localPlayerId &&
        mine.captureProgressMs > 0;
    final owned = mine != null && mine.owns(MineController.localPlayerId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: _panelDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.terrain, size: 14, color: Color(0xFFFFD257)),
          const SizedBox(width: 4),
          Text(
            'مناجم ${world.ownedMineCount}/${world.map.mines.length}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Text(
            'حمل ${world.resources.clamp(0, capacity)}/$capacity',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          if (capturing) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: mine.captureFraction,
                  backgroundColor: const Color(0x22FFFFFF),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF9BE845)),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'سيطرة ${(mine.captureFraction * 100).round()}%',
              style: const TextStyle(color: Color(0xFF9BE845), fontSize: 10),
            ),
          ] else if (owned) ...[
            const SizedBox(width: 8),
            const Text(
              'منجمك',
              style: TextStyle(color: Color(0xFF9BE845), fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buyMonsterButton(MonsterType type) {
    final def = MonsterCatalog.def(type);
    final count = world.army.where((m) => m.type == type).length;
    final affordable = world.canBuyMonster(type);
    return GestureDetector(
      key: ValueKey('buy_${type.name}'),
      onTap: () => _onBuyMonster(type),
      child: Container(
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        decoration: BoxDecoration(
          color: affordable
              ? Color(def.color).withValues(alpha: 0.82)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Color(def.accent).withValues(alpha: affordable ? 0.9 : 0.25),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              def.nameAr,
              style: TextStyle(
                color: affordable ? Colors.white : Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$count · ${def.price}',
              style: TextStyle(
                color: affordable ? Colors.white70 : Colors.white38,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onBuyMonster(MonsterType type) {
    final def = MonsterCatalog.def(type);
    if (world.buyMonster(type)) {
      setState(() {});
      _showToast('انضم ${def.nameAr} إلى الجيش');
    } else if (world.army.length >= GameWorld.maxArmySize) {
      _showToast('الجيش وصل الحد الأقصى');
    } else {
      _showToast('الموارد غير كافية (${def.price})');
    }
  }

  Widget _monsterUpgradeButton(ThemeData theme) {
    return OutlinedButton.icon(
      key: const ValueKey('btn_monster_upgrades'),
      style: OutlinedButton.styleFrom(
        foregroundColor: accentColor,
        side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 30),
      ),
      onPressed: _showMonsterUpgrades,
      icon: const Icon(Icons.upgrade, size: 15),
      label: const Text('ترقية الوحوش', style: TextStyle(fontSize: 11)),
    );
  }

  Future<void> _showMonsterUpgrades() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('ترقية الوحوش — جوهر ${world.essence}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final type in MonsterType.values)
                      _monsterUpgradeRow(type, setDialogState),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('إغلاق'),
                ),
              ],
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  Widget _monsterUpgradeRow(
    MonsterType type,
    StateSetter setDialogState,
  ) {
    final def = MonsterCatalog.def(type);
    final level = world.upgrades.levelOf(type);
    final maxed = level >= MonsterUpgrades.maxLevel;
    final cost = world.upgrades.upgradeCost(type);
    final materialCost = world.monsterUpgradeMaterialCostFor(type);
    final materials =
        world.materials[ProgressionMaterial.monster] ?? 0;
    final affordable = world.essence >= cost && materials >= materialCost;
    final stats = MonsterStats.of(type, level);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${def.roleAr} · HP ${stats.maxHp.round()} · ضرر ${stats.damage.round()}',
                  style: const TextStyle(fontSize: 10),
                ),
                Text(
                  maxed
                      ? 'الأنسجة: $materials'
                      : 'الأنسجة: $materials/$materialCost',
                  style: TextStyle(
                    fontSize: 10,
                    color: maxed || materials >= materialCost
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: ValueKey('upgrade_${type.name}'),
            onPressed: maxed
                ? null
                : () {
                    if (world.upgradeMonster(type)) {
                      setDialogState(() {});
                      setState(() {});
                      _persistProgress();
                      _showToast(
                        '${def.nameAr} أصبح المستوى '
                        '${world.upgrades.levelOf(type)}',
                      );
                    } else {
                      _showToast(
                        'تحتاج $cost جوهر و$materialCost أنسجة وحوش '
                        '(لديك ${world.essence} و$materials)',
                      );
                    }
                  },
            child: Text(
              maxed ? 'الأقصى' : 'ترقية ($cost + $materialCost)',
              style: TextStyle(
                color: maxed || affordable ? null : Colors.orangeAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlCluster(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final ability in kit.abilities)
          _AbilityButton(
            def: ability,
            level: world.level,
            readyAtMs: world.abilityReadyAtMs[ability.id] ?? 0,
            nowMs: world.nowMs,
            energy: world.player.energy,
            accent: accentColor,
            scale: _settings.controlScale,
            onTap: () => _onAbilityTap(ability.id),
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
        width: 88 * _settings.controlScale,
        height: 88 * _settings.controlScale,
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
    this.scale = 1.0,
  });

  final AbilityDef def;
  final int level;
  final int readyAtMs;
  final int nowMs;
  final double energy;
  final Color accent;
  final VoidCallback onTap;
  final double scale;

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
          width: 52 * scale,
          height: 52 * scale,
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
    this.scale = 1.0,
  });

  final bool active;
  final Offset center;
  final Offset knob;
  final Color accent;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    canvas.drawCircle(
      center,
      56 * scale,
      Paint()
        ..color = accent.withValues(alpha: 0.14)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      56 * scale,
      Paint()
        ..color = accent.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(knob, 22 * scale,
        Paint()..color = accent.withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter old) =>
      old.active != active ||
      old.center != center ||
      old.knob != knob ||
      old.scale != scale;
}
