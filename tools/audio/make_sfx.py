#!/usr/bin/env python3
"""Builds every sound effect in the game from code: game/audio/sfx/*.wav.

Nothing here is recorded or downloaded. Each sound is synthesised from noise, sine
waves, filters and envelopes, so the files are ours outright (see game/audio/LICENSE.md).
Run it again after changing a recipe:

    python3 tools/audio/make_sfx.py            # every sound
    python3 tools/audio/make_sfx.py fire_      # only names starting with "fire_"

The style is crisp but realistic: a clean attack, real weight in the low end, gun
actions and armour made of dull steel rather than ringing bells, and room tails.
The players are robots, so hits are metal (feet have soft rubber treads), but nothing is "beepy".
Every sound is normalised to the same peak; Sound (game/audio/sound.gd) sets how loud
each one plays. Needs Python 3 and numpy only. Output: 44.1 kHz, 16-bit, mono (the
first-person gunshots are stereo for a wider tail).
"""
import math
import os
import sys
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "game", "audio", "sfx")
PEAK = 10 ** (-1.0 / 20)   # normalise every sound to -1 dBFS


# ---------------------------------------------------------------------------
# Building blocks

def n(seconds):
    return max(int(round(seconds * SR)), 1)


def tt(seconds):
    return np.arange(n(seconds)) / SR


def noise(rng, seconds):
    return rng.uniform(-1.0, 1.0, n(seconds))


def _biquad(x, b0, b1, b2, a1, a2):
    y = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, xi in enumerate(x.tolist()):
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def _rbj(kind, f, q, gain_db=0.0):
    f = min(max(f, 10.0), SR * 0.45)
    w = 2 * math.pi * f / SR
    cw, sw = math.cos(w), math.sin(w)
    alpha = sw / (2 * q)
    a = 10 ** (gain_db / 40)
    if kind == "lp":
        b = ((1 - cw) / 2, 1 - cw, (1 - cw) / 2); den = (1 + alpha, -2 * cw, 1 - alpha)
    elif kind == "hp":
        b = ((1 + cw) / 2, -(1 + cw), (1 + cw) / 2); den = (1 + alpha, -2 * cw, 1 - alpha)
    elif kind == "bp":
        b = (alpha, 0.0, -alpha); den = (1 + alpha, -2 * cw, 1 - alpha)
    elif kind == "peak":
        b = (1 + alpha * a, -2 * cw, 1 - alpha * a); den = (1 + alpha / a, -2 * cw, 1 - alpha / a)
    else:
        raise ValueError(kind)
    a0 = den[0]
    return b[0] / a0, b[1] / a0, b[2] / a0, den[1] / a0, den[2] / a0


def lp(x, f, q=0.707):
    return _biquad(x, *_rbj("lp", f, q))


def hp(x, f, q=0.707):
    return _biquad(x, *_rbj("hp", f, q))


def bp(x, f, q=1.0):
    return _biquad(x, *_rbj("bp", f, q))


def peak(x, f, q, gain_db):
    return _biquad(x, *_rbj("peak", f, q, gain_db))


def sweep_bp(x, f_start, f_end, q=2.0, curve=1.0):
    """A band-pass whose centre glides from f_start to f_end (a state-variable filter)."""
    y = np.empty_like(x)
    low = band = 0.0
    count = len(x)
    damp = 1.0 / q
    for i, xi in enumerate(x.tolist()):
        u = (i / max(count - 1, 1)) ** curve
        f = f_start * (f_end / f_start) ** u
        g = 2 * math.sin(math.pi * min(f, SR * 0.2) / SR)
        high = xi - low - damp * band
        band += g * high
        low += g * band
        y[i] = band
    return y


def env(seconds, tau, attack=0.0005):
    """A fast rise and an exponential fall (tau = seconds to fall to 37 %)."""
    t = tt(seconds)
    rise = np.clip(t / attack, 0.0, 1.0) if attack > 0 else 1.0
    return rise * np.exp(-t / tau)


def bell_env(seconds, at=0.4, power=2.0):
    """Rises to a peak at `at` (a fraction of the length), then falls: a whoosh."""
    u = np.linspace(0.0, 1.0, n(seconds))
    return np.where(u < at, (u / at) ** power, ((1 - u) / (1 - at)) ** power)


def sine_sweep(seconds, f0, f1, tau):
    """A sine that falls (or rises) from f0 towards f1 with time constant tau."""
    t = tt(seconds)
    f = f1 + (f0 - f1) * np.exp(-t / tau)
    return np.sin(2 * math.pi * np.cumsum(f) / SR)


def glide(seconds, f0, f1, shape="sine"):
    t = tt(seconds)
    f = f0 * (f1 / f0) ** (t / max(seconds, 1e-6))
    ph = 2 * math.pi * np.cumsum(f) / SR
    if shape == "saw":
        return 2 * ((ph / (2 * math.pi)) % 1.0) - 1
    if shape == "square":
        return np.sign(np.sin(ph))
    return np.sin(ph)


def modal(rng, seconds, freqs, decays, amps=None, detune=0.0):
    """Struck metal: a few damped sines at inharmonic frequencies."""
    t = tt(seconds)
    out = np.zeros_like(t)
    amps = amps or [1.0 / (i + 1) for i in range(len(freqs))]
    for f, d, a in zip(freqs, decays, amps):
        f *= 1.0 + rng.uniform(-detune, detune)
        out += a * np.sin(2 * math.pi * f * t + rng.uniform(0, 2 * math.pi)) * np.exp(-t / d)
    return out


def click(rng, seconds=0.006, tau=0.0007, cutoff=3000.0):
    """A very short bright transient."""
    return lp(hp(noise(rng, seconds) * env(seconds, tau, 0.0001), cutoff * 0.45), 6500)


def sat(x, drive=2.0):
    return np.tanh(drive * x) / math.tanh(drive)


def fit(x, length):
    if len(x) >= length:
        return x[:length]
    return np.concatenate([x, np.zeros(length - len(x))])


def mix(*parts):
    """Sum of (signal, start seconds, gain) tuples, or bare signals at 0 s."""
    items = [(p, 0.0, 1.0) if isinstance(p, np.ndarray) else (p + (1.0,) if len(p) == 2 else p) for p in parts]
    length = max(n(at) + len(sig) for sig, at, _ in items)
    out = np.zeros(length)
    for sig, at, gain in items:
        s = n(at) if at > 0 else 0
        out[s:s + len(sig)] += sig * gain
    return out


def fftconv(x, h):
    size = len(x) + len(h) - 1
    m = 1 << (size - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(h, m), m)[:size]


def room_ir(rng, rt60, bright=4000.0, early=(0.011, 0.019, 0.027, 0.041), seconds=None):
    """A small synthetic room: a few early reflections and a decaying, darkening tail."""
    seconds = seconds or rt60 * 1.1
    t = tt(seconds)
    hi = hp(noise(rng, seconds), 2500) * np.exp(-6.9 * t / (rt60 * 0.45))
    lo = lp(noise(rng, seconds), bright) * np.exp(-6.9 * t / rt60)
    ir = (lo + 0.5 * hi) * np.clip(t / 0.008, 0, 1)
    for i, d in enumerate(early):
        k = n(d)
        if k < len(ir):
            ir[k] += 0.7 * (0.8 ** i) * rng.choice([-1, 1])
    return ir / np.sqrt(np.sum(ir ** 2))


def finish(x, floor_db=-62.0, fade=0.004):
    """Removes rumble below 25 Hz, trims silence off the end, fades out and normalises."""
    stereo = x.ndim == 2
    chans = [x[:, 0], x[:, 1]] if stereo else [x]
    chans = [hp(c, 25.0) for c in chans]
    mag = np.max([np.abs(c) for c in chans], axis=0)
    top = mag.max()
    if top <= 0:
        raise ValueError("silent sound")
    loud = np.nonzero(mag > top * 10 ** (floor_db / 20))[0]
    end = min(loud[-1] + n(0.01), len(mag))
    out = []
    for c in chans:
        c = c[:end].copy()
        k = min(n(fade), len(c))
        c[-k:] *= np.linspace(1.0, 0.0, k)
        out.append(c)
    y = np.stack(out, axis=1) if stereo else out[0]
    return y * (PEAK / np.max(np.abs(y)))


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    data = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(2 if x.ndim == 2 else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ---------------------------------------------------------------------------
# Guns

GUNS = {
    # crack: (centre Hz, Q, decay), blast: (lowpass Hz, decay, gain), boom: (decay, gain),
    # thump: (start Hz, end Hz, decay, gain), mech: metallic action (freqs, decay),
    # tail: (rt60, gain, brightness), slide_at: the slide or bolt carrier slamming home
    "pistol": dict(crack=(1700, 0.7, 0.012), blast=(2400, 0.022, 1.0), boom=(0.07, 0.6),
                   thump=(130, 50, 0.05, 0.7), mech=([980, 1630, 2480], 0.01), slide_at=0.03,
                   tail=(0.75, 0.45, 2200), drive=2.6),
    "rifle": dict(crack=(1900, 0.7, 0.01), blast=(2600, 0.02, 1.0), boom=(0.06, 0.75),
                  thump=(120, 46, 0.045, 0.8), mech=([860, 1420, 2210], 0.009), slide_at=0.024,
                  tail=(0.65, 0.4, 2100), drive=3.0),
    "shotgun": dict(crack=(1200, 0.6, 0.02), blast=(1700, 0.045, 1.3), boom=(0.16, 0.55),
                    thump=(100, 42, 0.08, 0.6), mech=([700, 1180, 1870], 0.014), slide_at=None,
                    tail=(1.2, 0.6, 1800), drive=3.2),
    "sniper": dict(crack=(2000, 0.6, 0.016), blast=(2000, 0.04, 1.3), boom=(0.2, 0.5),
                   thump=(95, 38, 0.1, 0.55), mech=([640, 1090, 1720], 0.016), slide_at=None,
                   tail=(1.9, 0.7, 1900), drive=3.4),
    # The newer guns
    "revolver": dict(crack=(1500, 0.6, 0.016), blast=(2000, 0.035, 1.25), boom=(0.13, 0.75),
                     thump=(115, 42, 0.08, 0.8), mech=([820, 1380, 2150], 0.012), slide_at=None,
                     tail=(1.2, 0.55, 2000), drive=3.3),
    "machine_pistol": dict(crack=(2100, 0.8, 0.008), blast=(2800, 0.016, 0.9), boom=(0.045, 0.5),
                           thump=(150, 60, 0.035, 0.55), mech=([1100, 1800, 2700], 0.008), slide_at=0.02,
                           tail=(0.55, 0.35, 2300), drive=2.6),
    "break_action": dict(crack=(1050, 0.55, 0.024), blast=(1500, 0.055, 1.45), boom=(0.2, 0.65),
                         thump=(90, 38, 0.1, 0.75), mech=([620, 1050, 1700], 0.012), slide_at=None,
                         tail=(1.4, 0.65, 1700), drive=3.4),
    "smg": dict(crack=(2000, 0.75, 0.009), blast=(2700, 0.018, 0.95), boom=(0.05, 0.6),
                thump=(135, 52, 0.04, 0.6), mech=([980, 1600, 2500], 0.008), slide_at=0.02,
                tail=(0.6, 0.38, 2200), drive=2.8),
    "burst_rifle": dict(crack=(1850, 0.7, 0.011), blast=(2500, 0.022, 1.05), boom=(0.07, 0.75),
                        thump=(118, 44, 0.05, 0.8), mech=([900, 1500, 2300], 0.009), slide_at=0.022,
                        tail=(0.7, 0.42, 2100), drive=3.0),
    "lmg": dict(crack=(1650, 0.65, 0.012), blast=(2200, 0.028, 1.15), boom=(0.09, 0.85),
                thump=(105, 40, 0.06, 0.9), mech=([760, 1260, 1980], 0.011), slide_at=0.026,
                tail=(0.8, 0.45, 1900), drive=3.2),
    "lever_action": dict(crack=(1750, 0.6, 0.015), blast=(2100, 0.035, 1.2), boom=(0.15, 0.6),
                         thump=(105, 40, 0.08, 0.65), mech=([700, 1150, 1800], 0.014), slide_at=None,
                         tail=(1.5, 0.6, 1900), drive=3.3),
    "bolt_action": dict(crack=(1950, 0.6, 0.015), blast=(2050, 0.038, 1.25), boom=(0.18, 0.55),
                        thump=(98, 38, 0.09, 0.6), mech=([660, 1110, 1750], 0.015), slide_at=None,
                        tail=(1.7, 0.65, 1900), drive=3.4),
}


def gun_dry(rng, g):
    """The shot itself: a broadband blast, the supersonic crack, a low boom and the action cycling."""
    length = 0.6
    cf, cq, ctau = g["crack"]
    crack = bp(noise(rng, length), cf, cq) * env(length, ctau, 0.0002) * 1.6
    air = hp(noise(rng, length), 4500) * env(length, 0.0025, 0.0001) * 0.25
    bc, btau, bg = g["blast"]
    blast = lp(noise(rng, length), bc) * env(length, btau, 0.0004) * bg
    btau2, bgain = g["boom"]
    boom = lp(lp(noise(rng, length), 260), 260) * env(length, btau2, 0.002) * bgain * 1.1
    f0, f1, ttau, tg = g["thump"]
    thump = sine_sweep(length, f0, f1, ttau * 0.4) * env(length, ttau, 0.001) * tg * 0.55
    freqs, mtau = g["mech"]
    mech = modal(rng, length, freqs, [mtau, mtau * 0.8, mtau * 0.6], [0.16, 0.12, 0.08], 0.05)
    mech += bp(noise(rng, length), freqs[1], 1.5) * env(length, mtau * 0.6, 0.0002) * 0.25
    parts = [blast, crack, air, boom, thump, mech]
    if g["slide_at"]:
        slam = bp(noise(rng, 0.06), freqs[0] * 1.2, 1.2) * env(0.06, 0.006, 0.0002) * 0.3
        parts.append((slam, g["slide_at"]))
    dry = mix(*parts)
    dry = sat(dry * 1.1, g["drive"])
    dry = peak(dry, 180, 0.8, 1.5)     # weight
    dry = peak(dry, 2200, 0.9, 2.0)    # the crack cuts through
    dry = peak(dry, 4500, 0.8, -3.0)   # no fizz
    return lp(dry, 9000)


def gun_fire(name, stereo=False, seed=0):
    rng = np.random.default_rng(1000 + seed)
    g = GUNS[name]
    dry = gun_dry(rng, g)
    rt, tg, bright = g["tail"]
    feed = lp(dry, bright)
    if not stereo:
        tail = fftconv(feed, room_ir(rng, rt, bright)) * tg
        return finish(mix(dry, tail))
    tails = [fftconv(feed, room_ir(np.random.default_rng(2000 + k + seed), rt, bright)) * tg for k in range(2)]
    length = max(len(dry), len(tails[0]), len(tails[1]))
    left = fit(dry, length) + fit(tails[0], length)
    right = fit(dry, length) + fit(tails[1], length)
    return finish(np.stack([left, right], axis=1))


def railgun_fire(stereo=False, seed=0):
    """The railgun: a rising electric whine snapping into a hard magnetic crack and a falling zap."""
    rng = np.random.default_rng(1500 + seed)
    length = 0.9
    whine = glide(0.12, 900, 3800) * bell_env(0.12, 0.9, 2.0) * 0.25
    crack = bp(noise(rng, length), 2600, 0.6) * env(length, 0.012, 0.0002) * 1.8
    zap = sine_sweep(length, 2400, 120, 0.05) * env(length, 0.09, 0.0005) * 0.6
    zap += sine_sweep(length, 1210, 60, 0.06) * env(length, 0.12, 0.0005) * 0.35
    buzz = sat(glide(0.4, 220, 90, "saw") * env(0.4, 0.12), 2.0) * 0.25
    thump = sine_sweep(length, 140, 40, 0.03) * env(length, 0.08, 0.001) * 0.9
    dry = lp(sat(mix((whine, 0.0), (crack, 0.11), (zap, 0.11), (buzz, 0.11), (thump, 0.11)), 1.8), 11000)
    tail = fftconv(lp(dry, 3000), room_ir(rng, 1.4, 3000)) * 0.5
    if not stereo:
        return finish(mix(dry, tail))
    tail2 = fftconv(lp(dry, 3000), room_ir(np.random.default_rng(1600 + seed), 1.4, 3000)) * 0.5
    m = max(len(dry), len(tail), len(tail2))
    return finish(np.stack([fit(dry, m) + fit(tail, m), fit(dry, m) + fit(tail2, m)], axis=1))


def rocket_fire(stereo=False, seed=0):
    """The rocket launcher: a hollow pop from the tube, a roaring back blast and the motor rushing away."""
    rng = np.random.default_rng(1700 + seed)
    pop = sat(sine_sweep(0.3, 180, 50, 0.03) * env(0.3, 0.06, 0.001) * 1.6, 2.0)
    blast = lp(noise(rng, 0.8), 1800) * env(0.8, 0.12, 0.002) * 1.1
    roar = sweep_bp(noise(rng, 1.0), 1400, 500, 0.9) * bell_env(1.0, 0.15, 1.2) * 0.9
    hiss = hp(noise(rng, 0.9), 3000) * bell_env(0.9, 0.12, 1.5) * 0.25
    dry = sat(mix(click(rng, 0.01, 0.0006, 2500) * 0.6, pop, blast, roar, hiss), 1.5)
    tail = fftconv(lp(dry, 2200), room_ir(rng, 1.3, 2200)) * 0.4
    if not stereo:
        return finish(mix(dry, tail))
    tail2 = fftconv(lp(dry, 2200), room_ir(np.random.default_rng(1800 + seed), 1.3, 2200)) * 0.4
    m = max(len(dry), len(tail), len(tail2))
    return finish(np.stack([fit(dry, m) + fit(tail, m), fit(dry, m) + fit(tail2, m)], axis=1))


def grenade_fire(stereo=False, seed=0):
    """The grenade launcher: a deep, hollow "thoomp" and the drum's clack."""
    rng = np.random.default_rng(1900 + seed)
    thoomp = sat(sine_sweep(0.4, 160, 55, 0.04) * env(0.4, 0.09, 0.002) * 1.8, 1.8)
    puff = lp(noise(rng, 0.3), 900) * env(0.3, 0.05, 0.002) * 0.8
    tube = modal(rng, 0.4, [330, 610, 980], [0.05, 0.035, 0.02], [0.25, 0.15, 0.08])
    dry = mix(click(rng, 0.008, 0.0006, 1800) * 0.4, thoomp, puff, tube, (metal_clack(rng, 0.8, 1.0, 0.6) * 0.4, 0.09))
    tail = fftconv(lp(dry, 1800), room_ir(rng, 0.8, 1800)) * 0.3
    if not stereo:
        return finish(mix(dry, tail))
    tail2 = fftconv(lp(dry, 1800), room_ir(np.random.default_rng(1950 + seed), 0.8, 1800)) * 0.3
    m = max(len(dry), len(tail), len(tail2))
    return finish(np.stack([fit(dry, m) + fit(tail, m), fit(dry, m) + fit(tail2, m)], axis=1))


SPECIAL_FIRE = {"railgun": railgun_fire, "rocket_launcher": rocket_fire, "grenade_launcher": grenade_fire}


def special_far(name):
    rng = np.random.default_rng(3100 + list(SPECIAL_FIRE).index(name))
    dry = hp(lp(SPECIAL_FIRE[name](), 1300), 80)
    tail = fftconv(dry, room_ir(rng, 2.2, 1600, early=(0.09, 0.16, 0.27, 0.41))) * 0.9
    return finish(mix(dry, tail, (lp(dry, 800) * 0.4, 0.2), (lp(dry, 600) * 0.25, 0.42)))


def explosion(seed, far=False):
    """A rocket or grenade going off: a deep blast, a crackling burst, debris and a long rumble."""
    rng = np.random.default_rng(9800 + seed)
    length = 2.0
    boom = sat(sine_sweep(length, 90, 28, 0.08) * env(length, 0.35, 0.001) * 2.2, 2.5)
    blast = lp(noise(rng, length), 2200) * env(length, 0.09, 0.0005) * 1.6
    crackle = np.zeros(n(length))
    for _ in range(rng.integers(30, 45)):
        at = n(rng.uniform(0.01, 0.6))
        c = bp(click(rng, 0.012, 0.0008, 3000), rng.uniform(1200, 4000), 1.2) * rng.uniform(0.1, 0.4)
        crackle[at:at + len(c)] += c[: len(crackle) - at]
    rumble = lp(noise(rng, length), 160) * env(length, 0.6, 0.02) * 1.4
    dry = sat(mix(click(rng, 0.01, 0.0008, 2500), boom, blast, crackle, rumble), 1.8)
    if far:
        dry = hp(lp(dry, 900), 50)
    tail = fftconv(lp(dry, 2000), room_ir(rng, 2.4 if far else 1.6, 2000)) * 0.5
    return finish(mix(dry, tail))


def gun_far(name):
    """The same gun far away: no crack, a dull thud, and echoes off distant walls."""
    rng = np.random.default_rng(3000)
    g = GUNS[name]
    dry = lp(gun_dry(rng, g), 1400)
    dry = hp(dry, 90)
    rt = g["tail"][0] * 1.8 + 0.6
    tail = fftconv(dry, room_ir(rng, rt, 1800, early=(0.09, 0.16, 0.27, 0.41))) * 0.9
    echoes = [(lp(dry, 900) * 0.45, 0.19), (lp(dry, 700) * 0.3, 0.38), (lp(dry, 600) * 0.18, 0.62)]
    return finish(mix(dry, tail, *echoes))


# Gun handling: actions, reload steps, empty click, equip

def metal_clack(rng, scale=1.0, decay=1.0, weight=1.0):
    """The hard click of steel parts meeting."""
    f = [x * scale for x in (1150, 1870, 2830, 4100)]
    d = [0.016 * decay, 0.011 * decay, 0.007 * decay, 0.004 * decay]
    m = modal(rng, 0.2, f, d, [0.35, 0.28, 0.18, 0.1], 0.06)
    knock = bp(noise(rng, 0.2), 1400 * scale, 1.2) * env(0.2, 0.006 * decay, 0.0002) * 0.9
    thud = sine_sweep(0.2, 200 * scale, 90, 0.01) * env(0.2, 0.022) * 0.55 * weight
    return mix(click(rng, 0.01, 0.0005, 2500) * 0.6, knock, m, thud)


def metal_slide(rng, seconds=0.07, centre=2400.0, rise=1.4):
    """Steel sliding on steel: a short gritty scrape."""
    grit = noise(rng, seconds) * (rng.uniform(0, 1, n(seconds)) > 0.6)
    centre *= 0.55   # recipes give the old, brighter centres
    return sweep_bp(grit, centre, centre * rise, 2.0) * bell_env(seconds, 0.3, 1.2) * 0.9


def handling(name, rng):
    s = {
        "cylinder_open": lambda: mix(metal_clack(rng, 1.3, 0.5, 0.2), (metal_slide(rng, 0.06, 2800, 1.3) * 0.6, 0.012)),
        "cylinder_close": lambda: mix(metal_slide(rng, 0.04, 2400, 0.8) * 0.5, (metal_clack(rng, 1.05, 1.0, 0.9), 0.03)),
        "empties_out": lambda: mix(*[(metal_clack(rng, rng.uniform(1.6, 2.2), 0.3, 0.05) * rng.uniform(0.3, 0.6),
                                      rng.uniform(0.0, 0.15)) for _ in range(6)]),
        "speedloader": lambda: mix(metal_slide(rng, 0.05, 1600, 1.4) * 0.7, (metal_clack(rng, 0.9, 1.0, 0.8), 0.04),
                                   (metal_clack(rng, 1.5, 0.4, 0.2) * 0.4, 0.07)),
        "break_open": lambda: mix(metal_clack(rng, 0.9, 1.0, 0.6), (metal_slide(rng, 0.1, 900, 0.7) * 0.7, 0.03),
                                  (metal_clack(rng, 0.6, 1.4, 1.2) * 0.6, 0.12)),
        "break_close": lambda: mix(metal_slide(rng, 0.05, 1200, 1.4) * 0.5, (metal_clack(rng, 0.65, 1.8, 1.8), 0.04)),
        "shells_in": lambda: mix((metal_clack(rng, 0.8, 0.8, 0.6), 0.0), (metal_clack(rng, 0.85, 0.8, 0.6) * 0.9, 0.06),
                                 (metal_slide(rng, 0.04, 1000, 1.5) * 0.4, 0.0)),
        "lever_down": lambda: mix(metal_slide(rng, 0.07, 1500, 1.5), (metal_clack(rng, 0.95, 0.9, 0.6), 0.06)),
        "lever_up": lambda: mix(metal_slide(rng, 0.06, 1900, 0.8) * 0.8, (metal_clack(rng, 0.8, 1.3, 1.2), 0.05)),
        "cover_open": lambda: mix(metal_clack(rng, 0.75, 1.2, 0.8), (metal_slide(rng, 0.12, 800, 1.6) * 0.6, 0.02)),
        "cover_close": lambda: mix(metal_clack(rng, 0.55, 1.8, 1.8), (metal_clack(rng, 0.9, 0.9, 0.5) * 0.5, 0.03)),
        "box_out": lambda: mix(metal_clack(rng, 0.7, 1.3, 1.0), (metal_slide(rng, 0.14, 700, 1.3), 0.02)),
        "box_in": lambda: mix(metal_slide(rng, 0.1, 700, 1.6) * 0.7, (metal_clack(rng, 0.6, 1.6, 1.6), 0.08)),
        "cell_out": lambda: mix(metal_clack(rng, 1.1, 0.7, 0.4), (glide(0.25, 1800, 300) * env(0.25, 0.08) * 0.2, 0.0)),
        "cell_in": lambda: mix(metal_clack(rng, 0.9, 1.1, 1.0), (glide(0.45, 300, 2600) * bell_env(0.45, 0.8) * 0.25, 0.04)),
        "rocket_in": lambda: mix(metal_slide(rng, 0.25, 600, 1.4) * 0.9, (metal_clack(rng, 0.6, 1.6, 1.6), 0.24)),
        "drum_turn": lambda: mix(metal_clack(rng, 1.0, 0.7, 0.4), (metal_clack(rng, 1.3, 0.5, 0.3) * 0.5, 0.04)),
        "grenade_in": lambda: mix(metal_slide(rng, 0.06, 900, 1.4) * 0.6, (metal_clack(rng, 0.7, 1.2, 1.2), 0.05)),
        "rail_vent": lambda: mix(hp(noise(rng, 0.5), 2500) * bell_env(0.5, 0.1, 1.5) * 0.5,
                                 (glide(0.4, 2600, 600) * env(0.4, 0.15) * 0.15, 0.0)),
        "dry_click": lambda: mix(click(rng, 0.01, 0.0004, 3500) * 0.8,
                                 metal_clack(rng, 1.1, 0.4, 0.2),
                                 (metal_clack(rng, 0.8, 0.5, 0.3) * 0.5, 0.012)),
        "mag_out": lambda: mix(metal_clack(rng, 1.25, 0.6, 0.3), (metal_slide(rng, 0.09, 1800, 1.3), 0.01)),
        "mag_in": lambda: mix(metal_slide(rng, 0.06, 1600, 1.6) * 0.7, (metal_clack(rng, 0.85, 1.2, 1.2), 0.055)),
        "mag_out_rifle": lambda: mix(metal_clack(rng, 1.05, 0.7, 0.4), (metal_slide(rng, 0.12, 1400, 1.4), 0.015)),
        "mag_in_rifle": lambda: mix(metal_slide(rng, 0.08, 1300, 1.7) * 0.7, (metal_clack(rng, 0.72, 1.4, 1.5), 0.075),
                                    (metal_clack(rng, 1.3, 0.5, 0.2) * 0.4, 0.105)),
        "slide_back": lambda: mix(metal_slide(rng, 0.07, 2600, 1.5), (metal_clack(rng, 1.15, 0.7, 0.4) * 0.7, 0.06)),
        "slide_fwd": lambda: mix(metal_slide(rng, 0.03, 3000, 0.8) * 0.6, (metal_clack(rng, 0.95, 1.1, 1.0), 0.025)),
        "charge_back": lambda: mix(metal_slide(rng, 0.08, 2000, 1.6), (metal_clack(rng, 1.0, 0.8, 0.5) * 0.7, 0.07)),
        "charge_fwd": lambda: mix(metal_slide(rng, 0.03, 2600, 0.8) * 0.6, (metal_clack(rng, 0.8, 1.3, 1.3), 0.025)),
        "pump_back": lambda: mix(metal_slide(rng, 0.09, 900, 2.2) * 1.1, (metal_clack(rng, 0.7, 1.3, 1.2), 0.08)),
        "pump_fwd": lambda: mix(metal_slide(rng, 0.07, 1500, 0.6) * 0.9, (metal_clack(rng, 0.62, 1.6, 1.5), 0.065)),
        "shell_in": lambda: mix(metal_slide(rng, 0.05, 1100, 1.5) * 0.6,
                                (metal_clack(rng, 0.75, 0.9, 0.8), 0.045),
                                (metal_clack(rng, 1.4, 0.5, 0.6) * 0.5, 0.06)),
        "bolt_up": lambda: metal_clack(rng, 1.2, 0.6, 0.3),
        "bolt_back": lambda: mix(metal_slide(rng, 0.13, 1700, 1.5), (metal_clack(rng, 0.9, 1.0, 0.6) * 0.8, 0.12)),
        "bolt_fwd": lambda: mix(metal_slide(rng, 0.11, 2300, 0.7), (metal_clack(rng, 0.78, 1.3, 1.2), 0.1)),
        "bolt_down": lambda: metal_clack(rng, 1.0, 0.9, 0.8),
    }
    return finish(s[name]())


def equip(name):
    """Bringing the gun up (on spawn, or picking it in a menu): a whoosh and a latch."""
    rng = np.random.default_rng(4000 + (list(GUNS) + list(SPECIAL_FIRE)).index(name))
    whoosh = sweep_bp(noise(rng, 0.22), 500, 2200, 1.5) * bell_env(0.22, 0.55, 1.5) * 0.6
    parts = [whoosh, (metal_clack(rng, 1.0, 0.8, 0.6) * 0.8, 0.17)]
    if name == "pistol":
        parts += [(metal_slide(rng, 0.05, 2600, 1.5) * 0.7, 0.24), (metal_clack(rng, 0.95, 1.1, 1.0), 0.29)]
    elif name == "rifle":
        parts += [(metal_slide(rng, 0.07, 2000, 1.6) * 0.7, 0.25), (metal_clack(rng, 0.8, 1.3, 1.3), 0.33)]
    elif name == "shotgun":
        parts += [(metal_slide(rng, 0.08, 900, 2.2), 0.24), (metal_clack(rng, 0.7, 1.3, 1.2), 0.32),
                  (metal_slide(rng, 0.06, 1500, 0.6) * 0.8, 0.40), (metal_clack(rng, 0.62, 1.6, 1.5), 0.46)]
    elif name in ("revolver",):
        parts += [(metal_clack(rng, 1.4, 0.5, 0.2) * 0.8, 0.24), (metal_clack(rng, 1.1, 0.8, 0.5), 0.3)]
    elif name in ("machine_pistol", "smg", "burst_rifle", "lmg"):
        parts += [(metal_slide(rng, 0.07, 2000, 1.6) * 0.7, 0.25), (metal_clack(rng, 0.8, 1.3, 1.3), 0.33)]
    elif name == "break_action":
        parts += [(metal_clack(rng, 0.65, 1.8, 1.8), 0.28)]
    elif name == "lever_action":
        parts += [(metal_slide(rng, 0.07, 1500, 1.5), 0.24), (metal_slide(rng, 0.06, 1900, 0.8) * 0.8, 0.36),
                  (metal_clack(rng, 0.8, 1.3, 1.2), 0.41)]
    elif name == "railgun":
        parts += [(glide(0.5, 300, 2600) * bell_env(0.5, 0.85) * 0.3, 0.2), (metal_clack(rng, 0.9, 1.1, 1.0), 0.22)]
    elif name in ("rocket_launcher", "grenade_launcher"):
        parts += [(metal_clack(rng, 0.6, 1.6, 1.6), 0.22), (metal_clack(rng, 1.0, 0.8, 0.5) * 0.5, 0.3)]
    else:
        parts += [(metal_clack(rng, 1.2, 0.6, 0.3) * 0.7, 0.25), (metal_slide(rng, 0.1, 2300, 0.7), 0.3),
                  (metal_clack(rng, 0.78, 1.3, 1.2), 0.4)]
    return finish(mix(*parts))


# ---------------------------------------------------------------------------
# Impacts and combat feedback

def impact_wall(seed):
    """A bullet striking concrete or steel: a hard snap, a puff of grit, sometimes a ping."""
    rng = np.random.default_rng(5000 + seed)
    snap = lp(hp(noise(rng, 0.05), 900), 5000) * env(0.05, 0.003, 0.0002) * 0.7
    body = bp(noise(rng, 0.15), rng.uniform(500, 850), 0.8) * env(0.15, 0.025) * 1.8
    thud = sat(sine_sweep(0.12, 200, 80, 0.01) * env(0.12, 0.015) * 1.4, 1.5) * 0.35
    debris = np.zeros(n(0.2))
    for _ in range(rng.integers(5, 10)):
        at = n(rng.uniform(0.008, 0.16))
        d = lp(click(rng, 0.008, 0.0006, 2000), 3500) * rng.uniform(0.1, 0.3)
        debris[at:at + len(d)] += d[: len(debris) - at]
    parts = [snap, body, thud, debris]
    if seed % 2 == 1:   # every other variant has a little metal in it
        parts.append(modal(rng, 0.25, [rng.uniform(1100, 1500), rng.uniform(2100, 2700)], [0.03, 0.02], [0.12, 0.06]))
    dry = mix(*parts)
    return finish(mix(dry, fftconv(lp(dry, 2000), room_ir(rng, 0.45, 2500)) * 0.2))


def ricochet(seed):
    """The whine of a round glancing off."""
    rng = np.random.default_rng(5500 + seed)
    length = 0.42
    f0, f1 = rng.uniform(1900, 2300), rng.uniform(800, 1000)
    t = tt(length)
    vib = 1 + 0.02 * np.sin(2 * math.pi * rng.uniform(25, 40) * t)
    f = (f0 * (f1 / f0) ** (t / length)) * vib
    whine = sweep_bp(noise(rng, length), f0, f1, 6.0) * 2.5 * env(length, 0.12, 0.004)   # noisy, not a pure tone
    hiss = bp(noise(rng, length), 1500, 1.5) * env(length, 0.08, 0.004) * 0.25
    return finish(mix(lp(click(rng, 0.03, 0.002, 1500), 4000) * 0.8, (whine * 0.35 + hiss, 0.005)))


def impact_body(seed):
    """A round hitting robot armour: a hard metallic tink over a dull thunk."""
    rng = np.random.default_rng(6000 + seed)
    k = rng.uniform(0.92, 1.08)
    ping = modal(rng, 0.35, [520 * k, 860 * k, 1370 * k, 2010 * k], [0.05, 0.035, 0.02, 0.012], [0.3, 0.25, 0.16, 0.08], 0.04)
    thunk = sine_sweep(0.2, 170, 70, 0.012) * env(0.2, 0.03) * 0.5
    crunch = bp(noise(rng, 0.08), 1100, 0.8) * env(0.08, 0.012, 0.0002) * 1.0
    sparks = lp(hp(noise(rng, 0.12) * (rng.uniform(0, 1, n(0.12)) > 0.95), 2500), 5000) * env(0.12, 0.03) * 0.2
    return finish(sat(mix(click(rng, 0.01, 0.0005, 2500), crunch, thunk, ping, (sparks, 0.01)), 1.5))


def whiz(seed):
    """A round passing close by your head: a sharp supersonic snap with a short zip."""
    rng = np.random.default_rng(6500 + seed)
    snap = lp(hp(noise(rng, 0.03), 1500), 6000) * env(0.03, 0.002, 0.0002)
    zip_ = sweep_bp(noise(rng, 0.14), rng.uniform(2600, 3200), rng.uniform(800, 1100), 2.5) * bell_env(0.14, 0.2, 1.5)
    return finish(mix(snap * 0.8, zip_))


def hitmarker():
    rng = np.random.default_rng(7000)
    # A dull metallic tick, like a round striking armour plate a long way off.
    tick = metal_clack(rng, 0.85, 0.7, 0.4)
    return finish(mix(tick, bp(noise(rng, 0.03), 1200, 1.0) * env(0.03, 0.004) * 0.5))


def hitmarker_head():
    rng = np.random.default_rng(7001)
    # A helmet "tink": a sharper strike with a short ring of hard steel.
    ring = modal(rng, 0.3, [1320, 2190, 3350], [0.07, 0.04, 0.02], [0.35, 0.2, 0.1], 0.02)
    return finish(mix(metal_clack(rng, 1.0, 0.8, 0.4), ring))


def kill_confirm(head=False):
    rng = np.random.default_rng(7100 + head)
    # A heavy, muted thunk with a low metallic ring: felt more than heard.
    thunk = sat(sine_sweep(0.35, 150, 55, 0.03) * env(0.35, 0.09, 0.001) * 1.3, 2.0)
    ring = modal(rng, 0.7, [392, 588, 931] if not head else [466, 699, 1108], [0.22, 0.14, 0.08], [0.3, 0.18, 0.1], 0.01)
    parts = [metal_clack(rng, 0.7, 1.0, 0.8) * 0.6, thunk, (ring, 0.02)]
    if head:
        parts.append((metal_clack(rng, 1.0, 0.9, 0.3) * 0.6, 0.0))
    return finish(mix(*parts))


def hurt(head=False):
    """You were shot: a punch you feel, a crunch of armour."""
    rng = np.random.default_rng(7200 + head)
    punch = sat(sine_sweep(0.3, 120, 42, 0.03) * env(0.3, 0.08, 0.001) * 1.5, 2.0)
    crunch = lp(noise(rng, 0.12), 2200) * env(0.12, 0.03, 0.0005) * 0.6
    rattle = modal(rng, 0.25, [740, 1210, 1860], [0.05, 0.035, 0.02], [0.3, 0.2, 0.12], 0.05)
    parts = [punch, crunch, rattle]
    if head:
        parts += [modal(rng, 0.6, [880, 1370], [0.12, 0.07], [0.2, 0.1]),
                  bp(noise(rng, 0.05), 1600, 1.0) * env(0.05, 0.006) * 0.5]
    return finish(mix(*parts))


def death():
    """A robot powering down: a falling electric whine, crackle and a final clunk."""
    rng = np.random.default_rng(7300)
    length = 1.0
    whine = lp(glide(length, 260, 35, "saw"), 700) * env(length, 0.3, 0.01) * 0.25
    crackle = lp(hp(noise(rng, 0.5) * (rng.uniform(0, 1, n(0.5)) > 0.98), 1500), 5000) * env(0.5, 0.12) * 0.4
    hit = sat(sine_sweep(0.3, 200, 50, 0.03) * env(0.3, 0.07), 2) * 0.9
    clatter = mix(*[(metal_clack(rng, rng.uniform(0.6, 0.9), 1.2, 1.0) * rng.uniform(0.3, 0.6), at) for at in (0.32, 0.45, 0.53)])
    return finish(mix(hit, crackle, whine, clatter))


def respawn():
    """Powering up: a rising shimmer that lands on a soft click."""
    rng = np.random.default_rng(7400)
    length = 0.6
    rise = lp(glide(length, 60, 240, "saw"), 600) * np.linspace(0, 1, n(length)) ** 2 * 0.25   # systems spinning up
    air = sweep_bp(noise(rng, length), 200, 1800, 1.5) * np.linspace(0, 1, n(length)) ** 2 * 0.4
    land = mix(metal_clack(rng, 0.7, 1.0, 1.0), sine_sweep(0.2, 140, 60, 0.02) * env(0.2, 0.04) * 0.6)
    return finish(mix(rise, air, (land, length), (click(rng) * 0.6, length)))


# ---------------------------------------------------------------------------
# Movement (robots: rubber-soled feet, servos, hydraulics)

def footstep(seed):
    """Soft rubber tread: a muffled, padded thump and a faint grippy scuff. Kept quiet
    and short so it never gets tiring, with no ringing metal."""
    rng = np.random.default_rng(9200 + seed)
    k = rng.uniform(0.9, 1.1)
    pad = sine_sweep(0.12, 95 * k, 55, 0.015) * env(0.12, 0.025, 0.002) * 0.9
    body = lp(noise(rng, 0.1), 380 * k) * env(0.1, 0.018, 0.002) * 1.1
    scuff = bp(noise(rng, 0.09), 1700 * k, 0.8) * bell_env(0.09, 0.25, 1.6) * 0.09
    toe = lp(noise(rng, 0.05), 500) * env(0.05, 0.01, 0.001) * 0.4
    return finish(mix(pad, body, (scuff, 0.01), (toe, 0.06)))


def land(hard=False):
    rng = np.random.default_rng(8100 + hard)
    w = 1.6 if hard else 1.0
    thud = sat(sine_sweep(0.4, 160, 40, 0.025) * env(0.4, 0.07 * w, 0.001) * 1.4, 2.0)
    plate = modal(rng, 0.5, [310, 540, 870, 1340], [0.06 * w, 0.045 * w, 0.03, 0.015], [0.3, 0.25, 0.16, 0.08], 0.04)
    plate += lp(noise(rng, 0.5), 700) * env(0.5, 0.05 * w, 0.001) * 0.8
    hiss = bp(noise(rng, 0.3), 1800, 0.8) * env(0.3, 0.06, 0.02) * 0.12 * w    # the shock absorbers
    debris = np.zeros(n(0.3))
    for _ in range(10 if hard else 4):
        at = n(rng.uniform(0.01, 0.22))
        d = click(rng, 0.01, 0.0008, 1500) * rng.uniform(0.1, 0.25)
        debris[at:at + len(d)] += d[: len(debris) - at]
    return finish(mix(click(rng, 0.008, 0.0006, 2500) * 0.6, thud, plate, (hiss, 0.03), debris))


def servo(rng, seconds, f0, f1, level=0.3):
    """An electric motor whirring from f0 to f1: a low, muffled hum under the movement."""
    w = lp(glide(seconds, f0 * 0.5, f1 * 0.5, "saw"), 900) * 0.6
    return w * bell_env(seconds, 0.25, 1.0) * level * 0.35


def whoosh(rng, seconds, f0=500, f1=2500, q=1.3, at=0.45):
    """Air rushing past: a broad band of noise gliding up (kept low, like real air)."""
    return sweep_bp(noise(rng, seconds), f0 * 0.5, f1 * 0.45, q * 0.8) * bell_env(seconds, at, 1.6)


def jump():
    rng = np.random.default_rng(8200)
    push = sine_sweep(0.12, 180, 80, 0.015) * env(0.12, 0.03) * 0.6
    hiss = hp(noise(rng, 0.16), 2500) * env(0.16, 0.04, 0.004) * 0.15
    return finish(mix(click(rng, 0.006, 0.0005, 3000) * 0.4, push,
                      metal_clack(rng, 0.6, 1.0, 0.8) * 0.5,
                      hiss, servo(rng, 0.14, 380, 820, 0.25), whoosh(rng, 0.22, 600, 1800) * 0.35))


def double_jump_flip():
    """A flip: a fast spinning whoosh and a servo spin-up."""
    rng = np.random.default_rng(8300)
    w = whoosh(rng, 0.42, 300, 3200, 1.6, 0.5)
    spin = servo(rng, 0.38, 300, 1100, 0.2)
    return finish(mix(click(rng, 0.006, 0.0005, 3000) * 0.3, w, spin))


def dive():
    rng = np.random.default_rng(8400)
    thrust = lp(noise(rng, 0.35), 900) * bell_env(0.35, 0.15, 1.2) * 0.6
    return finish(mix(whoosh(rng, 0.38, 250, 2400, 1.2, 0.3), thrust, servo(rng, 0.25, 260, 640, 0.18),
                      sine_sweep(0.15, 170, 70, 0.02) * env(0.15, 0.035) * 0.5))


def scrape(rng, seconds, centre, rough=0.75, rumble=0.5):
    """Metal dragging along the ground, with the odd spark."""
    grit = noise(rng, seconds) * (rng.uniform(0, 1, n(seconds)) > rough)
    am = 0.7 + 0.3 * lp(rng.uniform(-1, 1, n(seconds)), 30) * 8
    s = bp(grit, centre * 0.5, 1.0) * am
    s += lp(noise(rng, seconds), 220) * rumble * 1.5
    s += lp(hp(noise(rng, seconds) * (rng.uniform(0, 1, n(seconds)) > 0.99), 3000), 6000) * 0.12
    return s


def slide():
    rng = np.random.default_rng(8500)
    length = 0.85
    body = scrape(rng, length, 1900) * np.concatenate([np.linspace(0, 1, n(0.03)), np.ones(n(0.35)),
                                                       np.linspace(1, 0, n(length) - n(0.03) - n(0.35)) ** 1.5])
    return finish(mix(metal_clack(rng, 0.7, 1.0, 1.2) * 0.7, body * 0.8))


def belly_slide():
    rng = np.random.default_rng(8600)
    length = 1.1
    body = scrape(rng, length, 1200, 0.7, 0.8) * np.concatenate([np.linspace(0, 1, n(0.03)), np.ones(n(0.45)),
                                                                   np.linspace(1, 0, n(length) - n(0.03) - n(0.45)) ** 1.5])
    hit = sat(sine_sweep(0.3, 140, 45, 0.02) * env(0.3, 0.06) * 1.3, 2)
    return finish(mix(hit, modal(rng, 0.4, [280, 490, 820], [0.06, 0.04, 0.025], [0.3, 0.2, 0.1]), body * 0.8))


def crawl(seed):
    rng = np.random.default_rng(8650 + seed)
    return finish(mix(scrape(rng, 0.22, 1400, 0.8, 0.3) * bell_env(0.22, 0.3, 1.2),
                      (metal_clack(rng, 0.65, 0.8, 0.8) * 0.35, 0.02)))


def roll():
    rng = np.random.default_rng(8700)
    clunks = [(sat(sine_sweep(0.2, 150, 55, 0.015) * env(0.2, 0.04), 1.5) * g + modal(rng, 0.2, [340, 590, 960], [0.03, 0.02, 0.012], [0.22, 0.16, 0.08]) * g, at)
              for at, g in ((0.0, 1.0), (0.13, 0.75), (0.27, 0.55))]
    tumble = scrape(rng, 0.45, 1500, 0.8, 0.35) * bell_env(0.45, 0.3, 1.2) * 0.6
    return finish(mix(*clunks, whoosh(rng, 0.4, 400, 1600, 1.2, 0.35) * 0.5, tumble))


def wall_run_start():
    """Magnetic feet catching the wall: a clamp and an electric buzz."""
    rng = np.random.default_rng(8800)
    buzz = lp(glide(0.12, 70, 60, "square"), 500) * env(0.12, 0.04, 0.003) * 0.12
    return finish(mix(metal_clack(rng, 0.85, 1.4, 1.1), (buzz, 0.005), servo(rng, 0.16, 500, 900, 0.15)))


def wall_jump():
    rng = np.random.default_rng(8900)
    kick = mix(sat(sine_sweep(0.2, 180, 65, 0.015) * env(0.2, 0.05) * 1.3, 2.0), metal_clack(rng, 0.8, 1.2, 1.0) * 0.8)
    return finish(mix(kick, (whoosh(rng, 0.3, 500, 2600, 1.4, 0.35) * 0.6, 0.02), servo(rng, 0.14, 420, 900, 0.2)))


def vault():
    rng = np.random.default_rng(9000)
    hand = metal_clack(rng, 0.9, 1.0, 0.9) * 0.8
    return finish(mix(hand, (whoosh(rng, 0.3, 450, 2000, 1.3, 0.4) * 0.6, 0.02), servo(rng, 0.2, 350, 700, 0.15)))


def ledge_climb():
    rng = np.random.default_rng(9100)
    grab = metal_clack(rng, 0.85, 1.2, 1.0)
    strain = servo(rng, 0.38, 220, 520, 0.28)
    top = mix(sine_sweep(0.15, 160, 70, 0.015) * env(0.15, 0.03) * 0.6, metal_clack(rng, 0.7, 0.9, 0.8) * 0.5)
    return finish(mix(grab, (strain, 0.04), (top, 0.4)))


def crouch(down=True):
    rng = np.random.default_rng(9200 + down)
    f0, f1 = (700, 380) if down else (380, 720)
    return finish(mix(servo(rng, 0.14, f0, f1, 0.4), (metal_clack(rng, 0.75, 0.6, 0.6) * 0.35, 0.1 if down else 0.0)))


def grapple_fire():
    rng = np.random.default_rng(9300)
    pop = mix(lp(noise(rng, 0.08), 1200) * env(0.08, 0.012, 0.0005), sine_sweep(0.1, 220, 80, 0.01) * env(0.1, 0.025) * 0.8)
    cable = sweep_bp(noise(rng, 0.32), 900, 2600, 2.0) * env(0.32, 0.12, 0.004) * 0.6
    ticks = np.zeros(n(0.3))
    at = 0.02
    gap = 0.03
    while at < 0.28:
        c = click(rng, 0.004, 0.0004, 2500) * 0.18
        k = n(at)
        ticks[k:k + len(c)] += c[: len(ticks) - k]
        at += gap
        gap = max(gap * 0.85, 0.009)
    return finish(mix(click(rng, 0.008, 0.0005, 2500) * 0.7, pop, (cable, 0.01), ticks))


def grapple_attach():
    rng = np.random.default_rng(9400)
    bite = metal_clack(rng, 0.9, 1.2, 1.0)
    tension = sweep_bp(noise(rng, 0.2), 500, 220, 3.0) * env(0.2, 0.06) * 0.4
    return finish(mix(click(rng, 0.006, 0.0004, 3000), bite, sine_sweep(0.12, 300, 120, 0.01) * env(0.12, 0.02) * 0.6, tension))


def grapple_release():
    rng = np.random.default_rng(9500)
    unhook = metal_clack(rng, 1.15, 0.6, 0.4) * 0.6
    reel = sweep_bp(noise(rng, 0.26), 2400, 800, 2.0) * bell_env(0.26, 0.2, 1.2) * 0.6
    whirr = servo(rng, 0.24, 1400, 600, 0.14)
    return finish(mix(unhook, (reel, 0.01), (whirr, 0.01), (metal_clack(rng, 0.9, 0.7, 0.6) * 0.5, 0.25)))


def grapple_miss():
    rng = np.random.default_rng(9600)
    out = sweep_bp(noise(rng, 0.25), 900, 2600, 2.0) * env(0.25, 0.1, 0.004) * 0.5
    back = sweep_bp(noise(rng, 0.22), 2400, 800, 2.0) * bell_env(0.22, 0.3, 1.2) * 0.5
    return finish(mix(lp(noise(rng, 0.06), 1200) * env(0.06, 0.01) * 0.6, out, (back, 0.24),
                      (metal_clack(rng, 0.95, 0.6, 0.5) * 0.5, 0.45)))


# ---------------------------------------------------------------------------
# Menus and match flow

def tone(f, seconds, tau, partials=((1, 1.0), (2, 0.18), (3, 0.06))):
    t = tt(seconds)
    f *= 0.5   # recipes give the old, brighter pitches
    return sum(a * np.sin(2 * math.pi * f * m * t) * np.exp(-t / (tau / m)) for m, a in partials) * np.clip(t / 0.002, 0, 1)


def ui(name):
    rng = np.random.default_rng(9800)
    if name == "ui_hover":
        return finish(mix(click(rng, 0.004, 0.0003, 5000) * 0.4, tone(2400, 0.05, 0.008) * 0.5))
    if name == "ui_click":
        return finish(mix(click(rng, 0.006, 0.0005, 3500) * 0.8, tone(1480, 0.12, 0.025) * 0.6, tone(740, 0.12, 0.03) * 0.4))
    if name == "ui_confirm":
        return finish(mix(click(rng, 0.006, 0.0005, 3500) * 0.6, tone(987.8, 0.3, 0.08) * 0.5, (tone(1480, 0.4, 0.12) * 0.55, 0.06)))
    if name == "ui_back":
        return finish(mix(click(rng, 0.006, 0.0005, 3500) * 0.6, tone(1174.7, 0.3, 0.06) * 0.5, (tone(784, 0.35, 0.09) * 0.5, 0.055)))
    if name == "ui_toggle":
        return finish(mix(click(rng, 0.006, 0.0005, 3000) * 0.7, tone(1975, 0.1, 0.02) * 0.45,
                          (metal_clack(rng, 1.6, 0.3, 0.1) * 0.3, 0.0)))
    if name == "ui_tick":
        return finish(mix(click(rng, 0.003, 0.0002, 6000) * 0.4, tone(3300, 0.03, 0.004) * 0.6))
    if name == "ui_select":
        return finish(mix(metal_clack(rng, 0.9, 0.8, 0.7) * 0.6, tone(1318.5, 0.3, 0.07) * 0.4, (tone(1975.5, 0.3, 0.08) * 0.3, 0.04)))
    raise ValueError(name)


def match_start():
    """A short riser into a punchy hit on a ringing steel plate (an effect, not music)."""
    rng = np.random.default_rng(9900)
    rise_len = 0.7
    ramp = np.linspace(0, 1, n(rise_len)) ** 2.5
    riser = sweep_bp(noise(rng, rise_len), 150, 2500, 1.5, 0.8) * ramp * 0.6
    boom = sat(sine_sweep(0.9, 140, 38, 0.04) * env(0.9, 0.22, 0.001) * 1.6, 2.2)
    chord = modal(rng, 1.4, [612, 1043, 1690, 2475], [0.4, 0.3, 0.2, 0.12], [0.22, 0.18, 0.12, 0.08])   # a struck steel plate, not a chord
    crash = bp(noise(rng, 1.0), 1500, 0.7) * env(1.0, 0.15, 0.001) * 0.3
    hit = mix(click(rng, 0.01, 0.0006, 2000), boom, chord, crash)
    tail = fftconv(lp(hit, 4000), room_ir(rng, 1.4)) * 0.25
    return finish(mix(riser, (mix(hit, tail), rise_len)))


def match_end():
    rng = np.random.default_rng(9950)
    boom = sat(sine_sweep(1.0, 120, 35, 0.05) * env(1.0, 0.3, 0.001) * 1.5, 2.0)
    chord = modal(rng, 2.0, [418, 731, 1187, 1802], [0.6, 0.45, 0.3, 0.18], [0.2, 0.16, 0.1, 0.06])
    hit = mix(click(rng, 0.01, 0.0006, 2000), boom, chord, bp(noise(rng, 1.2), 1300, 0.7) * env(1.2, 0.2) * 0.3)
    return finish(mix(hit, fftconv(lp(hit, 3500), room_ir(rng, 1.8)) * 0.3))


# ---------------------------------------------------------------------------
# Melee: swings, blows, crashing into walls

MELEE = ["sword", "hammer", "dagger", "brass_knuckles", "spear", "axe", "bat"]


def swing(name):
    """A blade or hammer cutting the air: a fast whoosh (deeper and longer for the hammer) and a servo."""
    rng = np.random.default_rng(9100 + MELEE.index(name))
    if name == "brass_knuckles":
        return finish(mix(whoosh(rng, 0.13, 600, 2800, 1.6, 0.4), servo(rng, 0.09, 600, 1100, 0.18)))
    if name == "spear":
        return finish(mix(whoosh(rng, 0.22, 700, 3800, 2.2, 0.55) * 1.1, servo(rng, 0.14, 420, 900, 0.15)))
    if name == "axe":
        w = whoosh(rng, 0.36, 260, 2000, 1.2, 0.6) * 1.1
        return finish(mix(servo(rng, 0.24, 260, 640, 0.2), w, lp(noise(rng, 0.36), 600) * bell_env(0.36, 0.6, 1.4) * 0.4))
    if name == "bat":
        w = whoosh(rng, 0.34, 220, 1700, 1.0, 0.62) * 1.2
        return finish(mix(servo(rng, 0.22, 240, 600, 0.2), w, lp(noise(rng, 0.34), 450) * bell_env(0.34, 0.6, 1.4) * 0.6))
    if name == "hammer":
        w = whoosh(rng, 0.42, 160, 1300, 1.0, 0.65) * 1.2
        body = lp(noise(rng, 0.42), 380) * bell_env(0.42, 0.6, 1.4) * 0.7
        return finish(mix(servo(rng, 0.3, 200, 520, 0.22), w, body))
    if name == "dagger":
        return finish(mix(whoosh(rng, 0.16, 900, 4200, 1.8, 0.45), servo(rng, 0.1, 500, 900, 0.12)))
    ring = modal(rng, 0.3, [2950, 4400], [0.05, 0.03], [0.05, 0.03])
    return finish(mix(whoosh(rng, 0.26, 500, 3600, 1.5, 0.5) * 1.1, servo(rng, 0.16, 360, 800, 0.15), (ring, 0.05)))


def melee_hit(seed):
    """A blade striking robot armour: a hard metal clang with a crunch under it."""
    rng = np.random.default_rng(9200 + seed)
    k = rng.uniform(0.9, 1.1)
    clang = modal(rng, 0.5, [410 * k, 790 * k, 1310 * k, 2240 * k, 3500 * k], [0.09, 0.06, 0.04, 0.025, 0.015],
                  [0.35, 0.3, 0.2, 0.12, 0.06], 0.03)
    crunch = bp(noise(rng, 0.12), 1500, 0.7) * env(0.12, 0.018, 0.0002) * 1.1
    thud = sat(sine_sweep(0.25, 150, 55, 0.02) * env(0.25, 0.05) * 1.2, 1.6) * 0.7
    dry = sat(mix(click(rng, 0.01, 0.0005, 3000), crunch, thud, clang), 1.4)
    return finish(mix(dry, fftconv(lp(dry, 3000), room_ir(rng, 0.5, 3000)) * 0.18))


def hammer_hit():
    """The hammer landing: a heavy, low metal crash."""
    rng = np.random.default_rng(9300)
    boom = sat(sine_sweep(0.5, 110, 40, 0.04) * env(0.5, 0.12, 0.001) * 1.8, 2.2)
    clang = modal(rng, 0.6, [260, 520, 870, 1450], [0.12, 0.08, 0.05, 0.03], [0.35, 0.25, 0.15, 0.08], 0.05)
    crunch = bp(noise(rng, 0.2), 900, 0.6) * env(0.2, 0.04, 0.0003) * 1.4
    dry = mix(click(rng, 0.012, 0.0008, 2000), boom, crunch, clang)
    return finish(mix(dry, fftconv(lp(dry, 2500), room_ir(rng, 0.7, 2500)) * 0.25))


def slam(seed):
    """A robot crashing into a wall: a heavy body thump, buckling metal and debris."""
    rng = np.random.default_rng(9400 + seed)
    thump = sat(sine_sweep(0.45, 95, 38, 0.05) * env(0.45, 0.1, 0.001) * 2.0, 2.5)
    buckle = mix(metal_clack(rng, 0.55, 2.0, 1.5), (metal_clack(rng, 0.8, 1.5, 0.8) * 0.6, 0.03))
    debris = np.zeros(n(0.5))
    for _ in range(rng.integers(8, 14)):
        at = n(rng.uniform(0.02, 0.4))
        d = lp(click(rng, 0.01, 0.0008, 1800), 3000) * rng.uniform(0.1, 0.35)
        debris[at:at + len(d)] += d[: len(debris) - at]
    grit = bp(noise(rng, 0.4), 700, 0.6) * env(0.4, 0.08, 0.001) * 1.2
    dry = mix(thump, buckle, grit, debris)
    return finish(mix(dry, fftconv(lp(dry, 2200), room_ir(rng, 0.8, 2200)) * 0.25))


def break_sound(mat, seed):
    """A piece of wall or floor giving way: concrete crumbles with a deep crack and a
    rattle of chunks, wood splinters and clatters, glass shatters and tinkles down."""
    rng = np.random.default_rng(9700 + seed + {"concrete": 0, "wood": 10, "glass": 20}[mat])
    length = 1.1 if mat != "glass" else 1.3
    debris = np.zeros(n(length))
    pieces = {"concrete": (14, 22), "wood": (10, 16), "glass": (26, 40)}[mat]
    for _ in range(rng.integers(*pieces)):
        at = n(rng.uniform(0.02, length * 0.75) ** 1.4 / length ** 0.4)
        if mat == "glass":
            d = modal(rng, 0.25, [rng.uniform(2500, 4200), rng.uniform(5000, 7500)], [0.04, 0.03], [0.05, 0.03]) * rng.uniform(0.15, 0.45)
        elif mat == "wood":
            d = bp(click(rng, 0.03, 0.002, 900), rng.uniform(500, 1100), 1.2) * rng.uniform(0.2, 0.6)
        else:
            d = lp(click(rng, 0.02, 0.0012, 1400), 2600) * rng.uniform(0.2, 0.55)
        debris[at:at + len(d)] += d[: len(debris) - at]
    if mat == "glass":
        crack = hp(noise(rng, 0.08), 2500) * env(0.08, 0.002, 0.0001) * 1.2
        body = modal(rng, 0.7, [1800, 3100, 4700, 6900], [0.2, 0.15, 0.1, 0.06], [0.3, 0.2, 0.12, 0.06], 0.01)
        dry = mix(crack, body, debris)
    elif mat == "wood":
        crack = bp(noise(rng, 0.12), 1400, 0.9) * env(0.12, 0.004, 0.0003) * 1.6
        groan = sat(sine_sweep(0.35, 160, 70, 0.02) * env(0.35, 0.08) * 1.4, 1.6) * 0.5
        dry = mix(crack, groan, debris)
    else:
        boom = sat(sine_sweep(0.7, 90, 32, 0.03) * env(0.7, 0.18, 0.001) * 2.0, 2.4)
        crack = lp(hp(noise(rng, 0.1), 600), 4500) * env(0.1, 0.003, 0.0002) * 1.3
        grit = bp(noise(rng, 0.9), 650, 0.5) * env(0.9, 0.3, 0.002) * 0.9
        dry = mix(boom, crack, grit, debris)
    return finish(mix(dry, fftconv(lp(dry, 2400), room_ir(rng, 0.9, 2400)) * 0.3))


def bat_hit():
    """The bat on robot armour: a hollow "tonk" with a thick knock."""
    rng = np.random.default_rng(9310)
    knock = sat(sine_sweep(0.4, 180, 70, 0.03) * env(0.4, 0.07, 0.0008) * 1.7, 2.0)
    hollow = modal(rng, 0.5, [340, 610, 1020, 1700], [0.08, 0.05, 0.03, 0.02], [0.35, 0.25, 0.12, 0.06], 0.04)
    crack = bp(noise(rng, 0.1), 2200, 0.8) * env(0.1, 0.01, 0.0002) * 0.9
    dry = mix(click(rng, 0.01, 0.0006, 2500), knock, hollow, crack)
    return finish(mix(dry, fftconv(lp(dry, 2500), room_ir(rng, 0.6, 2500)) * 0.2))


def punch_hit(seed):
    """Brass knuckles on armour: a tight smack and a short dull clank."""
    rng = np.random.default_rng(9320 + seed)
    smack = bp(noise(rng, 0.1), 1800, 0.7) * env(0.1, 0.012, 0.0002) * 1.2
    thud = sat(sine_sweep(0.25, 170, 60, 0.02) * env(0.25, 0.04) * 1.3, 1.8)
    clank = modal(rng, 0.3, [600, 1150, 1900], [0.04, 0.03, 0.02], [0.25, 0.15, 0.08], 0.05)
    dry = mix(click(rng, 0.008, 0.0005, 3000), smack, thud, clank)
    return finish(mix(dry, fftconv(lp(dry, 3000), room_ir(rng, 0.4, 3000)) * 0.15))


def equip_melee(name):
    """Drawing a blade or hefting the hammer: a whoosh and a ring of steel (a clunk for the hammer)."""
    rng = np.random.default_rng(9500 + MELEE.index(name))
    if name == "brass_knuckles":
        return finish(mix(metal_clack(rng, 1.2, 0.6, 0.3), (metal_clack(rng, 1.25, 0.6, 0.3) * 0.8, 0.07),
                          (servo(rng, 0.15, 500, 900, 0.15), 0.0)))
    if name in ("axe", "bat"):
        w = sweep_bp(noise(rng, 0.22), 400, 1800, 1.5) * bell_env(0.22, 0.55, 1.5) * 0.5
        return finish(mix(w, (metal_clack(rng, 0.55 if name == "axe" else 0.45, 1.5, 1.4) * 0.9, 0.18)))
    draw = metal_slide(rng, 0.28 if name == "sword" else 0.16, 3200, 1.6) * 0.8
    w = sweep_bp(noise(rng, 0.22), 500, 2200, 1.5) * bell_env(0.22, 0.55, 1.5) * 0.5
    if name == "hammer":
        return finish(mix(w, (metal_clack(rng, 0.5, 1.8, 1.6), 0.18), (metal_clack(rng, 0.7, 1.2, 0.8) * 0.5, 0.24)))
    ring = modal(rng, 0.6, [2400, 3600, 5100], [0.15, 0.1, 0.06], [0.12, 0.08, 0.05])
    return finish(mix(draw, (w, 0.05), (ring, 0.2 if name == "sword" else 0.12)))


def kick():
    """A front kick: a short, low whoosh with a servo snap and a stamp of the knee joint."""
    rng = np.random.default_rng(9600)
    w = whoosh(rng, 0.2, 300, 1900, 1.4, 0.4)
    snap = servo(rng, 0.12, 420, 980, 0.25)
    joint = metal_clack(rng, 0.7, 0.8, 0.9) * 0.35
    return finish(mix(w, snap, (joint, 0.02)))


def flying_kick():
    """Launching a flying kick: a rising rush of air and a hard servo lock."""
    rng = np.random.default_rng(9610)
    w = whoosh(rng, 0.5, 220, 2600, 1.2, 0.35) * 1.1
    body = lp(noise(rng, 0.5), 500) * bell_env(0.5, 0.3, 1.3) * 0.5
    lock = metal_clack(rng, 0.6, 1.4, 1.2) * 0.5
    return finish(mix(w, body, servo(rng, 0.3, 300, 1200, 0.25), (lock, 0.05)))


def rocket_boost():
    """Rocket boots: a sharp ignition pop, then a short roaring jet that dies away."""
    rng = np.random.default_rng(9700)
    pop = sat(sine_sweep(0.12, 160, 60, 0.02) * env(0.12, 0.03) * 1.4, 1.8)
    roar = lp(noise(rng, 0.6), 1400) * bell_env(0.6, 0.12, 1.1) * 1.0
    hiss = sweep_bp(noise(rng, 0.55), 2600, 900, 1.2) * bell_env(0.55, 0.15, 1.4) * 0.5
    rumble = lp(noise(rng, 0.6), 180) * bell_env(0.6, 0.2, 1.2) * 0.9
    return finish(mix(click(rng, 0.008, 0.0006, 2500) * 0.5, pop, sat(roar, 1.5), hiss, rumble))


def float_spin():
    """Floating: the legs snap out and start to turn. A servo spins up, then the air
    beats softly as each leg comes round, thinning out over a second."""
    rng = np.random.default_rng(9750)
    d = 1.3
    t = tt(d)
    hold = np.clip(t / 0.08, 0.0, 1.0) * np.exp(-t / 0.5)
    beat = 0.5 + 0.5 * np.sin(2 * math.pi * 2.2 * t) ** 2   # two legs, a turn every 0.9 s
    air = sweep_bp(noise(rng, d), 350, 900, 1.0) * hold * beat * 0.9
    return finish(mix(click(rng, 0.006, 0.0005, 3000) * 0.3, whoosh(rng, 0.3, 400, 2200, 1.3, 0.3) * 0.7, air,
                      servo(rng, 0.7, 260, 700, 0.3), metal_clack(rng, 0.5, 1.0, 0.7) * 0.35))


# ---------------------------------------------------------------------------

def recipes():
    r = {}
    for g in GUNS:
        r["fire_" + g] = lambda g=g: gun_fire(g)
        r["fire_%s_fp" % g] = lambda g=g: gun_fire(g, stereo=True, seed=7)
        r["far_" + g] = lambda g=g: gun_far(g)
        r["equip_" + g] = lambda g=g: equip(g)
    for g, make in SPECIAL_FIRE.items():
        r["fire_" + g] = lambda make=make: make()
        r["fire_%s_fp" % g] = lambda make=make: make(stereo=True, seed=7)
        r["far_" + g] = lambda g=g: special_far(g)
        r["equip_" + g] = lambda g=g: equip(g)
    for i in range(2):
        r["explosion_%d" % (i + 1)] = lambda i=i: explosion(i)
    r["explosion_far"] = lambda: explosion(5, far=True)
    for i, h in enumerate(["dry_click", "mag_out", "mag_in", "mag_out_rifle", "mag_in_rifle", "slide_back",
                           "slide_fwd", "charge_back", "charge_fwd", "pump_back", "pump_fwd", "shell_in",
                           "bolt_up", "bolt_back", "bolt_fwd", "bolt_down"]):
        r[h] = lambda h=h, i=i: handling(h, np.random.default_rng(4500 + i))
    for i, h in enumerate(["cylinder_open", "cylinder_close", "empties_out", "speedloader", "break_open",
                           "break_close", "shells_in", "lever_down", "lever_up", "cover_open", "cover_close",
                           "box_out", "box_in", "cell_out", "cell_in", "rocket_in", "drum_turn", "grenade_in",
                           "rail_vent"]):
        r[h] = lambda h=h, i=i: handling(h, np.random.default_rng(4600 + i))
    for i in range(4):
        r["impact_wall_%d" % (i + 1)] = lambda i=i: impact_wall(i)
    for i in range(2):
        r["ricochet_%d" % (i + 1)] = lambda i=i: ricochet(i)
    for i in range(3):
        r["impact_body_%d" % (i + 1)] = lambda i=i: impact_body(i)
        r["whiz_%d" % (i + 1)] = lambda i=i: whiz(i)
    r["hitmarker"] = hitmarker
    r["hitmarker_head"] = hitmarker_head
    r["kill"] = lambda: kill_confirm(False)
    r["kill_head"] = lambda: kill_confirm(True)
    r["hurt"] = lambda: hurt(False)
    r["hurt_head"] = lambda: hurt(True)
    r["death"] = death
    r["respawn"] = respawn
    for i in range(6):
        r["step_%d" % (i + 1)] = lambda i=i: footstep(i)
    for i in range(3):
        r["crawl_%d" % (i + 1)] = lambda i=i: crawl(i)
    r["jump"] = jump
    r["land"] = lambda: land(False)
    r["land_hard"] = lambda: land(True)
    r["flip"] = double_jump_flip
    r["dive"] = dive
    r["roll"] = roll
    r["slide"] = slide
    r["belly_slide"] = belly_slide
    r["wall_run"] = wall_run_start
    r["wall_jump"] = wall_jump
    r["vault"] = vault
    r["ledge_climb"] = ledge_climb
    r["crouch"] = lambda: crouch(True)
    r["stand"] = lambda: crouch(False)
    r["grapple_fire"] = grapple_fire
    r["grapple_attach"] = grapple_attach
    r["grapple_release"] = grapple_release
    r["grapple_miss"] = grapple_miss
    for u in ["ui_hover", "ui_click", "ui_confirm", "ui_back", "ui_toggle", "ui_tick", "ui_select"]:
        r[u] = lambda u=u: ui(u)
    r["match_start"] = match_start
    r["match_end"] = match_end
    for m in MELEE:
        r["swing_" + m] = lambda m=m: swing(m)
        r["equip_" + m] = lambda m=m: equip_melee(m)
    r["bat_hit"] = bat_hit
    for i in range(2):
        r["punch_hit_%d" % (i + 1)] = lambda i=i: punch_hit(i)
    for i in range(3):
        r["melee_hit_%d" % (i + 1)] = lambda i=i: melee_hit(i)
    r["hammer_hit"] = hammer_hit
    r["kick"] = kick
    r["flying_kick"] = flying_kick
    r["rocket_boost"] = rocket_boost
    r["float"] = float_spin
    for i in range(2):
        r["slam_%d" % (i + 1)] = lambda i=i: slam(i)
    for mat in ["concrete", "wood", "glass"]:
        for i in range(2):
            r["break_%s_%d" % (mat, i + 1)] = lambda mat=mat, i=i: break_sound(mat, i)
    return r


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    for name, make in recipes().items():
        if not name.startswith(only):
            continue
        x = make()
        if not np.all(np.isfinite(x)):
            raise ValueError(name + ": not finite")
        write(name, x)
        print("%-18s %.2f s%s" % (name, len(x) / SR, "  stereo" if x.ndim == 2 else ""))


if __name__ == "__main__":
    main()
