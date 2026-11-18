# Audio (Step 13)

This project bundles small deterministic WAV clips and plays them through a
testable Dart seam. No external audio package is used.

## Architecture

- `lib/audio_service.dart` defines `AudioService`, `AudioScope`,
  `NoOpAudioService`, `RecordingAudioService` and `MethodChannelAudioService`.
- `main.dart` creates the `MethodChannelAudioService`, initializes it, applies
  the saved music/SFX toggles, and wraps the app in `AudioScope`.
- Android `MainActivity.kt` implements channel `archer_fm/audio` with one
  looping `MediaPlayer` for music and a `SoundPool` for overlapping cues.
- Every call is best-effort. Missing plugins, unsupported platforms and decoder
  failures are swallowed; they never interrupt gameplay.

## Tracks

| Track | Asset | Played |
|---|---|---|
| `MusicTrack.menu` | `assets/audio/menu_music.wav` | Main menu (`home_screen.dart`) |
| `MusicTrack.battle` | `assets/audio/battle_music.wav` | Battle (`game_screen.dart`), stopped on dispose |

## Cue mapping

| `SoundCue` | Asset | Trigger |
|---|---|---|
| `attack` | `sfx_attack.wav` | Accepted manual attack |
| `ability` | `sfx_ability.wav` | Accepted ability |
| `enemyHit` | `sfx_hit.wav` | Reserved (shared hit clip) |
| `enemyKilled` | `sfx_enemy_killed.wav` | `EnemyKilledEvent` |
| `playerHit` | `sfx_hit.wav` | `PlayerDamagedEvent` |
| `playerDeath` | `sfx_death.wav` | `PlayerDiedEvent` |
| `respawn` | `sfx_respawn.wav` | `PlayerRespawnedEvent` |
| `levelUp` | `sfx_level_up.wav` | `LevelUpEvent` |
| `crystalDestroyed` | `sfx_crystal_destroyed.wav` | `CrystalDestroyedEvent` (required notification) |
| `crystalRebuilt` | `sfx_crystal_rebuilt.wav` | `CrystalRebuiltEvent` |
| `chestOpened` | `sfx_chest_open.wav` | `ChestOpenedEvent` |
| `uiTap` | `sfx_ui_tap.wav` | Menu navigation and SFX re-enable |

**Deliberately absent:** any cue for mine capture or for our own crystals being
attacked (both forbidden by the specification), and any damage-number or
last-minute effect.

## Toggles

`GameSettings` stores `musicEnabled` and `sfxEnabled` independently, persisted
by `SettingsStore` alongside the control settings. The settings screen switches
call `AudioService.setMusicEnabled` / `setSfxEnabled` immediately. Music
changes stop the current track or replay the last selected one; SFX changes
only affect one-shot cues.

## Regenerating assets

```sh
python3 tools/audio/generate_audio.py
```

The generator uses only the Python standard library and is deterministic.
The output is declared under `assets/audio/` in `pubspec.yaml` (~920 KB total).
