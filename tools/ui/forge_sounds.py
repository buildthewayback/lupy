#!/usr/bin/env python3
"""Forge LUPY'S OWN interface sounds — original synthesized cues, no donor audio.

White-label law (founder, 2026-10-22): Lupy ships Lupy assets only. The old
build copied Coucou's 29 sound files into Lupy. `SoundEngine` loads
`Resources/sounds/<name>.wav` for these 29 names (missing = silent), so this
forge generates a small original cue for every name it can ask for:
short sine-based tones with soft exponential decays — calm, quiet, neutral.
Relationships are musical (approval rises, finish resolves, error drops)
so the island can "speak" in tone the way it speaks in colour.

Outputs (committed): Mac/LupyAssets/sounds/<name>.wav  (22.05 kHz 16-bit mono)
Run: python3 tools/ui/forge_sounds.py   (from repo root)
"""
import math
import os
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "Mac/LupyAssets/sounds")
RATE = 22050

# SoundEngine.soundNames (Mac/Sources/App/SoundEngine.swift) — every name forged.
NAMES = ["peek", "open", "close", "hover", "blip", "slap", "annoyed", "dizzy",
         "greet", "work", "finish", "error", "approval", "question", "approve",
         "gulp", "tick", "send", "love", "pop", "proud", "wink", "yawn",
         "attach", "think", "search", "rate", "sleep", "greeting"]

# A cue = list of (start_s, dur_s, freq_from, freq_to, gain) sine partials.
# Frequencies around A4=440 with gentle harmonics; gains stay low (engine vol 0.12).
def cue(name):
    T = {  # two-note / shaped motifs first
        "approval": [(0.00, 0.16, 659, 659, .50), (0.13, 0.22, 880, 880, .50)],
        "question": [(0.00, 0.16, 587, 587, .45), (0.14, 0.24, 740, 784, .45)],
        "approve":  [(0.00, 0.12, 523, 523, .50), (0.09, 0.20, 784, 784, .50)],
        "finish":   [(0.00, 0.18, 523, 523, .45), (0.10, 0.20, 659, 659, .45), (0.20, 0.30, 784, 784, .50)],
        "error":    [(0.00, 0.22, 220, 196, .55), (0.05, 0.20, 233, 208, .35)],
        "rate":     [(0.00, 0.14, 392, 392, .45), (0.12, 0.20, 349, 330, .45)],
        "greet":    [(0.00, 0.14, 523, 523, .45), (0.11, 0.22, 659, 659, .45)],
        "greeting": [(0.00, 0.14, 523, 523, .40), (0.12, 0.14, 659, 659, .40), (0.24, 0.26, 784, 784, .45)],
        "send":     [(0.00, 0.14, 587, 880, .40)],
        "open":     [(0.00, 0.12, 440, 587, .35)],
        "close":    [(0.00, 0.12, 587, 440, .35)],
        "attach":   [(0.00, 0.07, 880, 880, .40), (0.06, 0.10, 1175, 1175, .35)],
        "love":     [(0.00, 0.16, 659, 659, .40), (0.12, 0.24, 880, 880, .40), (0.26, 0.16, 659, 659, .30)],
        "proud":    [(0.00, 0.12, 523, 523, .45), (0.10, 0.12, 659, 659, .45), (0.20, 0.28, 784, 784, .50)],
        "think":    [(0.00, 0.10, 494, 494, .30), (0.16, 0.10, 494, 494, .25)],
        "search":   [(0.00, 0.09, 740, 659, .30), (0.10, 0.09, 659, 587, .30), (0.20, 0.12, 587, 659, .30)],
        "work":     [(0.00, 0.08, 440, 440, .30), (0.09, 0.08, 440, 440, .25)],
        "sleep":    [(0.00, 0.40, 330, 262, .30)],
        "yawn":     [(0.00, 0.35, 392, 294, .30)],
        "dizzy":    [(0.00, 0.30, 523, 392, .30), (0.08, 0.30, 554, 415, .20)],
        "annoyed":  [(0.00, 0.10, 262, 262, .40), (0.11, 0.12, 247, 247, .40)],
        "gulp":     [(0.00, 0.12, 330, 220, .40)],
        "slap":     [(0.00, 0.05, 180, 90, .60)],
        "peek":     [(0.00, 0.08, 988, 1175, .30)],
        "wink":     [(0.00, 0.07, 1319, 1568, .30)],
        "hover":    [(0.00, 0.05, 1047, 1047, .18)],
        "tick":     [(0.00, 0.035, 1568, 1568, .25)],
        "blip":     [(0.00, 0.06, 880, 880, .35)],
        "pop":      [(0.00, 0.06, 523, 784, .45)],
    }
    return T.get(name, [(0.00, 0.08, 880, 880, .35)])


def synth(notes):
    total = max(s + d for s, d, *_ in notes) + 0.05
    n = int(total * RATE)
    buf = [0.0] * n
    for start, dur, f0, f1, gain in notes:
        i0, count = int(start * RATE), int(dur * RATE)
        for i in range(count):
            t = i / RATE
            k = i0 + i
            if k >= n:
                break
            f = f0 + (f1 - f0) * (i / max(1, count))
            env = math.exp(-3.2 * t / dur) * min(1.0, t / 0.008)  # soft attack, exp decay
            buf[k] += gain * env * (math.sin(2 * math.pi * f * t)
                                    + 0.25 * math.sin(4 * math.pi * f * t))
    peak = max(0.001, max(abs(v) for v in buf))
    scale = 0.85 / peak
    return b"".join(struct.pack("<h", int(max(-1, min(1, v * scale)) * 32767)) for v in buf)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    total = 0
    for name in NAMES:
        path = os.path.join(OUT_DIR, name + ".wav")
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(synth(cue(name)))
        total += os.path.getsize(path)
    print(f"forged {len(NAMES)} original sounds -> {OUT_DIR} ({total // 1024} KB total)")


if __name__ == "__main__":
    main()
