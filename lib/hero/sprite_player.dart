import 'package:flutter/foundation.dart';

import 'hero_manifest.dart';

typedef SpriteEventCallback = void Function(AnimationEvent event);

/// Drives one animation clip with an explicit delta clock.
///
/// The player owns no ticker so it can be tested without a widget tree: the
/// screen feeds it elapsed milliseconds and the player emits gameplay events as
/// frames are entered.
class SpritePlayer extends ChangeNotifier {
  SpritePlayer({required AnimationClip clip, this.onEvent}) : _clip = clip {
    _restart();
  }

  AnimationClip _clip;
  final SpriteEventCallback? onEvent;

  int _frameIndex = 0;
  int _elapsedMs = 0;
  bool _playing = true;
  bool _completed = false;

  AnimationClip get clip => _clip;
  int get frameIndex => _frameIndex;
  int get elapsedMs => _elapsedMs;
  bool get playing => _playing;
  bool get completed => _completed;
  String get frameId => _clip.frames[_frameIndex];

  void setClip(AnimationClip clip) {
    _clip = clip;
    _restart();
    notifyListeners();
  }

  void play() {
    if (_completed) {
      _restart();
    }
    if (!_playing) {
      _playing = true;
      notifyListeners();
    }
  }

  void pause() {
    if (_playing) {
      _playing = false;
      notifyListeners();
    }
  }

  void toggle() => _playing ? pause() : play();

  void restart() {
    _restart();
    _playing = true;
    notifyListeners();
  }

  void seek(int index) {
    final clamped = index.clamp(0, _clip.frames.length - 1);
    if (clamped == _frameIndex) return;
    _frameIndex = clamped;
    _elapsedMs = 0;
    _completed = false;
    notifyListeners();
  }

  /// Advance the clip by [deltaMs] of playback time.
  void advance(int deltaMs) {
    if (!_playing || _completed || deltaMs <= 0) return;
    var remaining = deltaMs;
    var changed = false;
    while (remaining > 0 && !_completed) {
      final untilNext = _clip.frameDurationMs - _elapsedMs;
      if (remaining < untilNext) {
        _elapsedMs += remaining;
        remaining = 0;
      } else {
        remaining -= untilNext;
        _elapsedMs = 0;
        _stepFrame();
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void _stepFrame() {
    if (_frameIndex + 1 < _clip.frames.length) {
      _frameIndex++;
      _fireEventsFor(_frameIndex);
    } else if (_clip.loop) {
      _frameIndex = 0;
      _fireEventsFor(0);
    } else {
      _completed = true;
      _playing = false;
    }
  }

  void _restart() {
    _frameIndex = 0;
    _elapsedMs = 0;
    _completed = false;
    _fireEventsFor(0);
  }

  void _fireEventsFor(int index) {
    for (final event in _clip.events) {
      if (event.frame == index) onEvent?.call(event);
    }
  }
}
