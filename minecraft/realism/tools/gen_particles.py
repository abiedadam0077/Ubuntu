"""
gen_particles.py — كيحسّن الجزيئات (particles) باش تبان واقعية

شنو كنبدلو فـ textures/particle/particles.png (128×128، خانات 8×8):
  • قطرات الماء/الرشاش (سبرايتات 24,32,40,48 فـ y=8) → قطرات مدوّرة فيها ضو
  • الفقاعات (0,16) (8,16) (16,16)                    → فقاعات زجاجية فيها لمعة
  • الشعلة (0,24)                                     → لهب ناعم بتدرّج
  • particles_mers: الماء/الفقاعات = ناعم وعاكس (خشونة قليلة + subsurface)

باقي السبرايتات كيتنسخو كيف ما هوما (باش ما نفسدوش باقي الجزيئات).
"""
from __future__ import annotations

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from common import SRC_DIR, Report, load_json, log, vanilla_path, write_json

CELL = 8          # مقاس السبرايت
SS = 16           # supersampling (كنرسمو كبير ومن بعد كنصغرو = حواف ناعمة)


# ----------------------------------------------------------------------------
def _canvas(size: int = CELL):
    img = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def droplet(seed: int) -> Image.Image:
    """قطرة ماء واقعية: شكل دمعة + لمعة + قطرات صغيرة"""
    rng = np.random.default_rng(seed)
    img, d = _canvas()
    S = CELL * SS
    # القطرة الرئيسية
    cx = S * rng.uniform(0.42, 0.58)
    top = S * rng.uniform(0.08, 0.16)
    bot = S * rng.uniform(0.80, 0.92)
    w = S * rng.uniform(0.24, 0.30)
    # الجسم (بيضاوي ممدود)
    d.ellipse([cx - w, top + (bot - top) * 0.22, cx + w, bot], fill=(214, 236, 255, 235))
    # القمة المدببة (ذيل القطرة)
    d.polygon([(cx, top), (cx - w * 0.72, top + (bot - top) * 0.32),
               (cx + w * 0.72, top + (bot - top) * 0.32)], fill=(214, 236, 255, 235))
    # لمعة قوية
    hl = S * rng.uniform(0.08, 0.12)
    hx = cx - w * rng.uniform(0.25, 0.45)
    hy = top + (bot - top) * rng.uniform(0.30, 0.40)
    d.ellipse([hx - hl, hy - hl, hx + hl, hy + hl], fill=(255, 255, 255, 240))
    # لمعة صغيرة تحت
    d.ellipse([cx + w * 0.1, bot - S * 0.22, cx + w * 0.45, bot - S * 0.12],
              fill=(255, 255, 255, 150))
    # قطرات مرافقة
    for _ in range(rng.integers(1, 3)):
        rx = S * rng.uniform(0.08, 0.92)
        ry = S * rng.uniform(0.45, 0.95)
        rr = S * rng.uniform(0.04, 0.08)
        d.ellipse([rx - rr, ry - rr, rx + rr, ry + rr], fill=(206, 230, 252, 200))
    img = img.filter(ImageFilter.GaussianBlur(SS * 0.25))
    return img.resize((CELL, CELL), Image.LANCZOS)


def bubble(seed: int, big: bool = False) -> Image.Image:
    """فقاعة: حلقة (rim) + لمعة + داخل شفاف"""
    rng = np.random.default_rng(seed)
    img, d = _canvas()
    S = CELL * SS
    pad = S * (0.05 if big else 0.10)
    # الحلقة الخارجية
    d.ellipse([pad, pad, S - pad, S - pad], fill=(196, 224, 248, 120),
              outline=(236, 248, 255, 235), width=int(S * 0.055))
    # الحلقة الضوئية الداخلية
    d.ellipse([pad + S * 0.07, pad + S * 0.07, S - pad - S * 0.07, S - pad - S * 0.07],
              outline=(255, 255, 255, 150), width=int(S * 0.025))
    # لمعة كبيرة فوق-يسار
    r = S * rng.uniform(0.16, 0.21)
    d.ellipse([pad + S * 0.13, pad + S * 0.11, pad + S * 0.13 + r, pad + S * 0.11 + r],
              fill=(255, 255, 255, 220))
    # لمعة صغيرة تحت-يمين
    r2 = S * rng.uniform(0.07, 0.10)
    d.ellipse([S - pad - r2 - S * 0.14, S - pad - r2 - S * 0.16,
               S - pad - S * 0.14, S - pad - S * 0.16], fill=(226, 244, 255, 170))
    img = img.filter(ImageFilter.GaussianBlur(SS * 0.18))
    return img.resize((CELL, CELL), Image.LANCZOS)


def flame(seed: int = 5) -> Image.Image:
    """لهب ناعم: تدرّج من الأبيض للبرتقالي مع شفافية"""
    rng = np.random.default_rng(seed)
    S = CELL * SS
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    nx = (x - S / 2) / (S / 2)
    ny = y / S

    # شكل اللهب: عريض تحت ومدبب فوق
    width = 0.85 * (1 - ny) ** 0.55 + 0.10
    core = np.clip(1 - np.abs(nx) / width, 0, 1) ** 1.4
    core *= np.clip(1.25 - ny * 1.25, 0, 1)
    core *= 1.0 + 0.12 * np.sin(nx * 9.0 + ny * 5.0)   # تمويج

    a = np.clip(core * 255 * 0.95, 0, 255)
    r = np.clip(255 * (0.75 + 0.25 * core), 0, 255)
    g = np.clip(210 * core + 40, 0, 255)
    b = np.clip(90 * core ** 2, 0, 255)

    out = np.zeros((S, S, 4), dtype=np.uint8)
    out[..., 0] = r
    out[..., 1] = g
    out[..., 2] = b
    out[..., 3] = a
    img = Image.fromarray(out, "RGBA").filter(ImageFilter.GaussianBlur(SS * 0.3))
    return img.resize((CELL, CELL), Image.LANCZOS)


# ----------------------------------------------------------------------------
# مواقع السبرايتات (من ملفات الفانيلا الرسمية particles/*.json)
# ----------------------------------------------------------------------------
SPLASH_UVS = [(24, 8), (32, 8), (40, 8), (48, 8)]   # rain_splash + water_splash
BUBBLE_UVS = [(0, 16), (8, 16), (16, 16)]           # basic_bubble / nautilus / column
FLAME_UV = (0, 24)                                  # basic_flame


def main() -> None:
    vanilla = vanilla_path()
    src_png = vanilla / "textures" / "particle" / "particles.png"
    src_mers = vanilla / "textures" / "particle" / "particles_mers.tga"

    out_dir = SRC_DIR / "textures" / "particle"
    out_dir.mkdir(parents=True, exist_ok=True)
    rep = Report()

    base = Image.open(src_png).convert("RGBA")
    if base.size != (128, 128):
        rep.warn(f"particles.png مقاس ماشي متوقع: {base.size}")

    # 1) الرشاش / القطرات
    for i, (ux, uy) in enumerate(SPLASH_UVS):
        base.paste(droplet(100 + i), (ux, uy))

    # 2) الفقاعات
    for i, (ux, uy) in enumerate(BUBBLE_UVS):
        base.paste(bubble(200 + i, big=(i == 0)), (ux, uy))

    # 3) اللهب
    base.paste(flame(), FLAME_UV)

    base.save(out_dir / "particles.png")

    # --- MERS: الماء والفقاعات لامعين وناعمين + subsurface ---
    if src_mers.exists():
        mers = Image.open(src_mers).convert("RGBA")
    else:
        rep.warn("particles_mers.tga ماشي موجود — كنصايبو من الصفر")
        mers = Image.new("RGBA", base.size, (0, 0, 255, 0))
    m = np.asarray(mers).copy()

    def paint(uvs, metal, emiss, rough, sub):
        for (ux, uy) in uvs:
            m[uy:uy + CELL, ux:ux + CELL, 0] = metal
            m[uy:uy + CELL, ux:ux + CELL, 1] = emiss
            m[uy:uy + CELL, ux:ux + CELL, 2] = rough
            m[uy:uy + CELL, ux:ux + CELL, 3] = sub

    paint(SPLASH_UVS, 0, 30, 14, 200)    # ماء: ناعم، شوية إشعاع (بريق)، subsurface عالي
    paint(BUBBLE_UVS, 0, 45, 8, 220)     # فقاعة: زجاجية رقيقة
    paint([FLAME_UV], 0, 235, 190, 40)   # لهب: كيشعل

    Image.fromarray(m, "RGBA").save(out_dir / "particles_mers.png")

    write_json(out_dir / "particles.texture_set.json", {
        "format_version": "1.21.30",
        "minecraft:texture_set": {
            "color": "particles",
            "metalness_emissive_roughness_subsurface": "particles_mers",
        },
    })

    log("✅ gen_particles: قطرات + فقاعات + لهب واقعيين، ومعاهم MERS (ماء عاكس، لهب كيشعل)")
    rep.print()


if __name__ == "__main__":
    main()
