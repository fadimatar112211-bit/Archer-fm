import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Offset;

import 'package:archer_fm/hero/hero_manifest.dart';

import 'hero3d_painter.dart';

/// Drives the in-game 3D hero: clip sequencing, gameplay-event timing and
/// per-frame posing.
///
/// The event schedule is lifted from the hero manifest's atlas clips (which
/// were rendered from the very same GLB clips), so combat timing stays
/// identical whether the hero draws through the sprite path or this one.
class Hero3DController {
  Hero3DController(this.model);

  final Hero3DModel model;

  String? _clipState;
  bool _looping = true;
  double _pace = 1.0;
  int _startWorldMs = 0;
  bool _completed = false;

  /// Scheduled events of the active clip, in clip-local milliseconds.
  List<MapEntry<double, String>> _schedule = const [];
  int _firedCount = 0;

  /// Gameplay (manifest) duration of the active clip; 0 = GLB duration.
  double _gameDurationMs = 0;

  /// True once the current non-looping clip has played out.
  bool get completed => _completed;

  String? get clipState => _clipState;

  /// Clip-local playback duration (ms) at pace 1.
  double get clipDurationMs =>
      model.model.clips[_clipState]?.durationMs ?? 1000;

  /// Builds the event schedule for [state] from the manifest (any direction
  /// variant shares the timing).
  static List<MapEntry<double, String>> scheduleFor(
    HeroManifest? manifest,
    String state,
  ) {
    if (manifest == null) return const [];
    for (final clip in manifest.clips.values) {
      if (!clip.name.startsWith('${state}_')) continue;
      return clip.events
          .map(
            (e) => MapEntry(
              e.frame * clip.frameDurationMs.toDouble(),
              e.name,
            ),
          )
          .toList(growable: false);
    }
    return const [];
  }

  /// Atlas-clip duration (ms) for [state]; 0 when the manifest has no clip
  /// for it (the GLB's own duration is used then).
  static double durationFor(HeroManifest? manifest, String state) {
    if (manifest == null) return 0;
    for (final clip in manifest.clips.values) {
      if (!clip.name.startsWith('${state}_')) continue;
      return clip.frameDurationMs * clip.frames.length.toDouble();
    }
    return 0;
  }

  /// Starts [state] (idle/run/attack/...) at [nowMs].
  ///
  /// [durationMs] is the gameplay timing (manifest atlas duration). When the
  /// GLB clip runs at a different length, the pose is rescaled so the
  /// animation finishes exactly when the gameplay clip does.
  void playClip(
    String state, {
    required bool loop,
    required double pace,
    required int nowMs,
    required List<MapEntry<double, String>> events,
    double durationMs = 0,
  }) {
    if (!_looping || _clipState != state) {
      // Restarting or switching: reset the clock.
      _startWorldMs = nowMs;
      _firedCount = 0;
    }
    _clipState = state;
    _looping = loop;
    _pace = pace;
    _completed = false;
    _schedule = events;
    _gameDurationMs = durationMs;
  }

  /// Poses + skins the model for [nowMs] and fires crossed events.
  void advance(
    int nowMs, {
    required void Function(String eventName) onEvent,
  }) {
    final state = _clipState;
    if (state == null) return;
    final clip = model.model.clips[state];
    final localMs =
        math.max(0.0, (nowMs - _startWorldMs) * _pace);

    while (_firedCount < _schedule.length &&
        _schedule[_firedCount].key <= localMs) {
      onEvent(_schedule[_firedCount].value);
      _firedCount++;
    }

    if (clip == null) {
      _completed = true;
      return;
    }
    // Rescale the GLB clip so it finishes exactly when the gameplay clip
    // (manifest timing) does.
    final gameMs =
        _gameDurationMs > 0 ? _gameDurationMs : clip.durationMs;
    final poseMs = (gameMs > 0)
        ? localMs * clip.durationMs / gameMs
        : localMs;
    if (_looping) {
      model.pose(state, poseMs % clip.durationMs, loop: true);
    } else if (localMs >= gameMs) {
      model.pose(state, clip.durationMs, loop: false);
      _completed = true;
    } else {
      model.pose(state, poseMs, loop: false);
    }
    model.skin();
  }

  /// Draws the posed hero with the arena's gameplay-facing conventions:
  /// [facing] is the 2D arena direction; the model turns to match it and its
  /// feet sit on the anchor.
  void paint(
    Canvas canvas, {
    required Offset anchor,
    required Offset facing,
    required double scale,
    double alpha = 1,
    Color? tint,
  }) {
    final yaw = math.atan2(facing.dx, facing.dy);
    model.paint(
      canvas,
      anchor: anchor,
      yaw: yaw,
      scale: scale,
      alphaParam: alpha,
      tint: tint,
    );
  }

  /// Convenience: scale for a target on-screen height in arena units.
  double scaleForPixelHeight(double pixelHeight) =>
      model.scaleForPixelHeight(pixelHeight);
}
