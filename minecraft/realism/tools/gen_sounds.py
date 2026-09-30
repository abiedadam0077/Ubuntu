"""
gen_sounds.py — كيصايب أصوات واقعية (OGG) بديلة لأصوات الفانيلا

شنو كنبدلو:
  • المطر    (ambient.weather.rain)      → 4 نسخ مطر طبيعي (هسيس + قطرات)
  • الرعد    (ambient.weather.thunder)   → 3 نسخ رعد عميق
  • تحت الما (ambient.underwater.loop)   → لوب مكتّم عميق (ستيريو)
  • الماء الجاري (liquid.water)          → 3 نسخ ماء كيجرّي/كيتموج

كل الأصوات كتولّد بـ numpy (ضجيج + فلاتر FFT) وكتخرج فـ sounds/cinematic/*.ogg
مع sounds/sound_definitions.json كيربطهم بأسماء الأحداث الأصلية.
"""
from __future__ import annotations

import pathlib

import numpy as np
import soundfile as sf

from common import SRC_DIR, clean_dir, log

SR = 44100
OUT = SRC_DIR / "sounds"
RNG = np.random.default_rng(777)


# ----------------------------------------------------------------------------
# أدوات
# ----------------------------------------------------------------------------
def noise(n: int) -> np.ndarray:
    return RNG.standard_normal(n).astype(np.float32)


def spectral(x: np.ndarray, response) -> np.ndarray:
    """فلترة بالـ FFT: response(freqs) كترجع gain لكل تردد"""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    X *= response(f)
    return np.fft.irfft(X, n).astype(np.float32)


def band(lo, hi, slope=2.0):
    """فلتر تمرير حزمة ناعم (بدون رنّات)"""
    def resp(f):
        hp = 1.0 / (1.0 + (lo / np.maximum(f, 1e-6)) ** (2 * slope))
        lp = 1.0 / (1.0 + (f / max(hi, 1e-6)) ** (2 * slope))
        return hp * lp
    return resp


def lowpass(fc, slope=2.0):
    def resp(f):
        return 1.0 / (1.0 + (f / fc) ** (2 * slope))
    return resp


def highpass(fc, slope=2.0):
    def resp(f):
        return 1.0 / (1.0 + (fc / np.maximum(f, 1e-6)) ** (2 * slope))
    return resp


def loopify(x: np.ndarray, fade: float = 0.35) -> np.ndarray:
    """كنخليو الصوت يدور بلا طقة: كنخلطو الأخير مع الأول"""
    n = len(x)
    k = int(SR * fade)
    if k * 2 >= n:
        return x
    head = x[:k].copy()
    tail = x[-k:].copy()
    ramp = np.linspace(0, 1, k, dtype=np.float32)
    x = x[:-k].copy()
    x[:k] = tail * (1 - ramp) + head * ramp
    return x


def normalize(x: np.ndarray, target_db: float = -14.0) -> np.ndarray:
    peak = float(np.max(np.abs(x)) or 1.0)
    x = x / peak
    x *= 10 ** (target_db / 20.0)
    return x.astype(np.float32)


def soft_clip(x: np.ndarray, drive: float = 1.6) -> np.ndarray:
    return np.tanh(x * drive) / np.tanh(drive)


# ----------------------------------------------------------------------------
# 1) المطر
# ----------------------------------------------------------------------------
def make_rain(duration: float = 8.0, drops: int = 2600, tone: float = 1.0) -> np.ndarray:
    n = int(SR * duration)
    # الطبقة الأساسية: هسيس عريض
    base = spectral(noise(n), band(140 * tone, 6500, slope=2.0))
    body = spectral(noise(n), band(90, 900, slope=1.6)) * 0.35   # جسم المطر (low-mid)
    base = base * 0.5 + body

    # طبقة القطرات: نبضات حادة كتعطي إحساس المطر الحقيقي
    droplets = np.zeros(n, dtype=np.float32)
    pos = np.sort(RNG.integers(0, n, drops))
    for p in pos:
        burst_len = int(SR * RNG.uniform(0.002, 0.010))
        if p + burst_len >= n:
            continue
        t = np.arange(burst_len) / SR
        env = np.exp(-t * RNG.uniform(280, 700))
        # تردد القطرة كيختلف حسب الحجم
        freq = RNG.uniform(700, 3400)
        tone_burst = np.sin(2 * np.pi * freq * t + RNG.uniform(0, 6.28))
        droplets[p:p + burst_len] += env * tone_burst * RNG.uniform(0.25, 1.0)

    drops_layer = spectral(droplets, band(600 * tone, 7500, slope=1.9))
    mix = base + drops_layer * 0.9

    # تمويج بطيء (المطر كيبدل قوته) — دورة كاملة باش يبقى لوب
    t = np.arange(n) / SR
    lfo = 1.0 + 0.18 * np.sin(2 * np.pi * (1.0 / duration) * t) + 0.08 * np.sin(2 * np.pi * 2.0 / duration * t + 1.1)
    mix *= lfo

    mix = loopify(mix, 0.4)
    # peak قريب من 1.0 كيف ملفات الفانيلا (الفانيلا كتضرب فـ volume 0.02 فالجدول)
    return normalize(mix, -3.0)


# ----------------------------------------------------------------------------
# 2) الرعد
# ----------------------------------------------------------------------------
def make_thunder(duration: float = 6.5, seed_offset: int = 0) -> np.ndarray:
    n = int(SR * duration)
    rng = np.random.default_rng(900 + seed_offset)

    # ضجيج بني (brown noise) = صوت عميق
    white = rng.standard_normal(n).astype(np.float32)
    brown = np.cumsum(white)
    brown = brown / (np.max(np.abs(brown)) or 1.0)

    # فلترة: هدير عميق ولكنه مسموع فسماعات الهاتف (60-600Hz)
    rumble = spectral(brown, lowpass(rng.uniform(260, 420), slope=1.5))
    rumble = spectral(rumble, highpass(45, slope=1.4))
    mid = spectral(rng.standard_normal(n).astype(np.float32), band(150, 1200, slope=1.6))
    rumble = rumble * 1.0 + mid * 0.42

    # ظرف الصوت: طقة أولية + هدير كيخبو مع تموجات
    t = np.arange(n) / SR
    env = np.zeros(n, dtype=np.float32)
    # الجزء الأول (الطرقة)
    click_len = int(SR * 0.25)
    env[:click_len] = np.exp(-np.linspace(0, 6, click_len))
    # الهدير
    rumble_env = (
        0.55 * np.exp(-t / 2.6)
        + 0.35 * np.exp(-((t - 1.1) ** 2) / 1.1)
        + 0.25 * np.exp(-((t - 2.6) ** 2) / 2.0)
        + 0.18 * np.exp(-((t - 4.2) ** 2) / 2.6)
    )
    env += rumble_env
    env *= 1.0 + 0.22 * np.sin(2 * np.pi * rng.uniform(0.6, 1.4) * t)

    # طقة عالية قصيرة (كسر الصوت)
    crack = spectral(noise(n), band(350, 5000, slope=1.7)) * np.exp(-t * 16) * 0.42

    out = soft_clip(rumble * env * 2.2 + crack, 1.8)
    return normalize(out, -2.0)


# ----------------------------------------------------------------------------
# 3) تحت الما (لوب ستيريو)
# ----------------------------------------------------------------------------
def make_underwater_loop(duration: float = 10.0) -> np.ndarray:
    n = int(SR * duration)
    chans = []
    for ch in range(2):
        rng = RNG
        w = rng.standard_normal(n).astype(np.float32)
        deep = spectral(np.cumsum(w), lowpass(900, slope=1.5))
        deep = spectral(deep, highpass(120, slope=1.4))
        deep = deep * 0.8 + spectral(rng.standard_normal(n).astype(np.float32), band(220, 1600, slope=1.5)) * 0.65
        # بعض الفقاعات الهادئة
        bubbles = np.zeros(n, dtype=np.float32)
        for _ in range(26):
            p = int(rng.integers(0, n - SR // 4))
            ln = int(SR * rng.uniform(0.05, 0.22))
            tt = np.arange(ln) / SR
            f0 = rng.uniform(400, 1600)
            sweep = f0 * (1 + 2.6 * tt / max(tt[-1], 1e-6))
            env = np.exp(-tt * 26)
            bubbles[p:p + ln] += np.sin(2 * np.pi * sweep * tt) * env * rng.uniform(0.05, 0.16)
        t = np.arange(n) / SR
        drift = 1.0 + 0.12 * np.sin(2 * np.pi * (1.0 / duration) * t + ch * 0.9)
        mix = (deep * 0.9 + bubbles) * drift
        chans.append(loopify(mix, 0.6))
    stereo = np.stack(chans, axis=1)
    return normalize(stereo, -7.0)


# ----------------------------------------------------------------------------
# 4) الماء الجاري / تمويج
# ----------------------------------------------------------------------------
def make_water_flow(duration: float = 4.5, seed: int = 0) -> np.ndarray:
    n = int(SR * duration)
    rng = np.random.default_rng(1200 + seed)
    t = np.arange(n) / SR

    flow = spectral(rng.standard_normal(n).astype(np.float32), band(320, 4200, slope=2.0))
    # فقاعات/خرخرة (gurgle) بالتمويج
    gurgle = np.zeros(n, dtype=np.float32)
    for _ in range(60):
        p = int(rng.integers(0, n - SR // 6))
        ln = int(SR * rng.uniform(0.03, 0.14))
        tt = np.arange(ln) / SR
        f = rng.uniform(320, 1400)
        env = np.exp(-tt * rng.uniform(18, 45))
        gurgle[p:p + ln] += np.sin(2 * np.pi * f * tt * (1 + 1.2 * tt)) * env * rng.uniform(0.2, 0.6)

    gurgle = spectral(gurgle, band(250, 5000, slope=1.8))
    mod = 1.0 + 0.25 * np.sin(2 * np.pi * (1.0 / duration) * t) + 0.12 * np.sin(2 * np.pi * 3.0 / duration * t)
    out = (flow * 0.75 + gurgle * 0.8) * mod
    return normalize(loopify(out, 0.4), -6.0)


# ----------------------------------------------------------------------------
# الكتابة
# ----------------------------------------------------------------------------
def write_ogg(path: pathlib.Path, data: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if data.ndim == 1:
        data = data[:, None]
    sf.write(str(path), data, SR, format="OGG", subtype="VORBIS")


def build_sound_definitions() -> dict:
    return {
        "format_version": "1.14.0",
        "sound_definitions": {
            "ambient.weather.rain": {
                "__use_legacy_max_distance": "true",
                "category": "weather",
                "min_distance": 100.0,
                "sounds": [
                    {"name": "sounds/cinematic/rain_1", "volume": 0.022, "pitch": 1.00, "load_on_low_memory": True},
                    {"name": "sounds/cinematic/rain_2", "volume": 0.021, "pitch": 0.94, "load_on_low_memory": True},
                    {"name": "sounds/cinematic/rain_3", "volume": 0.022, "pitch": 1.06, "load_on_low_memory": True},
                    {"name": "sounds/cinematic/rain_4", "volume": 0.020, "pitch": 0.88, "load_on_low_memory": True},
                ],
                "subtitle": "subtitles.ambient.weather.rain",
            },
            "ambient.weather.thunder": {
                "__use_legacy_max_distance": "true",
                "category": "weather",
                "min_distance": 100.0,
                "sounds": [
                    {"name": "sounds/cinematic/thunder_1", "volume": 0.9, "load_on_low_memory": True},
                    {"name": "sounds/cinematic/thunder_2", "volume": 0.85, "pitch": 0.9},
                    {"name": "sounds/cinematic/thunder_3", "volume": 0.9, "pitch": 0.82},
                ],
                "subtitle": "subtitles.entity.lightning_bolt.thunder",
            },
            "ambient.underwater.loop": {
                "__use_legacy_max_distance": "true",
                "category": "ambient",
                "sounds": [
                    {"name": "sounds/cinematic/underwater_loop", "stream": True,
                     "is3D": False, "allow_concurrent_streaming": False},
                ],
            },
            "liquid.water": {
                "category": "block",
                "sounds": [
                    {"name": "sounds/cinematic/water_flow_1", "volume": 0.9, "pitch": 1.0},
                    {"name": "sounds/cinematic/water_flow_2", "volume": 0.9, "pitch": 0.92},
                    {"name": "sounds/cinematic/water_flow_3", "volume": 0.85, "pitch": 1.08},
                ],
            },
        },
    }


def main() -> None:
    clean_dir(OUT)
    n = 0

    # مطر: 4 نسخ بأحجام قطرات مختلفة
    for i, tone in enumerate((0.9, 1.0, 1.12, 0.82), start=1):
        write_ogg(OUT / "cinematic" / f"rain_{i}.ogg",
                  make_rain(8.0, drops=2200 + i * 300, tone=tone))
        n += 1

    # رعد: 3 نسخ
    for i in range(1, 4):
        write_ogg(OUT / "cinematic" / f"thunder_{i}.ogg", make_thunder(6.5, seed_offset=i * 7))
        n += 1

    # تحت الما
    write_ogg(OUT / "cinematic" / "underwater_loop.ogg", make_underwater_loop(10.0))
    n += 1

    # ماء جاري
    for i in range(1, 4):
        write_ogg(OUT / "cinematic" / f"water_flow_{i}.ogg", make_water_flow(4.5, seed=i))
        n += 1

    from common import write_json
    write_json(OUT / "sound_definitions.json", build_sound_definitions())
    log(f"✅ gen_sounds: {n} صوت OGG (مطر، رعد، تحت الما، ماء) + sound_definitions.json")


if __name__ == "__main__":
    main()
