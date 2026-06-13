import math, random, struct, wave
SR = 22050
random.seed(7)

def write_wav(name, samples):
    samples = [max(-1.0, min(1.0, s)) for s in samples]
    with wave.open(f"audio/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32000)) for s in samples))
    print(name, len(samples) / SR, "s")

def env(i, n, attack=0.002, decay=4.0):
    t = i / SR
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-decay * t)

def lowpass(xs, a=0.25):
    out, y = [], 0.0
    for x in xs:
        y += a * (x - y)
        out.append(y)
    return out

# rifle shot: sharp noise crack + low thump
n = int(SR * 0.14)
noise = [random.uniform(-1, 1) * env(i, n, 0.001, 28) for i in range(n)]
noise = lowpass(noise, 0.55)
thump = [0.7 * math.sin(2 * math.pi * (110 - 60 * i / n) * i / SR) * env(i, n, 0.001, 18) for i in range(n)]
write_wav("shot_rifle", [0.9 * a + b for a, b in zip(noise, thump)])

# reload: click-clack
n = int(SR * 0.45)
out = [0.0] * n
for start, pitch in ((0.0, 0.5), (0.16, 0.4), (0.34, 0.65)):
    s0 = int(start * SR)
    for i in range(int(SR * 0.04)):
        if s0 + i < n:
            out[s0 + i] += random.uniform(-1, 1) * math.exp(-pitch * 90 * i / SR)
write_wav("reload", lowpass(out, 0.6))

# player hurt: low thud
n = int(SR * 0.22)
write_wav("hurt", [0.95 * math.sin(2 * math.pi * (75 - 25 * i / n) * i / SR) * env(i, n, 0.002, 10) for i in range(n)])

# enemy hit impact: short snap
n = int(SR * 0.08)
write_wav("impact", lowpass([random.uniform(-1, 1) * env(i, n, 0.001, 45) for i in range(n)], 0.5))

# enemy death: descending growl
n = int(SR * 0.5)
out = []
ph = 0.0
for i in range(n):
    t = i / SR
    f = 180 * math.exp(-2.2 * t) + 45
    ph += 2 * math.pi * f / SR
    s = 0.6 * (1 if math.sin(ph) > 0 else -1) * 0.5 + 0.4 * math.sin(ph * 0.5)
    s += 0.2 * random.uniform(-1, 1)
    out.append(s * env(i, n, 0.01, 5))
write_wav("enemy_die", lowpass(out, 0.3))

# boss roar
n = int(SR * 0.9)
out = []
ph = 0.0
for i in range(n):
    t = i / SR
    f = 70 + 28 * math.sin(2 * math.pi * 3.2 * t)
    ph += 2 * math.pi * f / SR
    s = 0.7 * math.tanh(2.4 * math.sin(ph)) + 0.35 * random.uniform(-1, 1)
    out.append(s * min(1.0, t / 0.08) * math.exp(-2.2 * max(0.0, t - 0.45)))
write_wav("boss_roar", lowpass(out, 0.25))

# wave alarm: two-tone
n = int(SR * 0.7)
out = []
for i in range(n):
    t = i / SR
    f = 520 if int(t * 4) % 2 == 0 else 392
    s = 0.30 * math.tanh(1.8 * math.sin(2 * math.pi * f * t))
    out.append(s * min(1.0, t / 0.02) * (1.0 - max(0.0, (t - 0.55)) / 0.15))
write_wav("wave_start", out)

# dodge whoosh
n = int(SR * 0.3)
noise = [random.uniform(-1, 1) for i in range(n)]
noise = lowpass(noise, 0.12)
write_wav("dodge", [s * math.sin(math.pi * i / n) * 1.6 for i, s in enumerate(noise)])

# ui click
n = int(SR * 0.05)
write_wav("click", lowpass([random.uniform(-1, 1) * env(i, n, 0.001, 60) for i in range(n)], 0.4))

# ambient wind loop (4s)
n = SR * 4
noise = [random.uniform(-1, 1) for i in range(n)]
noise = lowpass(lowpass(noise, 0.045), 0.5)
out = []
for i, s in enumerate(noise):
    t = i / SR
    mod = 0.6 + 0.4 * math.sin(2 * math.pi * 0.21 * t)
    out.append(s * mod * 3.2)
# crossfade ends for seamless loop
f = int(SR * 0.25)
for i in range(f):
    k = i / f
    out[i] = out[i] * k + out[n - f + i] * (1 - k)
write_wav("amb_wind", out[: n - f])
