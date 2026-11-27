#!/usr/bin/env python3
"""Synthesises the placeholder ship sounds into assets/audio/*.wav (22.05 kHz mono 16-bit).
Original synthesis, no samples: replace any file with a real recording of the same name and
the game picks it up. Loops are built to be seamless. Run: python3 tools/gen_audio.py"""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)


def write(name, samples, peak=0.9):
    m = max(1e-9, max(abs(s) for s in samples))
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s / m * peak)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)


def noise(n, seed):
    r = random.Random(seed)
    return [r.uniform(-1, 1) for _ in range(n)]


def lowpass(x, a):
    y, out = 0.0, []
    for v in x:
        y += a * (v - y); out.append(y)
    return out


def seamless(x, fade):
    """Crossfade the tail into the head so the loop point is inaudible."""
    n = len(x) - fade
    out = x[:n]
    for i in range(fade):
        t = i / fade
        out[i] = x[i] * t + x[n + i] * (1 - t)
    return out


def env_note(freq, dur, kind="sine", decay=6.0, vib=0.0):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        f = freq * (1 + vib * math.sin(2 * math.pi * 5 * t))
        ph = 2 * math.pi * f * t
        v = math.sin(ph) if kind == "sine" else (1.0 if math.sin(ph) > 0 else -1.0) * 0.6 + math.sin(ph) * 0.4
        out.append(v * math.exp(-decay * t / dur) * min(1, t * 200))
    return out


# --- loops ------------------------------------------------------------------------
def ship_hum():
    n = SR * 8
    brown = seamless(lowpass(noise(n + SR // 2, 1), 0.01), SR // 2)
    out = []
    for i in range(n):
        t = i / SR
        v = (math.sin(2 * math.pi * 55 * t) * 0.6 + math.sin(2 * math.pi * 110 * t) * 0.3 + math.sin(2 * math.pi * 165.125 * t) * 0.12
             + math.sin(2 * math.pi * 27.5 * t) * 0.5)
        v *= 0.85 + 0.15 * math.sin(2 * math.pi * 0.25 * t)
        out.append(v * 0.6 + brown[i] * 9.0)
    write("ship_hum", out, 0.55)


def vent():
    n = SR * 6
    base = seamless(noise(n + SR // 2, 2), SR // 2)
    hi = lowpass(base, 0.35)
    lo = lowpass(base, 0.04)
    out = [(hi[i] - lo[i]) * (0.7 + 0.3 * math.sin(2 * math.pi * (i / SR) / 6.0 * 2)) for i in range(n)]
    write("vent_loop", out, 0.6)


def crackle():
    n = SR * 4
    r = random.Random(3)
    out = [0.0] * (n + SR // 2)
    for _ in range(26):
        s = r.randint(0, n - 1); amp = r.uniform(0.3, 1.0); ln = r.randint(60, 600)
        for k in range(ln):
            if s + k < len(out):
                out[s + k] += r.uniform(-1, 1) * amp * math.exp(-6 * k / ln)
    out = seamless(out, SR // 2)
    write("electrical_crackle", [out[i] + 0.02 * math.sin(2 * math.pi * 120 * i / SR) for i in range(n)], 0.7)


def alarm():
    out = []
    for note in range(6):
        f = 466.0 if note % 2 == 0 else 622.0
        seg = env_note(f, 0.5, "square", decay=0.6, vib=0.012)
        out += [v * (1.0 if i < len(seg) - 800 else (len(seg) - i) / 800) for i, v in enumerate(seg)]
    write("alarm_loop", out, 0.5)


# --- one-shots --------------------------------------------------------------------
def metal(name, base, dur, seed):
    r = random.Random(seed)
    partials = [(base * m, a) for m, a in [(1, 1), (2.76, 0.6), (5.4, 0.4), (8.9, 0.25)]]
    n = int(SR * dur)
    out = [sum(math.sin(2 * math.pi * f * i / SR + r.random()) * a for f, a in partials) * math.exp(-7 * i / n) for i in range(n)]
    for i in range(300):
        out[i] += r.uniform(-1, 1) * (1 - i / 300) * 2
    write(name, out, 0.8)


def thump():
    n = int(SR * 0.9)
    write("distant_thump", [math.sin(2 * math.pi * (60 - 30 * i / n) * i / SR) * math.exp(-5 * i / n) + random.Random(i).uniform(-.1, .1) * math.exp(-12 * i / n) for i in range(n)], 0.9)


def chime():
    a = env_note(659.25, 0.7, "sine", 5.0)
    b = env_note(523.25, 1.0, "sine", 5.0)
    out = a + [0.0] * 0 
    out = a[:] + [0.0] * (len(b))
    for i, v in enumerate(b):
        out[int(SR * 0.35) + i] += v if int(SR * 0.35) + i < len(out) else 0
    write("pa_chime", out, 0.7)


def door(name, rising, dur=0.5):
    n = int(SR * dur)
    r = random.Random(7)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        f = 180 + 520 * (t if rising else 1 - t)
        ph += 2 * math.pi * f / SR
        out.append((math.sin(ph) * 0.5 + r.uniform(-1, 1) * 0.15) * math.sin(math.pi * t) ** 0.5)
    thunk = [math.sin(2 * math.pi * 90 * i / SR) * math.exp(-30 * i / SR) for i in range(int(SR * 0.18))]
    write(name, (out + thunk) if rising else (out + thunk), 0.8)


def denied():
    seg = env_note(196, 0.18, "square", 1.2)
    write("door_denied", seg + [0.0] * 2000 + seg, 0.6)


def static_burst():
    r = random.Random(11)
    n = int(SR * 1.6)
    out = []
    for i in range(n):
        t = i / SR
        gate = 1.0 if (int(t * 9) % 3) else 0.15
        v = r.uniform(-1, 1) * 0.5 * gate
        if 0.1 < t < 0.2 or 1.3 < t < 1.4:
            v += math.sin(2 * math.pi * 1000 * t) * 0.6
        out.append(v)
    write("static_burst", lowpass(out, 0.5), 0.6)


def beep():
    write("terminal_beep", env_note(880, 0.12, "sine", 3.0), 0.5)


for fn in (ship_hum, vent, crackle, alarm, thump, chime, denied, static_burst, beep):
    fn()
metal("distant_clank_1", 310, 1.1, 1)
metal("distant_clank_2", 190, 1.4, 2)
door("door_open", True)
door("door_close", False)
print("wrote", sorted(os.listdir(OUT)))
