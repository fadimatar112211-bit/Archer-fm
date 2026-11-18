import 'package:archer_fm/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every declared music and cue asset is bundled and non-empty', () async {
    for (final asset in [...musicAssets.values, ...cueAssets.values]) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(44), reason: asset);
    }
  });

  test('spec-forbidden alerts have no cue at all', () {
    final names = SoundCue.values.map((cue) => cue.name).toList();
    expect(names, isNot(contains('mineCaptured')));
    expect(names, isNot(contains('crystalAttacked')));
    expect(names, isNot(contains('damageNumber')));
    // The required destruction notification is present, however.
    expect(names, contains('crystalDestroyed'));
  });

  test('recording service applies the two toggles independently', () async {
    final audio = RecordingAudioService(musicEnabled: false, sfxEnabled: false);
    await audio.initialize();
    expect(audio.initialized, isTrue);
    await audio.playMusic(MusicTrack.battle);
    await audio.play(SoundCue.attack);
    expect(audio.musicPlayed, isEmpty);
    expect(audio.cuesPlayed, isEmpty);

    await audio.setMusicEnabled(true);
    await audio.playMusic(MusicTrack.menu);
    expect(audio.musicPlayed, [MusicTrack.menu]);
    // SFX is still off: enabling music must not enable effects.
    await audio.play(SoundCue.ability);
    expect(audio.cuesPlayed, isEmpty);

    await audio.setSfxEnabled(true);
    await audio.play(SoundCue.ability);
    expect(audio.cuesPlayed, [SoundCue.ability]);
  });

  test('method channel service suppresses disabled playback', () async {
    const channel = MethodChannel('archer_fm/audio');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final audio = MethodChannelAudioService();
    await audio.initialize();
    await audio.playMusic(MusicTrack.menu);
    await audio.play(SoundCue.attack);
    expect(calls.map((call) => call.method), containsAll([
          'initialize',
          'playMusic',
          'playSfx',
        ]));

    await audio.setMusicEnabled(false);
    await audio.setSfxEnabled(false);
    calls.clear();
    await audio.playMusic(MusicTrack.battle);
    await audio.play(SoundCue.crystalDestroyed);
    expect(calls, isEmpty);

    // Re-enabling music restores the last selected track.
    await audio.setMusicEnabled(true);
    expect(calls.map((call) => call.method), contains('playMusic'));
  });
}
