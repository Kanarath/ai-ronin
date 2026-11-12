"""Genera las muestras de la música lo-fi del Dojo (game/assets/musica/*.wav).

Son sonidos sueltos y cortos (piano eléctrico, bajo, koto, shakuhachi, batería, vinilo y
lluvia) sintetizados desde cero: no hay grabaciones ni muestras de nadie. El juego los
combina al tocar (ui/fx/music_player.gd), así que la música ocupa muy poco.

Uso (una vez; necesita numpy):
    python game/tools/gen_muestras_lofi.py
Lo escribe Claude para AI RONIN.
"""

import wave
from pathlib import Path

import numpy as np

SR = 32000
OUT = Path(__file__).resolve().parents[1] / "assets" / "musica"
rng = np.random.default_rng(2026)


def midi_hz(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def lowpass(x, cutoff):
    """Paso bajo de un polo (suave, sin resonancia)."""
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def fade(x, fin=0.003, fout=0.02):
    n_in, n_out = int(SR * fin), int(SR * fout)
    x = x.copy()
    if n_in:
        x[:n_in] *= np.linspace(0, 1, n_in)
    if n_out:
        x[-n_out:] *= np.linspace(1, 0, n_out)
    return x


def save(name, x, peak=0.8):
    x = np.tanh(x * 1.2)  # saturación suave, «cinta»
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / (name + ".wav")), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print("%-12s %5.2f s" % (name, len(x) / SR))


def ep(note, dur=3.2):
    """Piano eléctrico tipo Rhodes: FM 1:1 con índice que cae (el «campanazo» del ataque)."""
    t = t_axis(dur)
    f = midi_hz(note)
    index = 1.6 * np.exp(-t / 0.18) + 0.25
    mod = np.sin(2 * np.pi * f * t) * index
    tone = np.sin(2 * np.pi * f * t + mod)
    tone += 0.12 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.4)
    tone += 0.05 * np.sin(2 * np.pi * f * 1.003 * t)  # leve batido
    env = np.exp(-t / 1.4) * np.minimum(1, t / 0.004)
    return fade(lowpass(tone * env, 3500), fout=0.15)


def bass(note, dur=1.8):
    t = t_axis(dur)
    f = midi_hz(note)
    tone = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t) + 0.08 * np.sin(2 * np.pi * 3 * f * t)
    env = np.minimum(1, t / 0.012) * np.exp(-t / 0.9)
    return fade(lowpass(tone * env, 900), fout=0.1)


def koto(note, dur=2.6):
    """Cuerda pulsada (Karplus-Strong) con un ataque algo brillante, como un plectro."""
    f = midi_hz(note)
    period = int(round(SR / f))
    buf = rng.uniform(-1, 1, period)
    buf = lowpass(buf, 6000)
    n = int(SR * dur)
    out = np.empty(n)
    for i in range(n):
        j = i % period
        v = buf[j]
        out[i] = v
        buf[j] = 0.997 * 0.5 * (v + buf[(j + 1) % period])
    return fade(out, fin=0.0005, fout=0.2)


def shakuhachi(note, dur=1.8):
    """Flauta de bambú: fundamental con pocos armónicos, soplo filtrado y vibrato que llega tarde."""
    t = t_axis(dur)
    f = midi_hz(note)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.35) / 0.4, 0, 1)
    phase = 2 * np.pi * np.cumsum(f * vib) / SR
    tone = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.06 * np.sin(3 * phase)
    breath = highpass(lowpass(rng.normal(0, 1, len(t)), 3000), 900) * 0.18
    env = np.clip(t / 0.09, 0, 1) * np.clip((dur - t) / 0.35, 0, 1)
    swell = 0.85 + 0.15 * np.sin(np.pi * np.clip(t / dur, 0, 1))
    return lowpass((tone + breath * (1.2 - 0.6 * np.clip(t / 0.3, 0, 1))) * env * swell, 4000)


def kick():
    t = t_axis(0.42)
    f = 45 + 80 * np.exp(-t / 0.035)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16)
    click = lowpass(rng.normal(0, 1, len(t)), 2500) * np.exp(-t / 0.004) * 0.3
    return fade(lowpass(body + click, 1800), fin=0.0005)


def snare():
    t = t_axis(0.28)
    noise = highpass(lowpass(rng.normal(0, 1, len(t)), 5000), 700) * np.exp(-t / 0.06)
    body = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.03) * 0.6
    return fade(lowpass(noise * 0.8 + body, 4200), fin=0.0005)


def rim():
    t = t_axis(0.06)
    x = np.sin(2 * np.pi * 820 * t) * np.exp(-t / 0.008) + highpass(rng.normal(0, 1, len(t)), 2000) * np.exp(-t / 0.002) * 0.4
    return fade(lowpass(x, 5000), fin=0.0002, fout=0.01)


def hat(dur):
    t = t_axis(dur)
    x = highpass(rng.normal(0, 1, len(t)), 6000) * np.exp(-t / (dur / 4))
    return fade(lowpass(x, 9000), fin=0.0002, fout=0.01)


def furin(dur=3.5):
    """Campanilla de viento (fūrin): parciales inarmónicos de una campana pequeña."""
    t = t_axis(dur)
    f = 1760.0
    x = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / d)
            for r, a, d in ((1.0, 1.0, 1.1), (2.76, 0.45, 0.6), (5.40, 0.25, 0.3), (8.93, 0.12, 0.15)))
    return fade(x * np.minimum(1, t / 0.001), fin=0.0005, fout=0.3)


def taiko():
    """Golpe suave de taiko: membrana grave que baja de tono y un poco de «palmada»."""
    t = t_axis(0.9)
    f = 55 + 35 * np.exp(-t / 0.06)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.35)
    slap = lowpass(rng.normal(0, 1, len(t)), 1200) * np.exp(-t / 0.01) * 0.4
    return fade(lowpass(body + slap, 1500), fin=0.0005, fout=0.1)


def pad(note, dur=4.5):
    """Colchón de cuerdas: tres dientes de sierra algo desafinados, muy filtrados, entrada lenta."""
    t = t_axis(dur)
    f = midi_hz(note)
    x = sum(2 * ((f * d * t) % 1.0) - 1 for d in (0.996, 1.0, 1.004))
    env = np.clip(t / 0.9, 0, 1) * np.clip((dur - t) / 1.4, 0, 1)
    return lowpass(lowpass(x * env, 1400), 1800)


def loopable(x, xfade=0.5):
    """Hace un bucle sin salto: mezcla el final con el principio."""
    n = int(SR * xfade)
    head, body = x[:n], x[n:]
    ramp = np.linspace(0, 1, n)
    body[-n:] = body[-n:] * (1 - ramp) + head * ramp
    return body


def vinyl(dur=7.0):
    t = t_axis(dur)
    hiss = lowpass(highpass(rng.normal(0, 1, len(t)), 1500), 7000) * 0.05
    pops = np.zeros(len(t))
    for pos in rng.integers(0, len(t) - 200, 70):
        amp = rng.uniform(0.15, 0.6)
        pops[pos:pos + 60] += amp * np.exp(-np.arange(60) / 6.0) * rng.choice([-1, 1])
    return loopable(hiss + lowpass(pops, 6000))


def rain(dur=9.0):
    t = t_axis(dur)
    bed = lowpass(highpass(rng.normal(0, 1, len(t)), 400), 2600) * 0.35
    bed *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.11 * t)
    drops = np.zeros(len(t))
    for pos in rng.integers(0, len(t) - 400, 900):
        drops[pos:pos + 300] += rng.uniform(0.05, 0.25) * np.exp(-np.arange(300) / 25.0) * np.sin(np.arange(300) * rng.uniform(0.3, 0.9))
    return loopable(bed + lowpass(drops, 5000) * 0.6)


if __name__ == "__main__":
    for n, name in ((48, "ep_c3"), (60, "ep_c4"), (72, "ep_c5")):
        save(name, ep(n), 0.7)
    save("bajo_c2", bass(36), 0.8)
    save("koto_c4", koto(60), 0.7)
    save("koto_c5", koto(72), 0.7)
    save("shakuhachi_c5", shakuhachi(72), 0.6)
    save("bombo", kick(), 0.9)
    save("caja", snare(), 0.6)
    save("aro", rim(), 0.5)
    save("charles", hat(0.05), 0.35)
    save("charles_abierto", hat(0.3), 0.3)
    save("vinilo", vinyl(), 0.5)
    save("lluvia", rain(), 0.5)
    save("furin", furin(), 0.45)
    save("taiko", taiko(), 0.85)
    save("pad_c4", pad(60), 0.5)
