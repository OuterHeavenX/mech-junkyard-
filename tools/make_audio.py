#!/usr/bin/env python3
"""Synthesize all Mech Junkyard SFX + ambient loop as 16-bit mono WAVs.
Run: python3 tools/make_audio.py
Output: assets/audio/*.wav (22050 Hz)
"""
import numpy as np
import os
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1337)


def save(name, x):
    x = np.clip(x, -1, 1)
    pcm = (x * 32767).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", path, "%.2fs" % (len(x) / SR))


def mix(*xs):
    """Sum signals of differing lengths (pad with zeros)."""
    n = max(len(x) for x in xs)
    y = np.zeros(n)
    for x in xs:
        y[:len(x)] += x
    return y


def env(n, attack=0.005, decay=None):
    e = np.ones(n)
    a = max(1, int(attack * SR))
    e[:a] = np.linspace(0, 1, a)
    d = n - a if decay is None else min(n - a, int(decay * SR))
    if d > 0:
        e[a:a + d] = np.linspace(1, 0, d) ** 1.6
        e[a + d:] = 0
    return e


def noise(n):
    return rng.standard_normal(n)


def lowpass(x, alpha):
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def thump(freq, dur, vol=0.9, slide_to=None):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = np.linspace(freq, slide_to or freq * 0.5, n)
    ph = np.cumsum(2 * np.pi * f / SR)
    return np.sin(ph) * env(n) * vol


def burst(dur, cutoff_alpha, vol=0.8, slide_alpha=None):
    n = int(dur * SR)
    x = noise(n)
    if slide_alpha:
        # crude sweeping lowpass via two-stage alpha
        y = np.zeros(n)
        acc = 0.0
        for i in range(n):
            a = cutoff_alpha + (slide_alpha - cutoff_alpha) * i / n
            acc += a * (x[i] - acc)
            y[i] = acc
        x = y
    else:
        x = lowpass(x, cutoff_alpha)
    return x * env(n) * vol


# --- impacts ---
save("punch", mix(burst(0.14, 0.35, 0.85), thump(110, 0.14, 0.7, 60)))
save("heavy_slam", mix(burst(0.35, 0.22, 0.9, 0.06), thump(70, 0.4, 1.0, 38)))
save("spark_zap", mix(burst(0.1, 0.8, 0.5),
     np.sin(2 * np.pi * 2400 * np.arange(int(0.1 * SR)) / SR) * env(int(0.1 * SR)) * 0.3))
n = int(0.4 * SR)
t = np.arange(n) / SR
saw = (np.sign(np.sin(2 * np.pi * 170 * t)) * 0.35 +
       np.sign(np.sin(2 * np.pi * 340 * t)) * 0.2 + noise(n) * 0.25) * env(n, decay=0.3)
save("saw", saw)
save("cannon", mix(burst(0.5, 0.3, 1.0, 0.05), thump(90, 0.5, 0.9, 40)))
save("explosion", mix(burst(0.8, 0.25, 1.0, 0.04), thump(55, 0.8, 1.0, 30)))
save("player_hurt", mix(burst(0.2, 0.3, 0.8), thump(95, 0.22, 0.8, 50)))
save("arm_rip", mix(burst(0.45, 0.6, 0.7, 0.15),
     np.sin(np.cumsum(2 * np.pi * np.linspace(900, 180, int(0.45 * SR)) / SR)) *
            env(int(0.45 * SR)) * 0.35))

# --- pickups / UI ---
def metallic(partials, dur, vol=0.6):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f, a in partials:
        x += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28))
    return x * env(n, decay=dur * 0.85) * vol

save("pickup_clank", metallic([(810, 0.5), (1243, 0.35), (2093, 0.25), (3180, 0.12)], 0.35))
save("scrap_tick", metallic([(2100, 0.5), (3150, 0.2)], 0.08, 0.4))
save("ui_click", np.sin(2 * np.pi * 1250 * np.arange(int(0.05 * SR)) / SR) *
     env(int(0.05 * SR)) * 0.5)
save("shop_buy", mix(metallic([(810, 0.5), (1243, 0.35)], 0.25, 0.5),
     metallic([(660, 0.4), (880, 0.4)], 0.4, 0.4)))
save("heal", metallic([(660, 0.4), (880, 0.4), (1320, 0.25)], 0.5, 0.5))
save("wave_horn", (np.sign(np.sin(2 * np.pi * 110 *
     np.arange(int(0.7 * SR)) / SR)) * 0.3 +
     np.sign(np.sin(2 * np.pi * 165 * np.arange(int(0.7 * SR)) / SR)) * 0.25) *
     env(int(0.7 * SR), attack=0.08, decay=0.55))

# --- movement ---
n = int(0.13 * SR)
t = np.arange(n) / SR
save("jump", np.sin(np.cumsum(2 * np.pi * np.linspace(280, 620, n) / SR)) *
     env(n) * 0.45)
save("dash", lowpass(noise(int(0.2 * SR)), 0.5) *
     env(int(0.2 * SR), attack=0.02, decay=0.16) * 0.6)
n = int(0.12 * SR)
save("land", lowpass(noise(n), 0.25) * env(n) * 0.4)

# --- ambient loop: 26 s industrial rumble, crossfaded to loop seamlessly ---
DUR = 26.0
n = int(DUR * SR)
t = np.arange(n) / SR
brown = np.cumsum(noise(n))
brown = brown / np.max(np.abs(brown))
rumble = lowpass(brown, 0.02) * 0.5
hum = np.sin(2 * np.pi * 55 * t) * 0.06 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.1 * t))
wind = lowpass(noise(n), 0.06) * 0.10 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.07 * t + 1))
amb = rumble + hum + wind
# distant metallic clangs at random times (keep 1.5 s clear of loop edges)
for _ in range(9):
    at = rng.uniform(1.5, DUR - 2.5)
    i0 = int(at * SR)
    clang = metallic([(rng.uniform(400, 900), 0.5),
                      (rng.uniform(1100, 2400), 0.3)], 1.6, 0.12)
    m = min(len(clang), n - i0)
    amb[i0:i0 + m] += clang[:m]
# slow pulsing furnace roar
amb += lowpass(noise(n), 0.03) * 0.08 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.05 * t))
# crossfade last 2 s into first 2 s for a click-free loop
X = int(2.0 * SR)
fade = np.linspace(0, 1, X)
amb[:X] = amb[:X] * fade + amb[-X:] * (1 - fade)
amb = amb[:-X]
amb = amb / max(1e-6, np.max(np.abs(amb))) * 0.5
save("ambient_loop", amb)
print("done")
