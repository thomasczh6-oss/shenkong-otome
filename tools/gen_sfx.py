#!/usr/bin/env python3
"""用 numpy 合成许愿（抽卡）演出的音效，输出 assets/audio/sfx/<key>.ogg。

不调用任何接口，随时可重跑：
  python tools/gen_sfx.py
音色都是铃、钢片琴和闪光噪声叠出来的，保持梦幻、柔和的女性向质感。
"""
import pathlib
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"
RNG = np.random.default_rng(7)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def note(freq):
    """音名 → 频率，A4 = 440。"""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    base = names[freq[0]] + (1 if "#" in freq else 0)
    octave = int(freq[-1])
    return 440.0 * 2 ** ((base + (octave - 4) * 12) / 12)


def bell(freq, sec, decay=3.0, bright=0.5):
    """钟琴 / 钢片琴：基频 + 非整数泛音，指数衰减。"""
    t = t_axis(sec)
    env = np.exp(-decay * t) * np.minimum(1.0, t * 400)
    s = np.sin(2 * np.pi * freq * t)
    s += bright * 0.5 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-decay * 2 * t)
    s += bright * 0.25 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-decay * 3 * t)
    s += 0.3 * np.sin(2 * np.pi * freq * 2 * t)
    return s * env


def shimmer(sec, density=40, lo=2000, hi=6000, decay=18.0):
    """许多随机的小高音点，像星星在闪。"""
    out = np.zeros(int(SR * sec))
    n = int(density * sec)
    for _ in range(n):
        start = RNG.uniform(0, sec * 0.92)
        f = RNG.uniform(lo, hi)
        b = bell(f, 0.5, decay=decay, bright=0.2) * RNG.uniform(0.15, 0.4)
        i = int(start * SR)
        j = min(len(out), i + len(b))
        out[i:j] += b[: j - i]
    return out


def noise_sweep(sec, f0, f1, q=0.08):
    """带通噪声从 f0 扫到 f1：「呼——」的风声。"""
    t = t_axis(sec)
    n = RNG.standard_normal(len(t))
    spec = np.fft.rfft(n)
    freqs = np.fft.rfftfreq(len(t), 1 / SR)
    centre = (f0 + f1) / 2
    width = abs(f1 - f0) / 2 + centre * q
    spec *= np.exp(-((freqs - centre) / width) ** 2)
    s = np.fft.irfft(spec, len(t))
    # 用时间包络模拟扫频
    env = np.sin(np.pi * np.clip(t / sec, 0, 1)) ** 1.5
    return s / (np.max(np.abs(s)) + 1e-9) * env


def pad(freqs, sec, attack=0.6):
    """柔和的和弦垫底。"""
    t = t_axis(sec)
    env = np.minimum(1.0, t / attack) * np.exp(-1.2 * np.maximum(0, t - sec * 0.5))
    s = sum(np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2.001 * t) for f in freqs)
    return s * env / len(freqs)


def mix(*parts):
    n = max(len(p) for p, _ in parts)
    out = np.zeros(n)
    for p, at in parts:
        i = int(at * SR)
        j = min(n, i + len(p))
        if i < n:
            out[i:j] += p[: j - i]
    return out


def reverb(x, wet=0.28):
    """几条梳状延迟，够用的房间感。"""
    out = x.copy()
    for d, g in ((0.029, 0.5), (0.037, 0.45), (0.041, 0.4), (0.053, 0.35), (0.11, 0.25), (0.17, 0.18)):
        k = int(d * SR)
        y = np.zeros(len(x) + k * 6)
        y[: len(x)] = x
        for r in range(1, 6):
            y[k * r : k * r + len(x)] += x * (g ** r)
        out = np.pad(out, (0, len(y) - len(out)))
        out += wet * (y - np.pad(x, (0, len(y) - len(x))))
    return out


def save(key, x, peak=0.85):
    x = reverb(x)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = int(0.05 * SR)
    x[-fade:] *= np.linspace(1, 0, fade)
    OUT.mkdir(parents=True, exist_ok=True)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as td:
        wav = pathlib.Path(td) / "a.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4", str(OUT / f"{key}.ogg")], check=True)
    print(key, f"{len(x) / SR:.1f}s")


def main():
    # 许愿聚能：上行琶音 + 越来越密的星光 + 风声
    arp = ["C5", "E5", "G5", "B5", "D6", "E6", "G6", "B6"]
    parts = [(bell(note(n), 1.4, decay=2.5, bright=0.4) * 0.5, i * 0.22) for i, n in enumerate(arp)]
    parts += [(shimmer(2.4, density=30) * 0.6, 0.2), (noise_sweep(2.4, 400, 4000) * 0.25, 0.0), (pad([note("C4"), note("G4"), note("E5")], 2.6) * 0.35, 0.0)]
    save("wish_charge", mix(*parts))

    # 流星划过
    save("star_fall", mix((noise_sweep(1.3, 6000, 800) * 0.6, 0), (shimmer(1.2, density=50, lo=3000, hi=8000) * 0.5, 0.05), (bell(note("E6"), 1.0, decay=4) * 0.4, 0.9)))

    # 翻卡：短促的「唰」+ 一点光
    save("card_flip", mix((noise_sweep(0.28, 1500, 5000) * 0.7, 0), (bell(note("A6"), 0.4, decay=10, bright=0.2) * 0.25, 0.12)), peak=0.6)

    # 3★：一声小铃
    save("reveal3", mix((bell(note("G5"), 0.9, decay=4.5) * 0.7, 0), (bell(note("D6"), 0.8, decay=5) * 0.35, 0.08)), peak=0.6)

    # 4★：紫色双音 + 闪光
    save("reveal4", mix((bell(note("E5"), 1.6, decay=2.6) * 0.6, 0), (bell(note("B5"), 1.6, decay=2.6) * 0.5, 0.12), (bell(note("E6"), 1.4, decay=3) * 0.4, 0.24), (shimmer(1.2, density=26) * 0.5, 0.1)), peak=0.75)

    # 5★：大和弦钟声 + 长长的星光尾巴 + 弦乐垫
    chord = ["C5", "E5", "G5", "C6", "E6", "G6"]
    parts = [(bell(note(n), 3.2, decay=1.2, bright=0.6) * 0.45, i * 0.06) for i, n in enumerate(chord)]
    parts += [(pad([note("C4"), note("G4"), note("C5"), note("E5")], 3.6, attack=0.3) * 0.5, 0), (shimmer(3.2, density=34, lo=2500, hi=9000) * 0.55, 0.15), (noise_sweep(1.0, 200, 3000) * 0.3, 0)]
    save("reveal5", mix(*parts), peak=0.9)

    # 结果页亮起
    save("result_open", mix((bell(note("C6"), 1.0, decay=3.5) * 0.5, 0), (bell(note("G6"), 1.0, decay=3.5) * 0.4, 0.1), (shimmer(0.8, density=20) * 0.4, 0.05)), peak=0.6)


if __name__ == "__main__":
    main()
