#!/usr/bin/env python3
"""Write a short mono 16 kHz 16-bit WAV containing a 440 Hz tone.

Usage: python3 scripts/make_sample_wav.py [out.wav] [seconds]

The tone contains no speech. Speech-to-text returns nothing for it, so the
server skips the LLM and TTS stages. Use it only to smoke-test the endpoint
and the measurement script. Timing a full turn needs a recording of real
speech.
"""
import math
import struct
import sys
import wave

out = sys.argv[1] if len(sys.argv) > 1 else "sample_tone.wav"
seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 2.0
rate = 16000

with wave.open(out, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(rate)
    frames = b"".join(
        struct.pack("<h", int(8000 * math.sin(2 * math.pi * 440 * i / rate)))
        for i in range(int(rate * seconds))
    )
    w.writeframes(frames)
print(f"wrote {out}")
