package com.archerfm.archer_fm

import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Best-effort audio playback for step 13.
 *
 * The WAV files are bundled as Flutter assets, so they live under
 * `flutter_assets/assets/audio/` in the APK's assets. Music uses one looping
 * [MediaPlayer] (swapped when the track changes); short cues use a [SoundPool]
 * so multiple impacts can overlap. Failures are logged and swallowed: audio is
 * never allowed to break gameplay.
 */
class MainActivity : FlutterActivity() {
  private var musicPlayer: MediaPlayer? = null
  private var soundPool: SoundPool? = null
  private val soundIds = mutableMapOf<String, Int>()
  private val loadedSounds = mutableSetOf<Int>()
  private var musicEnabled = true
  private var sfxEnabled = true

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      CHANNEL,
    ).setMethodCallHandler { call, result ->
      try {
        handle(call, result)
      } catch (e: Exception) {
        result.error("AUDIO_ERROR", e.message, null)
      }
    }
  }

  private fun handle(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "initialize" -> {
        ensureSoundPool()
        // Preload every cue so the first hit is never silent.
        CUE_ASSETS.forEach { loadCue(it) }
        result.success(null)
      }
      "setMusicEnabled" -> {
        musicEnabled = call.argument<Boolean>("enabled") ?: true
        if (!musicEnabled) stopMusic()
        result.success(null)
      }
      "setSfxEnabled" -> {
        sfxEnabled = call.argument<Boolean>("enabled") ?: true
        result.success(null)
      }
      "playMusic" -> {
        val asset = call.argument<String>("asset")
        if (musicEnabled && asset != null) playMusic(asset)
        result.success(null)
      }
      "stopMusic" -> {
        stopMusic()
        result.success(null)
      }
      "playSfx" -> {
        val asset = call.argument<String>("asset")
        if (sfxEnabled && asset != null) playSfx(asset)
        result.success(null)
      }
      "dispose" -> {
        releaseAudio()
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  private fun ensureSoundPool(): SoundPool {
    soundPool?.let { return it }
    val attributes = AudioAttributes.Builder()
      .setUsage(AudioAttributes.USAGE_GAME)
      .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
      .build()
    val pool = SoundPool.Builder()
      .setMaxStreams(8)
      .setAudioAttributes(attributes)
      .build()
    pool.setOnLoadCompleteListener { _, sampleId, status ->
      if (status == 0) loadedSounds.add(sampleId)
    }
    soundPool = pool
    return pool
  }

  private fun openAsset(path: String): AssetFileDescriptor? =
    try {
      assets.openFd("flutter_assets/$path")
    } catch (e: Exception) {
      null
    }

  private fun loadCue(asset: String) {
    if (soundIds.containsKey(asset)) return
    val fd = openAsset(asset) ?: return
    try {
      val id = ensureSoundPool().load(fd, 1)
      soundIds[asset] = id
    } finally {
      try {
        fd.close()
      } catch (_: Exception) {
      }
    }
  }

  private fun playSfx(asset: String) {
    val pool = ensureSoundPool()
    val id = soundIds[asset] ?: run {
      loadCue(asset)
      soundIds[asset]
    } ?: return
    if (!loadedSounds.contains(id)) return
    pool.play(id, 0.85f, 0.85f, 1, 0, 1f)
  }

  private fun playMusic(asset: String) {
    stopMusic()
    val fd = openAsset(asset) ?: return
    val player = MediaPlayer()
    try {
      player.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
      player.isLooping = true
      player.setVolume(0.6f, 0.6f)
      player.prepare()
      player.start()
      musicPlayer = player
    } catch (e: Exception) {
      try {
        player.release()
      } catch (_: Exception) {
      }
    } finally {
      try {
        fd.close()
      } catch (_: Exception) {
      }
    }
  }

  private fun stopMusic() {
    musicPlayer?.let { player ->
      try {
        player.stop()
      } catch (_: Exception) {
      }
      try {
        player.release()
      } catch (_: Exception) {
      }
    }
    musicPlayer = null
  }

  private fun releaseAudio() {
    stopMusic()
    soundPool?.release()
    soundPool = null
    soundIds.clear()
    loadedSounds.clear()
  }

  override fun onDestroy() {
    releaseAudio()
    super.onDestroy()
  }

  companion object {
    private const val CHANNEL = "archer_fm/audio"
    private val CUE_ASSETS = listOf(
      "assets/audio/sfx_attack.wav",
      "assets/audio/sfx_ability.wav",
      "assets/audio/sfx_hit.wav",
      "assets/audio/sfx_enemy_killed.wav",
      "assets/audio/sfx_death.wav",
      "assets/audio/sfx_respawn.wav",
      "assets/audio/sfx_level_up.wav",
      "assets/audio/sfx_crystal_destroyed.wav",
      "assets/audio/sfx_crystal_rebuilt.wav",
      "assets/audio/sfx_chest_open.wav",
      "assets/audio/sfx_ui_tap.wav",
    )
  }
}
