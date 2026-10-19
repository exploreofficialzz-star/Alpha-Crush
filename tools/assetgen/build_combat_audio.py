#!/usr/bin/env python3
"""Procedural audio for the combat edition: gunshots, kung-fu hits, explosions, crush moves, pick-ups, stingers, three music
loops and a war-rumble ambience bed. Everything is synthesised with numpy/scipy (no samples, no licences): noise bursts and
pitch-swept sines shaped by exponential envelopes, plus a tiny step sequencer for the music.
Output: 22.05 kHz mono 16-bit WAV in audio/sfx, audio/music and audio/ambience. Deterministic (fixed seeds).
Run:  python3 tools/assetgen/build_combat_audio.py"""
import os
import wave

import numpy as np
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SR = 22050
RNG = np.random.default_rng(20261017)


# ------------------------------------------------------------------------------------------------ building blocks
def tt(d):
    return np.arange(int(SR * d)) / SR


def noise(d):
    return RNG.uniform(-1.0, 1.0, int(SR * d))


def _filt(x, kind, hz, order=2):
    nyq = SR / 2.0
    hz = [min(max(h, 20.0), nyq - 200.0) for h in (hz if isinstance(hz, (list, tuple)) else [hz])]
    b, a = signal.butter(order, [h / nyq for h in hz] if len(hz) > 1 else hz[0] / nyq, kind)
    return signal.lfilter(b, a, x)


def lp(x, hz):
    return _filt(x, "low", hz)


def hp(x, hz):
    return _filt(x, "high", hz)


def bp(x, lo, hi):
    return _filt(x, "band", [lo, hi])


def expd(d, k):
    return np.exp(-tt(d) * k)


def sine(freq, d, phase=0.0):
    return np.sin(2 * np.pi * freq * tt(d) + phase)


def sweep(f0, f1, d):
    t = tt(d)
    freq = f0 * (f1 / f0) ** (t / d)
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def saw(freq, d):
    return signal.sawtooth(2 * np.pi * freq * tt(d))


def square(freq, d, duty=0.5):
    return signal.square(2 * np.pi * freq * tt(d), duty)


def tri(freq, d):
    return signal.sawtooth(2 * np.pi * freq * tt(d), 0.5)


def norm(x, peak=0.9):
    m = float(np.max(np.abs(x))) if len(x) else 0.0
    return x * (peak / m) if m > 1e-9 else x


def fade(x, ms_in=2.0, ms_out=12.0):
    x = x.copy()
    a, b = int(SR * ms_in / 1000.0), int(SR * ms_out / 1000.0)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def pad(x, d):
    n = int(SR * d)
    out = np.zeros(n)
    out[: min(n, len(x))] = x[:n]
    return out


def place(buf, snd, at, gain=1.0, wrap=False):
    i = int(at * SR)
    n = len(buf)
    if i >= n:
        return
    end = i + len(snd)
    if end <= n:
        buf[i:end] += snd * gain
    elif wrap:
        k = n - i
        buf[i:] += snd[:k] * gain
        rest = snd[k:]
        buf[: min(len(rest), n)] += rest[:n] * gain
    else:
        buf[i:] += snd[: n - i] * gain


def write(folder, name, x, peak=0.9):
    x = norm(np.nan_to_num(x), peak)
    path = os.path.join(ROOT, "audio", folder, name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(x, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("  %-34s %5.2fs %7.1f KB" % (folder + "/" + name, len(x) / SR, os.path.getsize(path) / 1024.0))


# ------------------------------------------------------------------------------------------------ weapons
def gun(d, crack_hz, body_lp, decay, f0, f1, thump_decay, tail=0.0):
    t = tt(d)
    crack = hp(noise(d), crack_hz) * np.exp(-t * decay * 1.6)
    body = lp(noise(d), body_lp) * np.exp(-t * decay)
    thump = sweep(f0, f1, d) * np.exp(-t * thump_decay)
    x = crack * 0.75 + body * 0.9 + thump * 0.9
    if tail > 0:
        x += lp(noise(d), 500) * np.exp(-t * tail) * 0.25
    return fade(x)


def launcher():
    d = 0.9
    t = tt(d)
    whoosh = bp(noise(d), 300, 2500) * np.sin(np.pi * np.clip(t / 0.5, 0, 1)) * np.exp(-t * 3)
    thump = sweep(110, 35, d) * np.exp(-t * 7)
    return fade(whoosh * 0.9 + thump * 1.1 + lp(noise(d), 900) * np.exp(-t * 10) * 0.7)


def explosion(d=1.8, boom=1.0):
    t = tt(d)
    rumble = lp(noise(d), 350) * np.exp(-t * 1.6)
    blast = lp(noise(d), 1500) * np.exp(-t * 7)
    sub = sweep(70, 25, d) * np.exp(-t * 2.2)
    clicks = (RNG.random(len(t)) > 0.997) * RNG.uniform(-1, 1, len(t))
    debris = lp(clicks, 6000) * np.exp(-t * 2.0)
    return fade(rumble + blast * 1.1 + sub * 1.2 * boom + debris * 0.7, 2, 40)


def punch(d, cutoff, f0, f1, k=38):
    t = tt(d)
    return fade(lp(noise(d), cutoff) * np.exp(-t * k) + sweep(f0, f1, d) * np.exp(-t * (k * 0.75)) * 0.9)


def whoosh(d=0.28, lo=600, hi=4500, level=0.8):
    t = tt(d)
    return fade(bp(noise(d), lo, hi) * np.sin(np.pi * t / d) ** 2 * level, 4, 20)


def click(d=0.03, ring=2600):
    t = tt(d)
    return hp(noise(d), 1500) * np.exp(-t * 160) * 0.8 + sine(ring, d) * np.exp(-t * 120) * 0.5


def chime(freqs, step, d, decay=9.0):
    out = np.zeros(int(SR * d))
    for i, f in enumerate(freqs):
        s = sine(f, d - i * step) * np.exp(-tt(d - i * step) * decay)
        s += sine(f * 2.0, d - i * step) * np.exp(-tt(d - i * step) * (decay * 1.6)) * 0.3
        place(out, s, i * step)
    return fade(out)


def brass(freq, d, vel=1.0, bright=2200):
    t = tt(d)
    env = np.minimum(t / 0.05, 1.0) * np.exp(-t * 1.5) * np.minimum((d - t) / 0.08, 1.0)
    tone = saw(freq, d) + 0.5 * saw(freq * 1.005, d) + 0.4 * square(freq * 0.5, d)
    return lp(tone, bright) * env * vel * 0.35


def build_sfx():
    print("SFX")
    write("sfx", "gun_pistol", gun(0.28, 2500, 3000, 30, 180, 60, 25))
    write("sfx", "gun_smg", gun(0.16, 3000, 3500, 55, 200, 80, 40))
    write("sfx", "gun_rifle", gun(0.34, 2000, 2600, 26, 150, 50, 22, tail=8))
    write("sfx", "gun_shotgun", gun(0.5, 1200, 1800, 14, 120, 40, 12, tail=6))
    write("sfx", "gun_sniper", gun(0.9, 1800, 2200, 10, 110, 35, 9, tail=4))
    write("sfx", "gun_lmg", gun(0.22, 1800, 2400, 38, 130, 55, 28))
    write("sfx", "gun_launcher", launcher())
    write("sfx", "explosion", explosion())
    write("sfx", "punch_light", punch(0.16, 1400, 180, 70))
    write("sfx", "kick_hit", punch(0.24, 900, 130, 50, 28))
    write("sfx", "whoosh", whoosh())
    t = tt(0.14)
    write("sfx", "hit_flesh", lp(noise(0.14), 900) * np.exp(-t * 45) + sweep(160, 70, 0.14) * np.exp(-t * 35))
    t = tt(0.07)
    write("sfx", "hit_marker", sine(1900, 0.07) * np.exp(-t * 70) + hp(noise(0.07), 3000) * np.exp(-t * 120) * 0.3)
    out = np.zeros(int(SR * 0.3))
    place(out, sine(1000, 0.12) * expd(0.12, 18), 0.0)
    place(out, sine(1500, 0.18) * expd(0.18, 14), 0.08)
    place(out, sweep(140, 60, 0.2) * expd(0.2, 18), 0.0, 0.8)
    write("sfx", "hit_kill", fade(out))
    out = np.zeros(int(SR * 0.5))
    place(out, click(), 0.0)
    place(out, bp(noise(0.2), 1200, 3200) * np.sin(np.pi * tt(0.2) / 0.2) * 0.35, 0.1)
    place(out, click(0.04, 2200), 0.32, 1.1)
    write("sfx", "reload_mag", fade(out))
    out = np.zeros(int(SR * 0.25))
    place(out, click(0.04, 1800), 0.0)
    place(out, click(0.05, 2600), 0.09, 1.2)
    write("sfx", "reload_done", fade(out))
    write("sfx", "grenade_pin", sine(3300, 0.22) * expd(0.22, 28) * 0.8 + pad(click(), 0.22))
    write("sfx", "dodge_roll", whoosh(0.35, 250, 1800, 0.7))
    write("sfx", "ui_back", sweep(520, 300, 0.13) * expd(0.13, 22))
    write("sfx", "countdown_tick", sine(880, 0.12) * expd(0.12, 24))


def build_crush_and_streaks():
    print("CRUSH / STREAKS / PICKUPS")
    write("sfx", "crush_ready", chime([523, 659, 784, 1046], 0.1, 0.6, 7))
    t = tt(1.4)
    quake = sweep(90, 28, 1.4) * np.exp(-t * 2.4) * 1.2 + lp(noise(1.4), 500) * np.exp(-t * 3) + hp(noise(1.4), 2000) * np.exp(-t * 12) * 0.5
    write("sfx", "crush_quake", fade(quake, 2, 40))
    t = tt(1.0)
    write("sfx", "crush_slam", fade(sweep(110, 30, 1.0) * np.exp(-t * 4) * 1.2 + lp(noise(1.0), 800) * np.exp(-t * 6) + hp(noise(1.0), 2500) * np.exp(-t * 18) * 0.5, 2, 40))
    out = np.zeros(int(SR * 0.7))
    place(out, whoosh(0.35, 400, 5000, 1.0), 0.0)
    place(out, punch(0.3, 1200, 160, 50, 22) * 1.2, 0.33)
    write("sfx", "crush_dragon", fade(out))
    t = tt(0.9)
    pulses = (np.sin(2 * np.pi * 18 * t) > 0).astype(float)
    storm = sweep(200, 1300, 0.9) * np.sin(np.pi * np.clip(t / 0.9, 0, 1)) * 0.6 + hp(noise(0.9), 1500) * pulses * np.exp(-t * 1.2) * 0.6
    write("sfx", "crush_storm", fade(storm))
    out = np.zeros(int(SR * 0.18))
    place(out, click(0.03, 1400), 0.0)
    place(out, click(0.03, 2100), 0.06, 1.2)
    write("sfx", "pickup_ammo", fade(out))
    write("sfx", "pickup_health", chime([660, 880, 1320], 0.11, 0.5, 8))
    t = tt(0.2)
    write("sfx", "pickup_coin", sine(1568, 0.2) * np.exp(-t * 14) + sine(2093, 0.2) * np.exp(-t * 18) * 0.8)
    out = np.zeros(int(SR * 0.7))
    for i in range(3):
        place(out, sine(1100, 0.12) * np.minimum(tt(0.12) / 0.01, 1) * np.minimum((0.12 - tt(0.12)) / 0.01, 1), 0.2 * i)
    write("sfx", "streak_ready", fade(out))
    out = np.zeros(int(SR * 0.5))
    place(out, hp(noise(0.18), 800) * 0.4 * np.sin(np.pi * tt(0.18) / 0.18), 0.0)
    place(out, sine(1400, 0.15) * expd(0.15, 12), 0.2)
    write("sfx", "streak_use", fade(out))
    t = tt(1.6)
    vibrato = 1.0 + 0.02 * np.sin(2 * np.pi * 6 * t)
    freq = np.linspace(2200, 500, len(t)) * vibrato
    whistle = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.sin(np.pi * t / 1.6) ** 0.6
    write("sfx", "airstrike_whistle", fade(whistle * 0.7 + hp(noise(1.6), 3000) * 0.08 * np.sin(np.pi * t / 1.6), 20, 60))
    t = tt(0.7)
    alarm = np.where((t * 4).astype(int) % 2 == 0, square(880, 0.7), square(660, 0.7)) * 0.5
    write("sfx", "alarm_warning", fade(lp(alarm, 3000) * np.sin(np.pi * np.clip(t / 0.7, 0, 1)) ** 0.3))
    write("sfx", "capture_done", chime([659, 988], 0.14, 0.7, 6))
    t = tt(1.3)
    horn = lp(saw(110, 1.3) + saw(165, 1.3) * 0.7, 900) * np.sin(np.pi * np.clip(t / 1.3, 0, 1)) ** 0.5
    write("sfx", "wave_start", fade(horn, 30, 80))


def build_stingers():
    print("STINGERS")
    out = np.zeros(int(SR * 2.4))
    for i, f in enumerate([523.25, 659.25, 783.99]):
        place(out, brass(f, 0.5), 0.18 * i)
    for f in [523.25, 659.25, 783.99, 1046.5]:
        place(out, brass(f, 1.6, 0.8), 0.62)
    write("sfx", "victory_fanfare", fade(out, 5, 120))
    out = np.zeros(int(SR * 1.8))
    for i, f in enumerate([440, 392, 349.23, 293.66]):
        place(out, tri(f, 0.7) * np.exp(-tt(0.7) * 2.6) * 0.5 * (1 + 0.03 * np.sin(2 * np.pi * 5 * tt(0.7))), 0.32 * i)
    place(out, lp(saw(73.4, 1.6), 400) * np.exp(-tt(1.6) * 1.8) * 0.5, 0.0)
    write("sfx", "defeat_sting", fade(out, 5, 120))


# ------------------------------------------------------------------------------------------------ music
def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12.0)


def kick(vol=1.0):
    t = tt(0.28)
    return (sweep(150, 45, 0.28) * np.exp(-t * 13) + pad(click(0.02, 90), 0.28) * 0.3) * vol


def snare(vol=1.0):
    t = tt(0.22)
    return (bp(noise(0.22), 1500, 7000) * np.exp(-t * 17) * 0.8 + sine(190, 0.22) * np.exp(-t * 24) * 0.4) * vol


def hat(vol=1.0, open_=False):
    d = 0.18 if open_ else 0.05
    return hp(noise(d), 7000) * np.exp(-tt(d) * (22 if open_ else 70)) * 0.45 * vol


def tom(f, vol=1.0):
    t = tt(0.4)
    return sweep(f * 1.5, f * 0.7, 0.4) * np.exp(-t * 8) * vol


def bass_note(note, d, vol=1.0):
    t = tt(d)
    return lp(saw(hz(note), d) + 0.6 * square(hz(note - 12), d), 420) * np.exp(-t * 6) * vol * 0.55


def pad_chord(notes, d, vol=1.0, bright=1500):
    t = tt(d)
    env = np.minimum(t / 0.35, 1.0) * np.minimum((d - t) / 0.4, 1.0)
    tone = sum(saw(hz(n), d) + saw(hz(n) * 1.004, d) for n in notes) / (2.0 * len(notes))
    return lp(tone, bright) * env * vol * 0.5


def pluck(note, d=0.22, vol=1.0, wave="tri"):
    t = tt(d)
    base = tri(hz(note), d) if wave == "tri" else square(hz(note), d, 0.35)
    return lp(base, 3200) * np.exp(-t * 14) * vol * 0.4


def sequence(bpm, bars, builder):
    beat = 60.0 / bpm
    total = bars * 4 * beat
    buf = np.zeros(int(round(total * SR)))
    builder(buf, beat)
    return buf


def battle_builder(buf, beat):
    chords = [[52, 55, 59], [48, 52, 55], [43, 47, 50], [50, 54, 57]]
    roots = [40, 36, 43, 38]
    bars = int(round(len(buf) / SR / (4 * beat)))
    for bar in range(bars):
        t0 = bar * 4 * beat
        block = (bar // 2) % 4
        for b in range(4):
            place(buf, kick(1.0), t0 + b * beat, 0.9, True)
            if b in (1, 3):
                place(buf, snare(0.9), t0 + b * beat, 0.8, True)
        for e in range(8):
            place(buf, hat(1.0, e % 2 == 1 and e == 7), t0 + e * beat * 0.5, 0.5 if e % 2 == 0 else 0.8, True)
        for e in range(8):
            note = roots[block] + (12 if e in (3, 6) else 0)
            place(buf, bass_note(note, beat * 0.5), t0 + e * beat * 0.5, 0.9, True)
        if bar % 2 == 0:
            place(buf, pad_chord(chords[block], beat * 8, 0.55), t0, 1.0, True)
        if bar >= bars // 2:
            for s in range(16):
                tone = chords[block][(s * 2 + (s // 4)) % 3] + 12 + (12 if s % 8 >= 4 else 0)
                place(buf, pluck(tone, 0.2, 0.8, "sq"), t0 + s * beat * 0.25, 0.55, True)


def boss_builder(buf, beat):
    chords = [[45, 48, 52], [41, 45, 48], [43, 47, 50], [40, 44, 47]]
    roots = [33, 29, 31, 28]
    bars = int(round(len(buf) / SR / (4 * beat)))
    for bar in range(bars):
        t0 = bar * 4 * beat
        block = (bar // 2) % 4
        for b in range(4):
            place(buf, kick(1.1), t0 + b * beat, 0.9, True)
        for b in (1, 3):
            place(buf, snare(1.0), t0 + b * beat, 0.8, True)
        for e in range(8):
            place(buf, hat(0.9), t0 + e * beat * 0.5, 0.45, True)
        pattern = [0, 0, 7, 0, 0, 5, 0, 3]
        for e, step in enumerate(pattern):
            place(buf, bass_note(roots[block] + step, beat * 0.5, 1.1), t0 + e * beat * 0.5, 0.95, True)
        if bar % 2 == 0:
            place(buf, pad_chord(chords[block], beat * 8, 0.6, 1100), t0, 1.0, True)
            for n in chords[block]:
                place(buf, brass(hz(n + 12), beat * 1.6, 0.9, 1800), t0, 0.7, True)
        if bar % 4 == 3:
            for k, f in enumerate([140, 120, 100, 85]):
                place(buf, tom(f, 1.0), t0 + beat * (2.0 + k * 0.5), 0.9, True)
        place(buf, tom(70, 1.0), t0 + beat * 0.5, 0.7, True)


def menu_builder(buf, beat):
    chords = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
    roots = [45, 41, 36, 43]
    bars = int(round(len(buf) / SR / (4 * beat)))
    for bar in range(bars):
        t0 = bar * 4 * beat
        block = (bar // 2) % 4
        if bar % 2 == 0:
            place(buf, pad_chord(chords[block], beat * 8, 0.8, 1300), t0, 1.0, True)
        place(buf, bass_note(roots[block], beat * 3.5, 0.9), t0, 0.7, True)
        for b in (0, 2):
            place(buf, kick(0.55), t0 + b * beat, 0.6, True)
        for e in range(8):
            place(buf, hat(0.6), t0 + e * beat * 0.5, 0.25, True)
        for s in range(8):
            tone = chords[block][s % 3] + 12 + (12 if s in (5, 6) else 0)
            place(buf, pluck(tone, 0.4, 0.9, "tri"), t0 + s * beat * 0.5, 0.5, True)


def build_music():
    print("MUSIC")
    write("music", "battle_loop", fade(sequence(128, 16, battle_builder), 5, 5), 0.85)
    write("music", "boss_loop", fade(sequence(108, 16, boss_builder), 5, 5), 0.85)
    write("music", "menu_theme", fade(sequence(92, 8, menu_builder), 5, 5), 0.8)


def build_ambience():
    print("AMBIENCE")
    d = 14.0
    t = tt(d)
    bed = lp(noise(d), 140) * (0.5 + 0.25 * np.sin(2 * np.pi * t / d * 2)) + lp(noise(d), 60) * 0.5
    buf = bed * 0.5
    for _ in range(5):
        at = RNG.uniform(0.0, d - 1.0)
        boom = lp(noise(2.2), 260) * np.exp(-tt(2.2) * 2.4) + sweep(60, 26, 2.2) * np.exp(-tt(2.2) * 2.2)
        place(buf, boom, at, RNG.uniform(0.25, 0.6), True)
    for _ in range(26):
        at = RNG.uniform(0.0, d - 0.5)
        pop = lp(hp(noise(0.12), 600) * np.exp(-tt(0.12) * 50), 1400)
        place(buf, pop, at, RNG.uniform(0.04, 0.14), True)
    write("ambience", "war_rumble", fade(buf, 5, 5), 0.6)


if __name__ == "__main__":
    build_sfx()
    build_crush_and_streaks()
    build_stingers()
    build_music()
    build_ambience()
