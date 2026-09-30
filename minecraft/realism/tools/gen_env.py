"""
gen_env.py — كيصايب خامات الجو: غيوم واقعية، شمس، قمر، مطر/ثلج

كلشي كيتصايب بـ numpy (ضجيج FBM) باش تبان طبيعية وكتبقى تكرر بلا خطوط
(seamless tileable)، وكنرندرو بدقة عالية ومن بعد كنصغّرو باش الحواف تكون ناعمة.

الاستعمال: python3 gen_env.py [--lite]
"""
from __future__ import annotations

import argparse
import pathlib

import numpy as np
from PIL import Image, ImageFilter

from common import SRC_DIR, clean_dir, log

RNG = np.random.default_rng(20260930)


# ----------------------------------------------------------------------------
# ضجيج (noise) — نسخة كتبقى تكرر وحدها (tileable)
# ----------------------------------------------------------------------------
def value_noise(h: int, w: int, freq: int, rng) -> np.ndarray:
    """ضجيج بسيط على شبكة freq×freq مع interpolate ناعم (cosine)"""
    grid = rng.random((freq, freq)).astype(np.float32)
    xs = np.linspace(0, freq, w, endpoint=False, dtype=np.float32)
    ys = np.linspace(0, freq, h, endpoint=False, dtype=np.float32)
    x0 = np.floor(xs).astype(int) % freq
    y0 = np.floor(ys).astype(int) % freq
    x1 = (x0 + 1) % freq
    y1 = (y0 + 1) % freq
    tx = xs - np.floor(xs)
    ty = ys - np.floor(ys)
    # cosine interpolation = نعومة أكثر
    tx = 0.5 - 0.5 * np.cos(tx * np.pi)
    ty = 0.5 - 0.5 * np.cos(ty * np.pi)
    tx = tx[None, :]
    ty = ty[:, None]
    v00 = grid[np.ix_(y0, x0)]
    v10 = grid[np.ix_(y0, x1)]
    v01 = grid[np.ix_(y1, x0)]
    v11 = grid[np.ix_(y1, x1)]
    top = v00 * (1 - tx) + v10 * tx
    bot = v01 * (1 - tx) + v11 * tx
    return top * (1 - ty) + bot * ty


def fbm(h: int, w: int, base_freq: int = 3, octaves: int = 6,
        gain: float = 0.5, lacunarity: int = 2, rng=None) -> np.ndarray:
    rng = rng or RNG
    out = np.zeros((h, w), dtype=np.float32)
    amp, total, freq = 1.0, 0.0, base_freq
    for _ in range(octaves):
        out += amp * value_noise(h, w, freq, rng)
        total += amp
        amp *= gain
        freq *= lacunarity
    return out / total


def smoothstep(edge0, edge1, x, eps: float = 1e-6):
    """smoothstep كيخدم فاتجاهين (حتى منين edge1 < edge0)"""
    d = float(edge1 - edge0)
    if abs(d) < eps:
        d = eps if d >= 0 else -eps
    t = np.clip((x - edge0) / d, 0, 1)
    return t * t * (3 - 2 * t)


# ----------------------------------------------------------------------------
# 1) الغيوم — cumulus مع حواف ريشية
# ----------------------------------------------------------------------------
def make_clouds(size: int = 256) -> Image.Image:
    h = w = size
    # طبقة كبيرة (كتحدد شكل السحابة) + طبقة تفاصيل (كتدير الحواف ريشية)
    big = fbm(h, w, base_freq=3, octaves=5, gain=0.55, rng=RNG)
    med = fbm(h, w, base_freq=6, octaves=5, gain=0.5, rng=RNG)
    fine = fbm(h, w, base_freq=14, octaves=4, gain=0.5, rng=RNG)
    # "ridged" = كيدير خطوط ولا حزم كيف السحاب الرقيق
    ridged = 1.0 - np.abs(fbm(h, w, base_freq=5, octaves=4, rng=RNG) * 2 - 1)

    field = 0.52 * big + 0.24 * med + 0.12 * fine + 0.12 * ridged
    field = (field - field.min()) / (field.max() - field.min() + 1e-6)
    # تباين: كنخليو الغيوم منفصلة شوية (حواف واضحة)
    field = np.clip((field - 0.5) * 1.55 + 0.5, 0, 1)

    alpha = smoothstep(0.46, 0.60, field)
    alpha = np.clip(alpha * 1.05, 0, 1)

    # التلوين: فوق أبيض ساطع، تحت (الحواف) رمادي خفيف = إحساس بالحجم
    shade = smoothstep(0.45, 0.9, field)
    rgb = 214 + 41 * shade          # من 214 (رمادي فاتح) لـ 255 (أبيض)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[..., 0] = rgb
    img[..., 1] = np.clip(rgb + 1, 0, 255)
    img[..., 2] = np.clip(rgb + 6, 0, 255)
    img[..., 3] = np.clip(alpha * 255, 0, 255)
    return Image.fromarray(img, "RGBA")


# ----------------------------------------------------------------------------
# 2) الشمس — قرص دافي مع هالة
# ----------------------------------------------------------------------------
def make_sun(size: int = 64, vv: bool = False) -> Image.Image:
    """كنرندرو بدقة 8x ومن بعد كنصغرو (anti-aliasing)"""
    scale = 8
    n = size * scale
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    c = (n - 1) / 2.0
    r = np.sqrt((x - c) ** 2 + (y - c) ** 2) / (n / 2.0)

    # الهالة: كانتين أوسع فالنسخة العادية، وأضيق فالـ VV (حيت VV كيزيد وهج وحدو)
    if vv:
        glow = np.exp(-((r / 0.42) ** 2)) * 0.85
        disc_a, core_a = 0.30, 0.20
    else:
        glow = np.exp(-((r / 0.55) ** 2)) * 0.75
        disc_a, core_a = 0.32, 0.22

    disc = smoothstep(disc_a + 0.03, disc_a - 0.03, r)   # القرص
    core = smoothstep(core_a + 0.04, 0.0, r)             # النواة

    # اللون ساطع والشفافية (alpha) هي لي كتحمل التلاشي
    warm = np.array([255, 196, 118], dtype=np.float32)
    white = np.array([255, 251, 233], dtype=np.float32)

    rgb = warm[None, None, :].copy() * np.ones((n, n, 1), dtype=np.float32)
    rgb = rgb + (white - warm)[None, None, :] * np.clip(disc * 0.85 + core * 0.6, 0, 1)[..., None]
    rgb = np.clip(rgb, 0, 255)

    a = np.clip(glow * 0.75 + disc * 0.9 + core * 0.4, 0, 1) * 255

    img = np.zeros((n, n, 4), dtype=np.uint8)
    img[..., :3] = rgb.astype(np.uint8)
    img[..., 3] = a.astype(np.uint8)
    return Image.fromarray(img, "RGBA").resize((size, size), Image.LANCZOS)


# ----------------------------------------------------------------------------
# 3) القمر — مع الفازات (8 مراحل) و كراتر
# ----------------------------------------------------------------------------
def _moon_disc(size: int, phase: float) -> Image.Image:
    """
    phase: 0.0 = بدر كامل، 0.5 = محاق (جديد)، والوسط بيناتهم
    """
    scale = 8
    n = size * scale
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    c = (n - 1) / 2.0
    dx = (x - c) / (n / 2.0)
    dy = (y - c) / (n / 2.0)
    r = np.sqrt(dx ** 2 + dy ** 2)

    disc = smoothstep(0.92, 0.88, r)

    # كراتر (بقع داكنة) بالضجيج
    craters = fbm(n, n, base_freq=5, octaves=5, rng=np.random.default_rng(7))
    craters = (craters - craters.min()) / (craters.max() - craters.min() + 1e-6)
    mare = fbm(n, n, base_freq=2, octaves=3, rng=np.random.default_rng(11))
    mare = smoothstep(0.55, 0.75, mare)

    base_color = 232 - 34 * craters - 40 * mare
    base_color = np.clip(base_color, 150, 245)

    # فاز القمر: الظل كيتحرك أفقيا
    #   phase 0 (بدر)   -> كامل مضوي
    #   phase 0.25      -> نص (الجهة اليمنى)
    #   phase 0.5 (محاق) -> ضلمة كاملة
    if phase <= 0.5:
        # من بدر لمحاق: الظل كيدخل من اليمين
        left = -1.0 + 2.0 * (phase / 0.5)          # من -1 لـ 1
        shadow = smoothstep(left - 0.06, left + 0.06, dx)
    else:
        p = (phase - 0.5) / 0.5
        right = 1.0 - 2.0 * p                       # من 1 لـ -1
        shadow = smoothstep(right - 0.06, right + 0.06, -dx)

    lit = disc * (1.0 - shadow)
    # شحال من ضو كيرجع (نسخة خفيفة فالجانب المظلم باش يبان)
    img = np.zeros((n, n, 4), dtype=np.float32)
    # لون دافي شوية (مايل للرمادي الأزرق)
    img[..., 0] = base_color * 1.02
    img[..., 1] = base_color * 1.01
    img[..., 2] = base_color * 0.98
    img[..., 3] = np.clip(lit * 252, 0, 255)
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")
    return im.resize((size, size), Image.LANCZOS)


def make_moon_phases(cell: int = 32) -> Image.Image:
    """16x64 ... 4 أعمدة × 2 صفوف = 8 مراحل"""
    sheet = Image.new("RGBA", (cell * 4, cell * 2), (0, 0, 0, 0))
    # ترتيب الفانيلا: بدر، أحدب متناقص، تربيع أخير، هلال متناقص،
    #              محاق، هلال متزايد، تربيع أول، أحدب متزايد
    order = [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875]
    for i, ph in enumerate(order):
        img = _moon_disc(cell, ph) if ph != 0.5 else Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        if ph > 0.5:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        sheet.paste(img, ((i % 4) * cell, (i // 4) * cell))
    return sheet


# ----------------------------------------------------------------------------
# 4) المطر والثلج (weather.png) — 4×4 خانات 8×8
#     الصف 0 = ثلج، الصف 1+2 = مطر، (0,3) = خانة غامقة كيف الفانيلا
# ----------------------------------------------------------------------------
def make_weather(size: int = 32, lite: bool = False) -> Image.Image:
    cell = size // 4
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    rng = np.random.default_rng(4242)

    # --- الثلج (صف 0): نجوم صغيرة ناعمة ---
    for tx in range(4):
        # كل خانة فيها شوية ثلج بنفس الطريقة ولكن مختلفة
        flakes = []
        for _ in range(3):
            fx = rng.integers(1, cell - 1)
            fy = rng.integers(1, cell - 1)
            flakes.append((fx, fy))
        for (fx, fy) in flakes:
            for ox in range(-1, 2):
                for oy in range(-1, 2):
                    x, y = int(fx + ox) % cell, int(fy + oy) % cell
                    if not (0 <= x < cell and 0 <= y < cell):
                        continue
                    dist = abs(ox) + abs(oy)
                    a = 235 if dist == 0 else (185 if dist == 1 else 120)
                    px[tx * cell + x, y] = (255, 255, 255, a)

    # --- المطر (صفوف 1 و 2): خطوط عمودية رفيعة مع تلاشي ---
    for row in (1, 2):
        for tx in range(4):
            # كل خانة فيها من 2 لـ 3 خطوط
            n_lines = 2 + (tx % 2)
            for li in range(n_lines):
                lx = int(rng.integers(0, cell))
                top = int(rng.integers(0, 2))
                length = cell - top - int(rng.integers(0, 3))
                for i in range(length):
                    y = top + i
                    if y >= cell:
                        break
                    # تلاشي فالأطراف
                    f = min(i + 1, length - i) / (length / 2.0)
                    a = int(np.clip(150 + 95 * f, 0, 255))
                    color = (196, 214, 246) if row == 1 else (176, 198, 238)
                    x = (lx + (i // 8)) % cell  # ميلان خفيف جدا
                    px[tx * cell + x, row * cell + y] = (*color, a)
                    if not lite and x + 1 < cell:
                        px[tx * cell + x + 1, row * cell + y] = (*color, int(a * 0.45))

    # --- خانة الفانيلا الغامقة (0,3) ---
    for x in range(cell):
        for y in range(3 * cell, 4 * cell):
            px[x, y] = (56, 66, 72, 255)

    return img


# ----------------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lite", action="store_true")
    args = ap.parse_args()

    out = SRC_DIR / "textures" / "environment"
    out.mkdir(parents=True, exist_ok=True)

    make_clouds(256).save(out / "clouds.png")
    make_sun(32, vv=False).save(out / "sun.png")
    make_sun(32, vv=True).save(out / "sun_vv.png")
    make_moon_phases(32).save(out / "moon_phases.png")
    make_weather(32, lite=args.lite).save(out / "weather.png")

    log("✅ gen_env: غيوم + شمس (عادية و VV) + قمر بفازاته + مطر/ثلج")


if __name__ == "__main__":
    main()
