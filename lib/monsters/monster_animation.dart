import 'monster_models.dart';

/// Visual state selected from authoritative monster simulation state.
enum MonsterAnimationState { idle, walk, attack, death }

/// Immutable sprite-sheet layout for one monster animation.
class MonsterSpriteSheet {
  const MonsterSpriteSheet({
    required this.asset,
    required this.frameWidth,
    required this.frameHeight,
    required this.frameCount,
    this.frameDuration = const Duration(milliseconds: 110),
    this.loop = true,
  })  : assert(frameWidth > 0),
        assert(frameHeight > 0),
        assert(frameCount > 0),
        assert(frameDuration != Duration.zero);

  final String asset;
  final int frameWidth;
  final int frameHeight;
  final int frameCount;
  final Duration frameDuration;
  final bool loop;

  int get sheetWidth => frameWidth * frameCount;
}

/// Owns the animation clock for one monster; it never changes world position.
/// The game renderer reads [frameIndex] and crops the corresponding cell from
/// [sheet]. Movement remains authoritative in MonsterUnit/formation systems.
class MonsterAnimationController {
  MonsterAnimationController({
    required this.type,
    required this.walkSheet,
    this.attackSheet,
    this.deathSheet,
    this.idleFrame = 0,
  }) : _frameIndex = idleFrame {
    _validateSheet(walkSheet, 'walkSheet');
    if (attackSheet != null) _validateSheet(attackSheet, 'attackSheet');
    if (deathSheet != null) _validateSheet(deathSheet, 'deathSheet');
    if (idleFrame < 0 || idleFrame >= walkSheet.frameCount) {
      throw RangeError.range(idleFrame, 0, walkSheet.frameCount - 1, 'idleFrame');
    }
  }

  final MonsterType type;
  final MonsterSpriteSheet walkSheet;
  final MonsterSpriteSheet? attackSheet;
  final MonsterSpriteSheet? deathSheet;
  final int idleFrame;

  MonsterAnimationState _state = MonsterAnimationState.idle;
  int _frameIndex;
  Duration _elapsed = Duration.zero;
  bool _dead = false;

  MonsterAnimationState get state => _state;
  int get frameIndex => _frameIndex;
  Duration get elapsedInFrame => _elapsed;
  bool get isComplete => _state == MonsterAnimationState.death &&
      _frameIndex == _activeSheet.frameCount - 1;

  MonsterSpriteSheet get _activeSheet {
    switch (_state) {
      case MonsterAnimationState.attack:
        return attackSheet ?? walkSheet;
      case MonsterAnimationState.death:
        return deathSheet ?? walkSheet;
      case MonsterAnimationState.idle:
      case MonsterAnimationState.walk:
        return walkSheet;
    }
  }

  /// Selects the highest-priority visual state without changing simulation.
  /// Death is terminal; an attack sheet is used only when one exists.
  void synchronize({required bool alive, required bool moving, bool attacking = false}) {
    if (_dead) return;
    if (!alive) {
      _dead = true;
      _switchTo(MonsterAnimationState.death);
    } else if (attacking && attackSheet != null) {
      _switchTo(MonsterAnimationState.attack);
    } else if (moving) {
      _switchTo(MonsterAnimationState.walk);
    } else {
      _switchTo(MonsterAnimationState.idle);
    }
  }

  /// Advances animation by elapsed simulation time, preserving excess time.
  /// Large frame deltas are reduced arithmetically to avoid unbounded loops.
  void advance(Duration delta) {
    if (delta.isNegative) throw ArgumentError.value(delta, 'delta');
    if (delta == Duration.zero || isComplete ||
        _state == MonsterAnimationState.idle) return;
    final sheet = _activeSheet;
    final frameUs = sheet.frameDuration.inMicroseconds;
    final totalUs = _elapsed.inMicroseconds + delta.inMicroseconds;
    final steps = totalUs ~/ frameUs;
    _elapsed = Duration(microseconds: totalUs % frameUs);
    if (steps == 0) return;

    final next = _frameIndex + steps;
    if (sheet.loop && _state != MonsterAnimationState.death) {
      _frameIndex = next % sheet.frameCount;
    } else {
      _frameIndex = next.clamp(0, sheet.frameCount - 1);
    }
  }

  void _validateSheet(MonsterSpriteSheet sheet, String name) {
    if (sheet.asset.isEmpty || sheet.frameWidth <= 0 ||
        sheet.frameHeight <= 0 || sheet.frameCount <= 0 ||
        sheet.frameDuration <= Duration.zero) {
      throw ArgumentError.value(sheet, name, 'Invalid sprite sheet metadata.');
    }
  }

  void _switchTo(MonsterAnimationState next) {
    if (_state == next) return;
    _state = next;
    _frameIndex = next == MonsterAnimationState.idle ? idleFrame : 0;
    _elapsed = Duration.zero;
  }
}
