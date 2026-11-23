import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:archer_fm/hero/sprite_player.dart';
import 'package:flutter_test/flutter_test.dart';

AnimationClip _clip({bool loop = false, int duration = 100}) {
  return AnimationClip(
    name: 'test',
    loop: loop,
    frameDurationMs: duration,
    frames: const ['f0', 'f1', 'f2'],
    events: const [
      AnimationEvent(frame: 0, name: 'start'),
      AnimationEvent(frame: 1, name: 'mid'),
    ],
  );
}

void main() {
  test('a non-looping clip stops on its last frame', () {
    final player = SpritePlayer(clip: _clip());
    player.advance(250);
    expect(player.frameIndex, 2);
    expect(player.playing, isTrue);
    expect(player.completed, isFalse);
    player.advance(50);
    expect(player.completed, isTrue);
    expect(player.playing, isFalse);
    expect(player.frameIndex, 2);
  });

  test('a looping clip wraps and re-emits frame-zero events', () {
    final events = <String>[];
    final player = SpritePlayer(
      clip: _clip(loop: true),
      onEvent: (event) => events.add(event.name),
    );
    expect(events, ['start']);
    player.advance(150);
    expect(player.frameIndex, 1);
    expect(events, ['start', 'mid']);
    player.advance(200);
    expect(player.frameIndex, 0);
    expect(events, ['start', 'mid', 'start']);
    expect(player.completed, isFalse);
  });

  test('pausing freezes the clip and playing resumes it', () {
    final player = SpritePlayer(clip: _clip(loop: true));
    player.pause();
    player.advance(500);
    expect(player.frameIndex, 0);
    expect(player.playing, isFalse);
    player.play();
    player.advance(100);
    expect(player.frameIndex, 1);
  });

  test('restart returns to the first frame and fires its event', () {
    final events = <String>[];
    final player = SpritePlayer(
      clip: _clip(loop: true),
      onEvent: (event) => events.add(event.name),
    );
    player.advance(250);
    events.clear();
    player.restart();
    expect(player.frameIndex, 0);
    expect(player.playing, isTrue);
    expect(events, ['start']);
  });

  test('a large delta fires one-shot gameplay events once and stops', () {
    final events = <String>[];
    final player = SpritePlayer(
      clip: _clip(),
      onEvent: (event) => events.add(event.name),
    );

    // Constructor enters frame zero. A delayed render tick may cross all
    // remaining frames, but must not repeat the impact event or loop the clip.
    expect(events, ['start']);
    player.advance(1000);

    expect(player.frameIndex, 2);
    expect(player.completed, isTrue);
    expect(player.playing, isFalse);
    expect(events, ['start', 'mid']);
    player.advance(1000);
    expect(events, ['start', 'mid']);
  });

  test('seek clamps to the clip length', () {
    final player = SpritePlayer(clip: _clip(loop: true));
    player.seek(99);
    expect(player.frameIndex, 2);
    player.seek(-4);
    expect(player.frameIndex, 0);
  });
}
