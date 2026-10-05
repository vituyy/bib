#!/usr/bin/env python3
"""Synthesises the game's music and sound effects into audio/*.mp3 (needs: pip install numpy scipy; ffmpeg).

Everything is generated from code, so there are no copyright questions and the sounds can be tuned here.
Upload the mp3 files to Roblox (Studio: View > Asset Manager > Audio > Bulk Import) and put the ids into
Config.Audio in src/shared/Config.luau.

    python3 tools/make_audio.py            # writes audio/*.mp3
"""
import os
import subprocess
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio")
RNG = np.random.default_rng(31)


# ---------------------------------------------------------------- building blocks
def mtof(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=float) - 69.0) / 12.0)


def tt(seconds):
    return np.arange(int(round(seconds * SR))) / SR


def lp(x, fc, order=2):
    return sosfilt(butter(order, min(fc, SR * 0.45), "low", fs=SR, output="sos"), x)


def hp(x, fc, order=2):
    return sosfilt(butter(order, fc, "high", fs=SR, output="sos"), x)


def adsr(n, a, d, s, r):
    """Envelope over n samples: attack a, decay d to level s, release r (seconds)."""
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    a, r = min(a, n), min(r, n)
    env = np.full(n, float(s))
    if a:
        env[:a] = np.linspace(0, 1, a)
    dd = min(d, max(n - a, 0))
    if dd:
        env[a:a + dd] = np.linspace(1, s, dd)
    if r:
        env[n - r:] *= np.linspace(1, 0, r)
    return env


def decay(n, tau):
    return np.exp(-np.arange(n) / SR / tau)


def saw(f, n, phase=0.0):
    t = np.arange(n) / SR
    return 2.0 * ((f * t + phase) % 1.0) - 1.0


def sine(f, n, phase=0.0):
    return np.sin(2 * np.pi * (f * np.arange(n) / SR + phase))


def tri(f, n):
    return 2.0 * np.abs(saw(f, n)) - 1.0


def noise(n):
    return RNG.standard_normal(n)


def reverb(x, wet=0.3, rt=2.5, damp=3500):
    n = int(rt * SR)
    ir = noise(n) * np.exp(-np.arange(n) / SR * 6.9 / rt)
    ir = lp(ir, damp)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    y = fftconvolve(x, ir)[: len(x) + n]
    out = np.zeros(len(y))
    out[: len(x)] += x * (1 - wet)
    out += y * wet
    return out


def mix_at(buf, sig, start):
    i = int(round(start * SR))
    if i < 0:
        sig, i = sig[-i:], 0
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i]


def add(*arrays):
    y = np.zeros(max(len(a) for a in arrays))
    for a in arrays:
        y[: len(a)] += a
    return y


def bell(m, dur=1.6, bright=1.0):
    """Music-box note."""
    f = float(mtof(m))
    n = int(dur * SR)
    y = np.zeros(n)
    for k, (ratio, amp, tau) in enumerate(((1, 1.0, 0.9), (2, 0.5, 0.5), (3, 0.28, 0.3), (4.2, 0.18 * bright, 0.18), (5.4, 0.1 * bright, 0.1))):
        y += amp * sine(f * ratio, n) * decay(n, tau)
    click = noise(int(0.004 * SR)) * 0.3
    y[: len(click)] += click
    return y * 0.5


def pluck(m, dur=0.6, tone=1.0):
    f = float(mtof(m))
    n = int(dur * SR)
    y = tri(f, n) * decay(n, 0.18) + 0.4 * sine(f * 2, n) * decay(n, 0.1)
    return lp(y, 900 * tone + 400) * 0.9


def pad(ms, dur, cutoff=1100):
    n = int(dur * SR)
    y = np.zeros(n)
    for m in ms:
        f = float(mtof(m))
        for det in (-0.07, 0.0, 0.07):
            y += saw(f * 2 ** (det / 12.0), n, RNG.random())
    y = lp(y, cutoff)
    return y * adsr(n, 1.4, 0.5, 0.8, 1.8) * 0.06


def ghost(m, dur, depth=0.004):
    f = float(mtof(m))
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1 + depth * np.sin(2 * np.pi * 5.2 * t) * np.minimum(t / 1.0, 1.0)
    y = np.sin(2 * np.pi * np.cumsum(f * vib) / SR) + 0.3 * np.sin(2 * np.pi * np.cumsum(2 * f * vib) / SR)
    return y * adsr(n, 1.2, 0.3, 0.8, 1.6) * 0.18


def kick(vol=1.0):
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    f = 42 + 110 * np.exp(-t * 28)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * decay(n, 0.11) * vol


def snare(vol=1.0):
    n = int(0.22 * SR)
    y = hp(noise(n), 1500) * decay(n, 0.07) * 0.6 + sine(190, n) * decay(n, 0.05) * 0.5
    return y * vol


def hat(vol=1.0):
    n = int(0.05 * SR)
    return hp(noise(n), 7000) * decay(n, 0.012) * 0.25 * vol


def fold_loop(y, length):
    """Make a loop of exactly `length` samples: the reverb tail wraps around to the start."""
    out = np.zeros(length)
    out += y[:length]
    tail = y[length:]
    out[: len(tail)] += tail[: length]
    return out


def normalise(y, peak=0.89):
    y = np.asarray(y, dtype=float)
    return y * (peak / (np.max(np.abs(y)) + 1e-9))


def fade_edges(y, ms=4):
    n = int(ms / 1000 * SR)
    y = y.copy()
    y[:n] *= np.linspace(0, 1, n)
    y[-n:] *= np.linspace(1, 0, n)
    return y


# ---------------------------------------------------------------- music
def chill_theme():
    """A slow spooky waltz: music box, warm pads, soft pizzicato bass, a ghostly voice. 32 bars, about 69 s."""
    bpm = 84
    beat = 60.0 / bpm
    bars = 32
    length = int(bars * 3 * beat * SR)
    buf = np.zeros(length + 6 * SR)
    # (root, chord tones) per bar. A minor waltz.
    Am, F, Dm, E, C, G = (45, (57, 60, 64)), (41, (57, 60, 65)), (50, (57, 62, 65)), (40, (56, 59, 64)), (48, (55, 60, 64)), (43, (55, 59, 62))
    prog_a = [Am, F, Dm, E, Am, F, E, Am]
    prog_b = [C, G, Am, E, F, Dm, E, Am]
    chords = prog_a + prog_b + prog_a + prog_b
    # melody: per bar a list of (beat, length in beats, midi)
    mel_a = [
        [(0, 2, 76), (2, 1, 74)], [(0, 2, 72), (2, 1, 69)], [(0, 1, 74), (1, 1, 77), (2, 1, 74)], [(0, 2, 68), (2, 1, 71)],
        [(0, 2, 76), (2, 1, 72)], [(0, 1, 69), (1, 1, 72), (2, 1, 77)], [(0, 1, 76), (1, 1, 74), (2, 1, 71)], [(0, 3, 69)],
    ]
    mel_b = [
        [(0, 1, 67), (1, 1, 72), (2, 1, 76)], [(0, 2, 74), (2, 1, 71)], [(0, 1, 72), (1, 1, 76), (2, 1, 81)], [(0, 2, 80), (2, 1, 76)],
        [(0, 1, 77), (1, 1, 72), (2, 1, 69)], [(0, 1, 74), (1, 1, 77), (2, 1, 81)], [(0, 1, 80), (1, 1, 76), (2, 1, 71)], [(0, 3, 69)],
    ]
    melody = mel_a + mel_b + mel_a + mel_b
    for bar in range(bars):
        t0 = bar * 3 * beat
        root, tones = chords[bar]
        mix_at(buf, pad(tones + (root + 12,), 3 * beat + 1.2), t0 - 0.05)
        mix_at(buf, pluck(root + 12, 0.9, 0.7) * 0.55, t0)
        for k in (1, 2):  # waltz "um-pah-pah"
            mix_at(buf, pluck(tones[k % 3] - 12 + 12, 0.35, 1.2) * 0.14, t0 + k * beat)
        # melody is quieter in the first 8 bars so the loop breathes
        gain = 0.55 if bar < 8 else 0.8
        for b, ln, midi in melody[bar]:
            mix_at(buf, bell(midi, ln * beat + 1.2) * gain, t0 + b * beat)
        # an octave higher echo on the last bar of each phrase
        if bar % 8 == 7:
            mix_at(buf, bell(93, 2.5, 0.6) * 0.18, t0 + 2 * beat)
        if bar % 8 == 3:
            mix_at(buf, ghost(69, 3 * beat * 2), t0)
    # wind
    n = len(buf)
    wind = lp(noise(n), 500) * (0.5 + 0.5 * np.sin(2 * np.pi * np.arange(n) / SR / 17.0)) * 0.012
    buf += wind
    buf = reverb(buf, 0.34, 3.0)
    buf = fold_loop(buf, length)
    return normalise(buf, 0.7)


def chase_theme():
    """Driving, tense: bass ostinato, kick and snare, tremolo strings, a stabbing lead. 32 bars at 152 bpm, about 50 s."""
    bpm = 152
    beat = 60.0 / bpm
    bars = 32
    length = int(bars * 4 * beat * SR)
    buf = np.zeros(length + 5 * SR)
    # bass root per bar (A minor, with a tritone-ish Eb twist every fourth phrase)
    roots = [33, 33, 29, 31, 33, 33, 36, 28] * 2 + [33, 33, 29, 31, 33, 34, 28, 40] + [33, 33, 29, 31, 36, 35, 40, 40]
    lead_notes = [69, 72, 76, 72, 69, 72, 77, 72]
    for bar in range(bars):
        t0 = bar * 4 * beat
        root = roots[bar]
        for i in range(8):  # eighth-note bass
            n = int(0.2 * SR)
            f = float(mtof(root + (12 if i in (3, 7) else 0)))
            y = lp(saw(f, n), 380 + 500 * (bar % 4) / 3) * decay(n, 0.12) * 0.5
            mix_at(buf, y, t0 + i * beat / 2)
        for k in range(4):
            if bar >= 2 or k == 0:
                mix_at(buf, kick(0.85), t0 + k * beat)
        if bar >= 2:
            for k in (1, 3):
                mix_at(buf, snare(0.7), t0 + k * beat)
            for i in range(16):
                mix_at(buf, hat(1.0 if i % 4 == 0 else 0.5), t0 + i * beat / 4)
        # tremolo strings (minor chord, pulsing sixteenths)
        if bar >= 4:
            n = int(4 * beat * SR)
            tones = (root + 24, root + 27, root + 31)
            y = sum(saw(float(mtof(m)), n, RNG.random()) for m in tones)
            y = lp(y, 2200) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (beat * 4) ** -1 * 8 * np.arange(n) / SR))) * adsr(n, 0.1, 0.1, 0.9, 0.2) * 0.05
            mix_at(buf, y, t0)
        # stabbing lead on the offbeats in the second half of each 8 bars
        if bar % 8 >= 4 and bar >= 8:
            for i, midi in enumerate(lead_notes):
                n = int(0.16 * SR)
                f = float(mtof(midi + (1 if (bar % 4 == 3 and i == 5) else 0)))
                y = lp(saw(f, n) + 0.5 * saw(f * 1.006, n), 3000) * decay(n, 0.08) * 0.16
                mix_at(buf, y, t0 + i * beat / 2)
        # riser at the end of every 8 bars
        if bar % 8 == 7:
            n = int(4 * beat * SR)
            r = hp(noise(n), 800) * np.linspace(0, 1, n) ** 2 * 0.18
            mix_at(buf, r, t0)
    buf = reverb(buf, 0.18, 1.4, 5000)
    buf = fold_loop(buf, length)
    return normalise(buf, 0.78)


def keep_random_state(fn):
    """New sounds use random noise too; restore the generator afterwards so the older sounds stay identical."""
    def wrapper(*args, **kwargs):
        state = RNG.bit_generator.state
        try:
            return fn(*args, **kwargs)
        finally:
            RNG.bit_generator.state = state
    return wrapper


@keep_random_state
def blood_theme():
    """Blood Moon: a low drone, a heartbeat, far tolling bells and dissonant strings. 24 bars at 60 bpm, 96 s."""
    beat = 1.0
    bars = 24
    length = int(bars * 4 * beat * SR)
    buf = np.zeros(length + 8 * SR)
    # drone: A1 with a flat fifth and a tritone underneath, slowly breathing
    n = len(buf)
    t = np.arange(n) / SR
    drone = np.zeros(n)
    for m, amp in ((33, 1.0), (40, 0.5), (39, 0.35), (45, 0.4)):
        f = float(mtof(m))
        drone += amp * (sine(f, n) + 0.4 * sine(f * 2.003, n)) * (0.75 + 0.25 * np.sin(2 * np.pi * t / 12.0 + m))
    buf += lp(drone, 500) * 0.16
    for bar in range(bars):
        t0 = bar * 4 * beat
        # heartbeat: lub-dub every two seconds, getting louder in the second half
        gain = 0.55 if bar < 12 else 0.8
        for k in range(2):
            mix_at(buf, kick(gain) * 0.9, t0 + k * 2.0)
            mix_at(buf, kick(gain * 0.6) * 0.7, t0 + k * 2.0 + 0.32)
        # dissonant strings: a minor second that rubs against itself
        if bar % 4 == 1:
            k = int(4 * beat * SR)
            y = lp(saw(float(mtof(57)), k) + saw(float(mtof(58)), k) * 0.8 + saw(float(mtof(64)), k) * 0.5, 1400)
            mix_at(buf, y * adsr(k, 1.6, 0.4, 0.7, 1.4) * 0.05, t0)
        # a far bell toll every four bars
        if bar % 4 == 3:
            mix_at(buf, bell(45, 5.0, 0.3) * 0.5, t0 + 2.0)
        # whispers: filtered noise swells
        if bar % 3 == 2:
            k = int(4 * beat * SR)
            w = hp(lp(noise(k), 3200), 900) * np.hanning(k) * 0.035
            mix_at(buf, w, t0)
    buf = reverb(buf, 0.4, 3.5, 2800)
    buf = fold_loop(buf, length)
    return normalise(buf, 0.75)


# ---------------------------------------------------------------- sound effects
def chime(midis, spacing=0.07, dur=1.0, vol=1.0):
    total = spacing * len(midis) + dur
    y = np.zeros(int(total * SR))
    for i, m in enumerate(midis):
        n = int(dur * SR)
        f = float(mtof(m))
        note = (sine(f, n) + 0.35 * sine(f * 2, n) + 0.15 * sine(f * 3, n)) * decay(n, dur / 4.0)
        mix_at(y, note, i * spacing)
    return y * vol


def sfx():
    out = {}
    # clicks
    n = int(0.09 * SR)
    out["ui_click"] = (sine(900, n) * decay(n, 0.018) * 0.8 + sine(1800, n) * decay(n, 0.01) * 0.3)
    n = int(0.05 * SR)
    out["ui_hover"] = sine(1400, n) * decay(n, 0.012) * 0.35
    # panels
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    f = 330 * 2 ** (t * 2.2)
    out["ui_open"] = lp(np.sin(2 * np.pi * np.cumsum(f) / SR), 3000) * adsr(n, 0.01, 0.1, 0.5, 0.15) * 0.7 + hp(noise(n), 3000) * np.hanning(n) * 0.04
    f = 740 * 2 ** (-t * 2.2)
    out["ui_close"] = lp(np.sin(2 * np.pi * np.cumsum(f) / SR), 3000) * adsr(n, 0.01, 0.1, 0.5, 0.15) * 0.6
    # buying: coin plus sparkle
    coin = np.zeros(int(1.0 * SR))
    mix_at(coin, chime([88], dur=0.5, vol=0.7), 0.0)
    mix_at(coin, chime([93], dur=0.9, vol=0.8), 0.07)
    mix_at(coin, chime([81, 84, 88, 93, 96], spacing=0.05, dur=0.7, vol=0.35), 0.12)
    out["ui_buy"] = coin
    # error: two low buzzes
    err = np.zeros(int(0.4 * SR))
    for i in range(2):
        n = int(0.14 * SR)
        mix_at(err, lp(saw(130, n) + saw(131.5, n), 700) * adsr(n, 0.005, 0.05, 0.8, 0.04) * 0.5, i * 0.17)
    out["ui_error"] = err
    # neutral message
    out["ui_notify"] = chime([84, 91], spacing=0.09, dur=0.5, vol=0.5)
    # coins / candy
    out["ui_coin"] = chime([96, 100], spacing=0.045, dur=0.25, vol=0.55)
    candy = np.zeros(int(0.5 * SR))
    for i, m in enumerate((84, 88, 91)):
        mix_at(candy, chime([m], dur=0.25, vol=0.5), i * 0.05)
    out["ui_candy"] = candy
    # level up
    out["ui_levelup"] = chime([72, 76, 79, 84, 88, 91, 96], spacing=0.075, dur=1.3, vol=0.6)
    # rebirth / big fanfare
    fan = np.zeros(int(2.2 * SR))
    for i, ch in enumerate(([60, 64, 67], [65, 69, 72], [67, 71, 74], [72, 76, 79, 84])):
        mix_at(fan, chime(ch, spacing=0.0, dur=1.2, vol=0.4), i * 0.28)
    mix_at(fan, chime([84, 88, 91, 96, 100], spacing=0.07, dur=1.0, vol=0.4), 1.1)
    out["fanfare"] = fan
    # egg picked up: spooky rising sting
    n = int(1.1 * SR)
    t = np.arange(n) / SR
    f = 110 * 2 ** (t * 1.6)
    st = lp(saw(1, n) * 0 + np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR), 2500) * adsr(n, 0.3, 0.2, 0.8, 0.5) * 0.45
    out["egg_pickup"] = add(st, chime([81], dur=0.9, vol=0.3))
    # chase alert: low hit and stabbing tritone
    n = int(1.2 * SR)
    al = np.zeros(n)
    mix_at(al, kick(1.2), 0.0)
    for i, m in enumerate((57, 63, 57, 63)):
        k = int(0.2 * SR)
        mix_at(al, lp(saw(float(mtof(m)), k) + saw(float(mtof(m)) * 1.01, k), 1800) * adsr(k, 0.005, 0.05, 0.7, 0.08) * 0.4, 0.08 + i * 0.16)
    out["chase_alert"] = al
    # escaped
    out["escape"] = chime([67, 72, 76, 79, 84], spacing=0.09, dur=1.2, vol=0.5)
    # caught: thump plus sad slide
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    f = 400 * 2 ** (-t * 1.3)
    slide = lp(np.sin(2 * np.pi * np.cumsum(f) / SR), 1500) * adsr(n, 0.02, 0.1, 0.7, 0.3) * 0.3
    cg = np.zeros(int(1.1 * SR))
    mix_at(cg, kick(1.1), 0.0)
    mix_at(cg, slide, 0.18)
    out["caught"] = cg
    # kick hit
    n = int(0.35 * SR)
    kk = add(kick(1.0) * 0.9, hp(noise(n), 400) * decay(n, 0.04) * 0.5)
    out["kick"] = kk
    # door knock: three wood knocks
    kn = np.zeros(int(0.9 * SR))
    for i in range(3):
        n = int(0.12 * SR)
        k = (sine(210, n) + 0.6 * sine(420, n) + 0.3 * sine(690, n)) * decay(n, 0.03) + lp(noise(n), 1200) * decay(n, 0.006) * 0.5
        mix_at(kn, k * 0.8, i * 0.2)
    out["knock"] = kn
    # door creak
    n = int(1.3 * SR)
    t = np.arange(n) / SR
    f = 180 + 90 * np.sin(2 * np.pi * 3.0 * t) + 140 * t
    cr = (np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.5 + noise(n) * 0.1)
    out["door_creak"] = lp(hp(cr, 250), 1800) * adsr(n, 0.15, 0.2, 0.7, 0.4) * 0.35
    # egg hatch: crack, pop, sparkle
    h = np.zeros(int(1.6 * SR))
    for i in range(3):
        n = int(0.05 * SR)
        mix_at(h, hp(noise(n), 1500) * decay(n, 0.01) * 0.6, i * 0.09)
    n = int(0.25 * SR)
    pop = sine(300, n) * decay(n, 0.05) + sine(600, n) * decay(n, 0.03) * 0.5
    mix_at(h, pop * 0.8, 0.34)
    mix_at(h, chime([84, 88, 91, 96, 100, 103], spacing=0.06, dur=1.0, vol=0.5), 0.4)
    out["egg_hatch"] = h
    # egg placed on a pad: soft thud and ping
    n = int(0.3 * SR)
    pl = sine(160, n) * decay(n, 0.06) * 0.9
    pl2 = np.zeros(int(0.8 * SR))
    mix_at(pl2, pl, 0)
    mix_at(pl2, chime([88], dur=0.5, vol=0.4), 0.05)
    out["egg_place"] = pl2
    # blood moon rising: a swelling drone and a deep bell (drawn with the random state saved, see below)
    state = RNG.bit_generator.state
    n = int(3.2 * SR)
    t = np.arange(n) / SR
    rise = lp(saw(55, n) + saw(55.4, n) + saw(82.5, n) * 0.5, 600 + 900 * (t / 3.2)[0:1].mean()) * np.linspace(0, 1, n) ** 1.5 * 0.35
    out["blood_rise"] = add(rise, bell(33, 3.2, 0.2) * 0.7)
    # thunder: a noise burst that rolls off
    n = int(2.4 * SR)
    th = lp(noise(n), 400) * decay(n, 0.6) * 1.2 + lp(noise(n), 120) * decay(n, 1.0)
    th[: int(0.05 * SR)] *= np.linspace(0, 1, int(0.05 * SR))
    out["thunder"] = th
    RNG.bit_generator.state = state
    # whoosh (sprint / generic)
    n = int(0.5 * SR)
    wh = lp(noise(n), 2500) * np.hanning(n) * 0.5
    out["whoosh"] = hp(wh, 400)
    return out


# ---------------------------------------------------------------- output
def write_mp3(name, y, peak, is_music):
    os.makedirs(OUT, exist_ok=True)
    y = fade_edges(normalise(y, peak)) if not is_music else normalise(y, peak)
    wav = os.path.join(OUT, name + ".wav")
    wavfile.write(wav, SR, (np.clip(y, -1, 1) * 32767).astype(np.int16))
    mp3 = os.path.join(OUT, name + ".mp3")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-codec:a", "libmp3lame", "-qscale:a", "3", mp3], check=True)
    os.remove(wav)
    print(f"{name}.mp3  {len(y) / SR:5.1f}s  {os.path.getsize(mp3) // 1024} KB")


def main():
    write_mp3("music_chill", chill_theme(), 0.7, True)
    write_mp3("music_chase", chase_theme(), 0.78, True)
    write_mp3("music_blood", blood_theme(), 0.75, True)
    for name, y in sfx().items():
        write_mp3(name, y, 0.85, False)


if __name__ == "__main__":
    sys.exit(main())
