#!/usr/bin/env python3
"""Synthesises the ambience beds and footstep variants into audio/ambience and audio/sfx (22.05 kHz mono, 16-bit).
All beds are generated from circular (FFT-shaped) noise so they loop without a seam.   usage: python3 tools/assetgen/build_audio.py"""
import os, wave
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SR = 22050

def save(path, x, peak=0.8):
    x = np.asarray(x, float); x = x / max(np.abs(x).max(), 1e-9) * peak
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x * 32767).astype('<i2').tobytes())

def noise(n, lo, hi, slope=0.0, seed=0):
    rng = np.random.default_rng(seed); spec = np.fft.rfft(rng.standard_normal(n)); f = np.fft.rfftfreq(n, 1 / SR)
    edge = np.clip((f - lo) / max(lo * 0.3, 20.0), 0, 1) * np.clip((hi - f) / max(hi * 0.2, 50.0), 0, 1)
    x = np.fft.irfft(spec * edge * np.maximum(f, 1.0) ** slope, n); return x / (np.std(x) + 1e-9)

def add_circular(buf, snd, pos):
    idx = (pos + np.arange(len(snd))) % len(buf); buf[idx] += snd

def chirp(dur, f0, f1, vib=0.0, seed=0):
    t = np.arange(int(dur * SR)) / SR; ph = 2 * np.pi * (f0 * t + (f1 - f0) * t * t / (2 * dur) + vib * np.sin(2 * np.pi * 38 * t) / 38)
    env = np.sin(np.pi * t / dur) ** 2; return np.sin(ph) * env * (1 + 0.25 * np.sin(2 * ph))

def day_bed(seconds=24, seed=1):
    n = seconds * SR; t = np.arange(n) / n; r = np.random.default_rng(seed)
    gust = 0.55 + 0.45 * (0.5 * np.sin(2 * np.pi * 2 * t + 1.1) + 0.5 * np.sin(2 * np.pi * 3 * t + 2.3))
    wind = noise(n, 60, 900, -0.6, seed) * gust * 0.55 + noise(n, 1800, 6500, 0.0, seed + 1) * gust ** 2 * 0.10
    air = noise(n, 200, 2400, -1.0, seed + 2) * 0.06
    birds = np.zeros(n)
    for _ in range(14):
        species = r.integers(0, 3); pos = int(r.integers(0, n)); gap = [0.13, 0.09, 0.22][species]
        for k in range(int(r.integers(3, 7))):
            f0 = [3200, 4300, 2300][species] * r.uniform(0.9, 1.15); f1 = f0 * [1.25, 0.8, 1.1][species]
            add_circular(birds, chirp([0.09, 0.06, 0.16][species], f0, f1, vib=r.uniform(0, 80)) * r.uniform(0.5, 1.0), pos + int(k * gap * SR))
    return wind + air + birds * 0.16

def night_bed(seconds=24, seed=4):
    n = seconds * SR; t = np.arange(n) / SR; r = np.random.default_rng(seed)
    wind = noise(n, 50, 500, -0.8, seed) * (0.5 + 0.5 * np.sin(2 * np.pi * 2 * np.arange(n) / n + 0.4)) * 0.35
    crick = np.zeros(n)
    for f, rate, off, amp in ((4350, 29.0, 0.0, 1.0), (4700, 33.0, 0.17, 0.8), (3900, 26.0, 0.31, 0.6)):
        per = 0.46 + 0.04 * r.random(); burst = ((t + off) % per) < 0.14
        gate = np.convolve(burst.astype(float), np.hanning(180) / np.hanning(180).sum(), 'same') * (np.sin(2 * np.pi * rate * t) > -0.1)
        crick += np.sin(2 * np.pi * f * t) * gate * amp
    return wind + crick * 0.045

def river_bed(seconds=12, seed=7):
    n = seconds * SR; base = noise(n, 250, 3200, -0.5, seed); gur = np.abs(noise(n, 1, 14, 0.0, seed + 1)); gur = gur / gur.max()
    sparkle = noise(n, 3000, 8000, 0.0, seed + 2) * (np.abs(noise(n, 2, 40, 0.0, seed + 3)) ** 3) * 0.5
    return base * (0.55 + 0.45 * gur) + sparkle * 0.25

def rain_bed(seconds=12, seed=9):
    n = seconds * SR; r = np.random.default_rng(seed); x = noise(n, 1200, 9000, 0.1, seed) * 0.6 + noise(n, 80, 600, -0.5, seed + 1) * 0.15
    drops = np.zeros(n)
    for _ in range(int(seconds * 140)):
        d = np.exp(-np.arange(int(0.012 * SR)) / (0.0025 * SR)) * np.sin(2 * np.pi * r.uniform(2500, 7000) * np.arange(int(0.012 * SR)) / SR) * r.uniform(0.2, 1.0)
        add_circular(drops, d, int(r.integers(0, n)))
    return x + drops * 0.5

def footstep(seed, bright=1.0):
    n = int(0.28 * SR); t = np.arange(n) / SR; r = np.random.default_rng(seed)
    body = noise(n, 250, 2400 * bright, -0.3, seed) * np.exp(-t / 0.045) * np.clip(t / 0.003, 0, 1)
    thump = np.sin(2 * np.pi * (85 + 10 * r.random()) * t) * np.exp(-t / 0.05) * 0.8
    grit = noise(n, 3000, 7000, 0.0, seed + 5) * np.exp(-t / 0.02) * 0.25
    return body + thump + grit

def main():
    out = os.path.join(ROOT, 'audio')
    save(os.path.join(out, 'ambience', 'day_wind_birds.wav'), day_bed(), 0.85)
    save(os.path.join(out, 'ambience', 'night_crickets.wav'), night_bed(), 0.85)
    save(os.path.join(out, 'ambience', 'river.wav'), river_bed(), 0.85)
    save(os.path.join(out, 'ambience', 'rain.wav'), rain_bed(), 0.85)
    for i in range(3): save(os.path.join(out, 'sfx', f'footstep_grass_{i}.wav'), footstep(100 + i * 7, 0.9 + 0.1 * i), 0.8)
    total = sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(os.path.join(out, 'ambience')) for f in fs)
    print('audio done, ambience %.1f MB' % (total / 1e6))

if __name__ == '__main__': main()
