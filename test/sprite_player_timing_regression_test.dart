import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:archer_fm/hero/sprite_player.dart';
import 'package:flutter_test/flutter_test.dart';

AnimationClip _clip({
  required String name,
  required bool loop,
  int duration = 100,
  List<AnimationEvent> events = const [],
}) =>
    AnimationClip(
      name: name,
      loop: loop,
      frameDurationMs: duration,
      frames: const ['f0', 'f1', 'f2'],
      events: events,
    );

void main() {
  test('sub-frame elapsed time is carried across render ticks', () {
    final player = SpritePlayer(
      clip: _clip(name: 'walk', loop: true, duration: 80),
    );

    player.advance(30);
    expect(player.frameIndex, 0);
    expect(player.elapsedMs, 30);

    player.advance(49);
    expect(player.frameIndex, 0);
    expect(player.elapsedMs, 79);

    player.advance(1);
    expect(player.frameIndex, 1);
    expect(player.elapsedMs, 0);
  });

  test('large looping delta preserves remainder and emits each entered event', () {
    final events = <String>[];
    final player = SpritePlayer(
      clip: _clip(
        name: 'walk',
        loop: true,
        duration: 50,
        events: const [
          AnimationEvent(frame: 0, name: 'loop_start'),
          AnimationEvent(frame: 2, name: 'footfall'),
        ],
      ),
      onEvent: (event) => events.add(event.name),
    );

    player.advance(275);

    expect(player.frameIndex, 2);
    expect(player.elapsedMs, 25);
    expect(events, ['loop_start', 'footfall', 'loop_start', 'footfall']);
    expect(player.completed, isFalse);
  });

  test('changing clips resets frame clock and enters the new clip once', () {
    final events = <String>[];
    final walk = _clip(name: 'walk', loop: true);
    final attack = _clip(
      name: 'attack',
      loop: false,
      events: const [AnimationEvent(frame: 0, name: 'attack_start')],
    );
    final player = SpritePlayer(
      clip: walk,
      onEvent: (event) => events.add(event.name),
    );

    player.advance(65);
    player.setClip(attack);

    expect(player.clip.name, 'attack');
    expect(player.frameIndex, 0);
    expect(player.elapsedMs, 0);
    expect(player.completed, isFalse);
    expect(events, ['attack_start']);
  });

  test('non-looping clip cannot restart or re-emit events after completion', () {
    final events = <String>[];
    final player = SpritePlayer(
      clip: _clip(
        name: 'death',
        loop: false,
        duration: 40,
        events: const [
          AnimationEvent(frame: 0, name: 'death_start'),
          AnimationEvent(frame: 2, name: 'death_final_pose'),
        ],
      ),
      onEvent: (event) => events.add(event.name),
    );

    player.advance(500);
    player.advance(500);

    expect(player.frameIndex, 2);
    expect(player.completed, isTrue);
    expect(player.playing, isFalse);
    expect(events, ['death_start', 'death_final_pose']);
  });
}
