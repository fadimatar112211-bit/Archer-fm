import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Makes one [AudioService] available to every screen without global state.
/// Screens used outside the app (widget tests) fall back to silence, so no test
/// needs a native plugin just to pump a widget.
class AudioScope extends InheritedWidget {
  const AudioScope({
    super.key,
    required this.service,
    required super.child,
  });

  final AudioService service;

  static AudioService of(BuildContext context) {
    // No dependency registration: screens read the service once in initState,
    // and the service instance never changes during a run. Toggles are applied
    // by calling methods on it, not by replacing the inherited widget.
    final scope = context.getInheritedWidgetOfExactType<AudioScope>();
    return scope?.service ?? const NoOpAudioService();
  }

  @override
  bool updateShouldNotify(AudioScope oldWidget) => oldWidget.service != service;
}

/// Background music tracks used by step 13.
enum MusicTrack { menu, battle }

/// One-shot sound effects. The names describe the gameplay moment, not the
/// file, so callers never need to know the bundled asset paths.
///
/// Deliberately absent: a mine-capture alert and any warning when the player's
/// own crystals are attacked. The specification explicitly forbids both.
enum SoundCue {
  attack,
  ability,
  enemyHit,
  enemyKilled,
  playerHit,
  playerDeath,
  respawn,
  levelUp,
  crystalDestroyed,
  crystalRebuilt,
  chestOpened,
  uiTap,
}

const Map<MusicTrack, String> musicAssets = {
  MusicTrack.menu: 'assets/audio/menu_music.wav',
  MusicTrack.battle: 'assets/audio/battle_music.wav',
};

const Map<SoundCue, String> cueAssets = {
  SoundCue.attack: 'assets/audio/sfx_attack.wav',
  SoundCue.ability: 'assets/audio/sfx_ability.wav',
  SoundCue.enemyHit: 'assets/audio/sfx_hit.wav',
  SoundCue.enemyKilled: 'assets/audio/sfx_enemy_killed.wav',
  SoundCue.playerHit: 'assets/audio/sfx_hit.wav',
  SoundCue.playerDeath: 'assets/audio/sfx_death.wav',
  SoundCue.respawn: 'assets/audio/sfx_respawn.wav',
  SoundCue.levelUp: 'assets/audio/sfx_level_up.wav',
  SoundCue.crystalDestroyed: 'assets/audio/sfx_crystal_destroyed.wav',
  SoundCue.crystalRebuilt: 'assets/audio/sfx_crystal_rebuilt.wav',
  SoundCue.chestOpened: 'assets/audio/sfx_chest_open.wav',
  SoundCue.uiTap: 'assets/audio/sfx_ui_tap.wav',
};

/// Testable seam for all audio. Widget tests inject a fake; the running app
/// uses [MethodChannelAudioService]. Music is toggled by `musicEnabled` and
/// effects by `sfxEnabled`, independently, as required by the specification.
abstract class AudioService {
  const AudioService();

  Future<void> initialize();
  Future<void> setMusicEnabled(bool enabled);
  Future<void> setSfxEnabled(bool enabled);
  Future<void> playMusic(MusicTrack track);
  Future<void> stopMusic();
  Future<void> play(SoundCue cue);
  void dispose();
}

/// Silent implementation used when no audio is wanted (tests, unsupported
/// platforms). It keeps the toggle state so callers can still assert on it.
class NoOpAudioService extends AudioService {
  const NoOpAudioService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setMusicEnabled(bool enabled) async {}

  @override
  Future<void> setSfxEnabled(bool enabled) async {}

  @override
  Future<void> playMusic(MusicTrack track) async {}

  @override
  Future<void> stopMusic() async {}

  @override
  Future<void> play(SoundCue cue) async {}

  @override
  void dispose() {}
}

/// Records everything requested after the toggle filters. Useful for widget
/// tests that need to prove a cue was (or was not) played.
class RecordingAudioService extends AudioService {
  RecordingAudioService({this.musicEnabled = true, this.sfxEnabled = true});

  bool musicEnabled;
  bool sfxEnabled;
  bool initialized = false;
  bool musicPlaying = false;
  final List<MusicTrack> musicPlayed = [];
  final List<SoundCue> cuesPlayed = [];
  int stopCount = 0;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> setMusicEnabled(bool enabled) async {
    musicEnabled = enabled;
    if (!enabled) {
      musicPlaying = false;
    }
  }

  @override
  Future<void> setSfxEnabled(bool enabled) async {
    sfxEnabled = enabled;
  }

  @override
  Future<void> playMusic(MusicTrack track) async {
    if (!musicEnabled) return;
    musicPlaying = true;
    musicPlayed.add(track);
  }

  @override
  Future<void> stopMusic() async {
    musicPlaying = false;
    stopCount++;
  }

  @override
  Future<void> play(SoundCue cue) async {
    if (!sfxEnabled) return;
    cuesPlayed.add(cue);
  }

  @override
  void dispose() {
    musicPlaying = false;
  }
}

/// Real playback on Android. The Kotlin side loads the WAVs from the bundled
/// Flutter assets: one looping [MediaPlayer] for music, a [SoundPool] for cues.
///
/// Every call is best-effort. Unsupported platforms, missing plugins and
/// decoder failures must never break gameplay, so errors are swallowed here.
class MethodChannelAudioService extends AudioService {
  MethodChannelAudioService({this.channel = const MethodChannel(_channelName)});

  static const String _channelName = 'archer_fm/audio';

  final MethodChannel channel;
  bool _initialized = false;
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  MusicTrack? _currentTrack;

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await channel.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // Audio is optional; a device without a working decoder still plays.
    } on MissingPluginException {
      // Unit/widget tests and desktop hosts have no native implementation.
    }
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _invoke('initialize');
  }

  @override
  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    await _invoke('setMusicEnabled', {'enabled': enabled});
    if (!enabled) {
      await stopMusic();
    } else if (_currentTrack != null) {
      await playMusic(_currentTrack!);
    }
  }

  @override
  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    await _invoke('setSfxEnabled', {'enabled': enabled});
  }

  @override
  Future<void> playMusic(MusicTrack track) async {
    _currentTrack = track;
    if (!_musicEnabled) return;
    await _invoke('playMusic', {'asset': musicAssets[track]});
  }

  @override
  Future<void> stopMusic() async {
    await _invoke('stopMusic');
  }

  @override
  Future<void> play(SoundCue cue) async {
    if (!_sfxEnabled) return;
    await _invoke('playSfx', {'asset': cueAssets[cue]});
  }

  @override
  void dispose() {
    _currentTrack = null;
    // Fire-and-forget: dispose has no await in the AudioService contract.
    _invoke('dispose');
  }
}
