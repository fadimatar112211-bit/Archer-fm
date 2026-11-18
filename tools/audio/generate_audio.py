#!/usr/bin/env python3
"""Generate the small, deterministic WAV cues used by step 13.

No external packages: only the Python standard library. The files are short
16-bit mono clips at 22050 Hz, deliberately tiny so they can be bundled in the
APK without inflating it. Run from the repository root:

    python3 tools/audio/generate_audio.py

The generated files are checked in under assets/audio/ and declared in
pubspec.yaml. Regenerating them with the same script yields identical bytes.
"""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio"


def _clamp(v: float) -> float:
    return max(-1.0, min(1.0, v))


def _write(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        frames = bytearray()
        for s in samples:
            frames += struct.pack("<h", int(_clamp(s) * 32767))
        wav.writeframes(frames)
    print(f"{path.name}: {len(samples) / RATE:.2f}s")


def _tone(freq: float, t: float, phase: float = 0.0) -> float:
    return math.sin(2 * math.pi * freq * t + phase)


def _env(t: float, dur: float, attack: float = 0.01, release: float = 0.12) -> float:
    if t < attack:
        return t / attack if attack > 0 else 1.0
    if t > dur - release:
        return max(0.0, (dur - t) / release) if release > 0 else 1.0
    return 1.0


def _noise(seed: int) -> list[float]:
    """Deterministic pseudo-noise in [-1, 1]."""
    state = seed & 0xFFFFFFFF
    out: list[float] = []
    for _ in range(RATE):
        state = (1103515245 * state + 12345) & 0x7FFFFFFF
        out.append((state / 0x3FFFFFFF) - 1.0)
    return out


# ---- Music loops -------------------------------------------------------------

def menu_music() -> list[float]:
    """Calm 8 s arpeggio loop; soft sine pad, no percussion."""
    dur = 8.0
    notes = [220.0, 277.18, 329.63, 440.0, 329.63, 277.18, 246.94, 220.0]
    step = dur / len(notes)
    out: list[float] = []
    for i in range(int(RATE * dur)):
        t = i / RATE
        idx = int(t / step) % len(notes)
        local = t - int(t / step) * step
        f = notes[idx]
        v = 0.22 * math.sin(2 * math.pi * f * t)
        v += 0.09 * math.sin(2 * math.pi * f * 2 * t)
        v += 0.05 * math.sin(2 * math.pi * (f / 2) * t)
        v *= _env(local, step, 0.04, 0.18)
        # Gentle loop-level fade to avoid a click at the seam.
        v *= min(1.0, t / 0.05, (dur - t) / 0.05)
        out.append(v)
    return out


def battle_music() -> list[float]:
    """Driving 8 s loop with a simple pulse bass and off-beat hat."""
    dur = 8.0
    bpm = 120.0
    beat = 60.0 / bpm
    bass = [55.0, 55.0, 65.41, 55.0, 73.42, 55.0, 65.41, 49.0]
    hat = _noise(20261118)
    out: list[float] = []
    for i in range(int(RATE * dur)):
        t = i / RATE
        b = int(t / beat) % len(bass)
        local = t - int(t / beat) * beat
        f = bass[b]
        v = 0.20 * (_tone(f, t) + 0.35 * _tone(f * 2, t))
        v *= _env(local, beat, 0.005, 0.08)
        pulse_pos = (t % (beat / 2)) / (beat / 2)
        if pulse_pos < 0.06:
            v += 0.10 * _tone(880.0, t) * (1.0 - pulse_pos / 0.06)
        hpos = int((t + beat / 2) / beat) * beat + beat / 2
        hd = t - hpos
        if 0 <= hd < 0.03:
            v += 0.12 * hat[i % len(hat)] * (1.0 - hd / 0.03)
        v *= min(1.0, t / 0.05, (dur - t) / 0.05)
        out.append(v)
    return out


# ---- Effects ----------------------------------------------------------------

def sweep(f0: float, f1: float, dur: float, seed: int = 0, noise: float = 0.0) -> list[float]:
    n = _noise(seed) if noise else []
    out: list[float] = []
    phase = 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        p = t / dur
        f = f0 + (f1 - f0) * p
        phase += 2 * math.pi * f / RATE
        v = math.sin(phase) * _env(t, dur)
        if noise:
            v += noise * n[i] * _env(t, dur, 0.005, 0.08)
        out.append(v)
    return out


def chime(notes: list[float], dur: float, gap: float) -> list[float]:
    out: list[float] = []
    for f in notes:
        out.extend(sweep(f, f, dur, 0.0))
        out.extend([0.0] * int(RATE * gap))
    return out[: int(RATE * (dur + gap) * len(notes))]


def main() -> None:
    _write("menu_music", menu_music())
    _write("battle_music", battle_music())
    _write("sfx_attack", sweep(680.0, 210.0, 0.16, 11, 0.18))
    _write("sfx_ability", sweep(180.0, 720.0, 0.42, 12, 0.05))
    _write("sfx_hit", sweep(320.0, 90.0, 0.18, 13, 0.35))
    _write("sfx_enemy_killed", sweep(240.0, 70.0, 0.26, 14, 0.22))
    _write("sfx_death", sweep(300.0, 60.0, 0.75, 15))
    _write("sfx_respawn", sweep(140.0, 620.0, 0.55, 16))
    _write("sfx_level_up", chime([523.25, 659.25, 783.99], 0.16, 0.08))
    _write("sfx_crystal_destroyed", chime([880.0, 660.0, 440.0], 0.18, 0.05))
    _write("sfx_crystal_rebuilt", sweep(120.0, 260.0, 0.34, 17, 0.12))
    _write("sfx_chest_open", chime([659.25, 987.77, 1318.51], 0.14, 0.06))
    _write("sfx_ui_tap", sweep(520.0, 420.0, 0.07, 18))


if __name__ == "__main__":
    main()
