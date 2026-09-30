"""
gen_vv.py — كيولّد ملفات Vibrant Visuals كاملة للباك (القلب ديال "السينمائي")

كيتنجم:
  1. atmospherics/  — لون السماء (zenith/horizon)، Rayleigh، Mie، وهج الشمس (keyframes على مدار اليوم)
  2. lighting/      — الشمس والقمر (قوة + لون)، ambient، قوة ضو السماء، الإشعاع
  3. color_grading/ — تصحيح الألوان (midtones/highlights/shadows + حرارة) + tone mapping
  4. water/         — الماء: صفاء، موج، caustics (منظرة ضو تحت الماء)
  5. shadows/       — نوع الظلال
  6. fogs/          — ضباب لكل بايوم (85 بايوم) فوق الفانيلا
  7. biomes/        — ملفات client_biome كتربط كل حاجة بكل بايوم
  8. pbr/global.json — القيم الافتراضية للخامات لي ماعندهاش texture set

المرجع الرسمي: learn.microsoft.com/minecraft/creator/documents/vibrantvisuals
"""
from __future__ import annotations

import pathlib

from common import (DATA_DIR, SRC_DIR, Report, clean_dir, hex_to_rgb, load_json,
                    log, write_json)

VANILLA_BIOMES = load_json(DATA_DIR / "vanilla_biomes.json")
VANILLA_FOGS = DATA_DIR / "vanilla_fogs"      # نسخة من ملفات الضباب الرسمية


def kf(d: dict) -> dict:
    """كنصلحو مفاتيح الـ keyframes باش تكون نص بـ 6 أرقام عشرية (الصيغة الرسمية)"""
    return {f"{float(k):.6f}": v for k, v in d.items()}


# ============================================================================
# 1) الأجواء — variants
# ============================================================================
# كل variant فيه: zenith/horizon (بالكيفrames)، rayleigh، mie، glare
ATMO_VARIANTS: dict[str, dict] = {
    "default": dict(
        zenith={0.0: [96, 128, 176], 0.20: [96, 128, 176], 0.3526: [32, 38, 58],
                0.6449: [32, 38, 58], 0.80: [96, 128, 176]},
        horizon={0.0: [176, 196, 216], 0.167: [186, 202, 218], 0.217: [246, 176, 136],
                 0.2393: [255, 168, 132], 0.2764: [140, 108, 116], 0.3615: [150, 156, 216],
                 0.4018: [74, 108, 154], 0.617: [74, 108, 154], 0.6545: [140, 142, 226],
                 0.7069: [226, 180, 220], 0.7487: [255, 200, 160], 0.7864: [226, 206, 186],
                 0.83: [176, 196, 216]},
        rayleigh={0.0: 11.0, 0.1387: 11.0, 0.25: 5.5, 0.3304: 5.5, 0.6407: 5.5,
                  0.7174: 5.5, 0.9293: 11.0, 1.0: 11.0},
        sun_mie={0.0: 0.0, 0.2: 0.0, 0.25: 0.95, 0.4: 0.0, 0.6: 0.0, 0.75: 0.95,
                 0.8: 0.0, 1.0: 0.0},
        moon_mie={0.0: 0.0, 0.3: 0.25, 0.6: 0.25, 0.75: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 0.2: 0.0, 0.25: 0.09, 0.4: 0.0, 0.6: 0.0, 0.75: 0.09,
               0.8: 0.0, 1.0: 0.0},
    ),
    "warmish": dict(
        zenith={0.0: [88, 118, 158], 0.20: [88, 118, 158], 0.3526: [30, 34, 50],
                0.6449: [30, 34, 50], 0.80: [88, 118, 158]},
        horizon={0.0: [188, 200, 208], 0.167: [198, 204, 210], 0.217: [252, 168, 122],
                 0.2393: [255, 158, 118], 0.2764: [138, 100, 104], 0.3615: [144, 146, 206],
                 0.4018: [70, 102, 148], 0.617: [70, 102, 148], 0.6545: [150, 138, 220],
                 0.7069: [232, 176, 214], 0.7487: [255, 192, 148], 0.7864: [232, 204, 180],
                 0.83: [188, 200, 208]},
        rayleigh={0.0: 12.0, 0.1387: 12.0, 0.25: 6.0, 0.3304: 6.0, 0.6407: 6.0,
                  0.7174: 6.0, 0.9293: 12.0, 1.0: 12.0},
        sun_mie={0.0: 0.0, 0.2: 0.0, 0.25: 1.05, 0.4: 0.0, 0.6: 0.0, 0.75: 1.05,
                 0.8: 0.0, 1.0: 0.0},
        moon_mie={0.0: 0.0, 0.3: 0.22, 0.6: 0.22, 0.75: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 0.2: 0.0, 0.25: 0.10, 0.4: 0.0, 0.6: 0.0, 0.75: 0.10,
               0.8: 0.0, 1.0: 0.0},
    ),
    "jungle": dict(
        zenith={0.0: [84, 132, 150], 0.20: [84, 132, 150], 0.3526: [26, 38, 44],
                0.6449: [26, 38, 44], 0.80: [84, 132, 150]},
        horizon={0.0: [186, 206, 196], 0.167: [196, 212, 200], 0.217: [248, 188, 132],
                 0.2393: [255, 182, 130], 0.2764: [140, 116, 108], 0.3615: [140, 168, 190],
                 0.4018: [72, 116, 142], 0.617: [72, 116, 142], 0.6545: [148, 156, 214],
                 0.7069: [226, 196, 210], 0.7487: [255, 206, 164], 0.7864: [222, 214, 190],
                 0.83: [186, 206, 196]},
        rayleigh={0.0: 10.0, 0.25: 5.0, 0.3304: 5.0, 0.6407: 5.0, 0.7174: 5.0,
                  0.9293: 10.0, 1.0: 10.0},
        sun_mie={0.0: 0.05, 0.25: 0.9, 0.4: 0.05, 0.6: 0.05, 0.75: 0.9, 0.8: 0.05, 1.0: 0.05},
        moon_mie={0.0: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 0.25: 0.08, 0.4: 0.0, 0.6: 0.0, 0.75: 0.08, 1.0: 0.0},
    ),
    "cold": dict(
        zenith={0.0: [104, 138, 190], 0.20: [104, 138, 190], 0.3526: [26, 36, 62],
                0.6449: [26, 36, 62], 0.80: [104, 138, 190]},
        horizon={0.0: [196, 214, 236], 0.167: [204, 218, 238], 0.217: [242, 186, 176],
                 0.2393: [248, 182, 176], 0.2764: [132, 116, 140], 0.3615: [150, 164, 226],
                 0.4018: [78, 112, 168], 0.617: [78, 112, 168], 0.6545: [146, 156, 232],
                 0.7069: [214, 190, 232], 0.7487: [250, 208, 190], 0.7864: [222, 216, 220],
                 0.83: [196, 214, 236]},
        rayleigh={0.0: 12.5, 0.25: 5.5, 0.3304: 5.5, 0.6407: 5.5, 0.7174: 5.5,
                  0.9293: 12.5, 1.0: 12.5},
        sun_mie={0.0: 0.0, 0.25: 0.8, 0.4: 0.0, 0.6: 0.0, 0.75: 0.8, 0.8: 0.0, 1.0: 0.0},
        moon_mie={0.0: 0.0, 0.3: 0.35, 0.6: 0.35, 0.75: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 0.25: 0.07, 0.4: 0.0, 0.6: 0.0, 0.75: 0.07, 1.0: 0.0},
    ),
    "desert": dict(
        zenith={0.0: [110, 142, 184], 0.20: [110, 142, 184], 0.3526: [34, 36, 54],
                0.6449: [34, 36, 54], 0.80: [110, 142, 184]},
        horizon={0.0: [220, 210, 190], 0.167: [228, 214, 190], 0.217: [255, 186, 128],
                 0.2393: [255, 176, 122], 0.2764: [156, 118, 100], 0.3615: [156, 160, 210],
                 0.4018: [86, 116, 158], 0.617: [86, 116, 158], 0.6545: [156, 152, 226],
                 0.7069: [236, 190, 212], 0.7487: [255, 202, 156], 0.7864: [238, 214, 184],
                 0.83: [220, 210, 190]},
        rayleigh={0.0: 9.0, 0.25: 4.5, 0.3304: 4.5, 0.6407: 4.5, 0.7174: 4.5,
                  0.9293: 9.0, 1.0: 9.0},
        sun_mie={0.0: 0.15, 0.25: 1.15, 0.4: 0.15, 0.6: 0.15, 0.75: 1.15, 0.8: 0.15, 1.0: 0.15},
        moon_mie={0.0: 0.0, 1.0: 0.0},
        glare={0.0: 0.02, 0.25: 0.12, 0.4: 0.02, 0.6: 0.02, 0.75: 0.12, 1.0: 0.02},
    ),
    "mesa": dict(
        zenith={0.0: [108, 134, 172], 0.20: [108, 134, 172], 0.3526: [36, 32, 48],
                0.6449: [36, 32, 48], 0.80: [108, 134, 172]},
        horizon={0.0: [222, 200, 178], 0.167: [230, 204, 178], 0.217: [255, 176, 118],
                 0.2393: [255, 164, 110], 0.2764: [158, 108, 94], 0.3615: [158, 150, 200],
                 0.4018: [92, 108, 150], 0.617: [92, 108, 150], 0.6545: [164, 146, 220],
                 0.7069: [240, 186, 206], 0.7487: [255, 196, 146], 0.7864: [240, 206, 176],
                 0.83: [222, 200, 178]},
        rayleigh={0.0: 9.5, 0.25: 4.8, 0.3304: 4.8, 0.6407: 4.8, 0.7174: 4.8,
                  0.9293: 9.5, 1.0: 9.5},
        sun_mie={0.0: 0.1, 0.25: 1.1, 0.4: 0.1, 0.6: 0.1, 0.75: 1.1, 0.8: 0.1, 1.0: 0.1},
        moon_mie={0.0: 0.0, 1.0: 0.0},
        glare={0.0: 0.02, 0.25: 0.11, 0.4: 0.02, 0.6: 0.02, 0.75: 0.11, 1.0: 0.02},
    ),
    "swamp": dict(
        zenith={0.0: [92, 122, 148], 0.20: [92, 122, 148], 0.3526: [30, 36, 46],
                0.6449: [30, 36, 46], 0.80: [92, 122, 148]},
        horizon={0.0: [178, 196, 186], 0.167: [188, 202, 190], 0.217: [242, 178, 138],
                 0.2393: [248, 172, 136], 0.2764: [132, 108, 106], 0.3615: [130, 152, 178],
                 0.4018: [70, 104, 132], 0.617: [70, 104, 132], 0.6545: [136, 144, 200],
                 0.7069: [214, 186, 206], 0.7487: [246, 196, 162], 0.7864: [214, 202, 184],
                 0.83: [178, 196, 186]},
        rayleigh={0.0: 8.5, 0.25: 4.5, 0.3304: 4.5, 0.6407: 4.5, 0.7174: 4.5,
                  0.9293: 8.5, 1.0: 8.5},
        sun_mie={0.0: 0.25, 0.25: 1.0, 0.4: 0.25, 0.6: 0.25, 0.75: 1.0, 0.8: 0.25, 1.0: 0.25},
        moon_mie={0.0: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 0.25: 0.07, 0.4: 0.0, 0.6: 0.0, 0.75: 0.07, 1.0: 0.0},
    ),
    "dark_forest": dict(
        zenith={0.0: [78, 106, 138], 0.20: [78, 106, 138], 0.3526: [24, 30, 44],
                0.6449: [24, 30, 44], 0.80: [78, 106, 138]},
        horizon={0.0: [158, 178, 194], 0.167: [168, 184, 196], 0.217: [238, 172, 132],
                 0.2393: [244, 166, 130], 0.2764: [124, 104, 108], 0.3615: [122, 142, 172],
                 0.4018: [62, 94, 126], 0.617: [62, 94, 126], 0.6545: [128, 134, 194],
                 0.7069: [206, 178, 200], 0.7487: [240, 190, 156], 0.7864: [206, 194, 180],
                 0.83: [158, 178, 194]},
        rayleigh={0.0: 8.0, 0.25: 4.2, 0.3304: 4.2, 0.6407: 4.2, 0.7174: 4.2,
                  0.9293: 8.0, 1.0: 8.0},
        sun_mie={0.0: 0.3, 0.25: 0.9, 0.4: 0.3, 0.6: 0.3, 0.75: 0.9, 0.8: 0.3, 1.0: 0.3},
        moon_mie={0.0: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 0.25: 0.06, 0.4: 0.0, 0.6: 0.0, 0.75: 0.06, 1.0: 0.0},
    ),
    "mushroom": dict(
        zenith={0.0: [120, 132, 180], 0.20: [120, 132, 180], 0.3526: [40, 38, 62],
                0.6449: [40, 38, 62], 0.80: [120, 132, 180]},
        horizon={0.0: [204, 196, 224], 0.167: [212, 200, 226], 0.217: [252, 190, 190],
                 0.2393: [255, 184, 186], 0.2764: [150, 124, 150], 0.3615: [162, 158, 232],
                 0.4018: [94, 118, 172], 0.617: [94, 118, 172], 0.6545: [170, 156, 240],
                 0.7069: [240, 200, 232], 0.7487: [255, 206, 196], 0.7864: [236, 216, 224],
                 0.83: [204, 196, 224]},
        rayleigh={0.0: 11.0, 0.25: 5.5, 0.3304: 5.5, 0.6407: 5.5, 0.7174: 5.5,
                  0.9293: 11.0, 1.0: 11.0},
        sun_mie={0.0: 0.0, 0.25: 0.85, 0.4: 0.0, 0.6: 0.0, 0.75: 0.85, 0.8: 0.0, 1.0: 0.0},
        moon_mie={0.0: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 0.25: 0.08, 0.4: 0.0, 0.6: 0.0, 0.75: 0.08, 1.0: 0.0},
    ),
    "pale_garden": dict(
        zenith={0.0: [122, 130, 140], 0.20: [122, 130, 140], 0.3526: [34, 36, 42],
                0.6449: [34, 36, 42], 0.80: [122, 130, 140]},
        horizon={0.0: [196, 200, 204], 0.167: [204, 206, 208], 0.217: [232, 190, 178],
                 0.2393: [238, 186, 176], 0.2764: [130, 122, 126], 0.3615: [148, 156, 168],
                 0.4018: [84, 96, 112], 0.617: [84, 96, 112], 0.6545: [150, 152, 176],
                 0.7069: [216, 206, 214], 0.7487: [240, 210, 196], 0.7864: [214, 210, 206],
                 0.83: [196, 200, 204]},
        rayleigh={0.0: 7.5, 0.25: 4.0, 0.3304: 4.0, 0.6407: 4.0, 0.7174: 4.0,
                  0.9293: 7.5, 1.0: 7.5},
        sun_mie={0.0: 0.35, 0.25: 0.8, 0.4: 0.35, 0.6: 0.35, 0.75: 0.8, 0.8: 0.35, 1.0: 0.35},
        moon_mie={0.0: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 0.25: 0.05, 0.4: 0.0, 0.6: 0.0, 0.75: 0.05, 1.0: 0.0},
    ),
    "snow_peaks": dict(
        zenith={0.0: [118, 150, 200], 0.20: [118, 150, 200], 0.3526: [30, 40, 68],
                0.6449: [30, 40, 68], 0.80: [118, 150, 200]},
        horizon={0.0: [214, 226, 244], 0.167: [220, 230, 246], 0.217: [250, 196, 186],
                 0.2393: [252, 192, 184], 0.2764: [140, 126, 150], 0.3615: [164, 176, 236],
                 0.4018: [88, 120, 176], 0.617: [88, 120, 176], 0.6545: [156, 164, 240],
                 0.7069: [222, 198, 238], 0.7487: [252, 214, 196], 0.7864: [230, 224, 228],
                 0.83: [214, 226, 244]},
        rayleigh={0.0: 13.0, 0.25: 6.0, 0.3304: 6.0, 0.6407: 6.0, 0.7174: 6.0,
                  0.9293: 13.0, 1.0: 13.0},
        sun_mie={0.0: 0.0, 0.25: 0.75, 0.4: 0.0, 0.6: 0.0, 0.75: 0.75, 0.8: 0.0, 1.0: 0.0},
        moon_mie={0.0: 0.0, 0.3: 0.4, 0.6: 0.4, 0.75: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 0.25: 0.06, 0.4: 0.0, 0.6: 0.0, 0.75: 0.06, 1.0: 0.0},
    ),
    "nether": dict(
        zenith={0.0: [58, 22, 18], 1.0: [58, 22, 18]},
        horizon={0.0: [118, 40, 22], 1.0: [118, 40, 22]},
        rayleigh={0.0: 2.0, 1.0: 2.0},
        sun_mie={0.0: 0.0, 1.0: 0.0},
        moon_mie={0.0: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 1.0: 0.0},
    ),
    "soulsand": dict(
        zenith={0.0: [22, 34, 52], 1.0: [22, 34, 52]},
        horizon={0.0: [58, 96, 128], 1.0: [58, 96, 128]},
        rayleigh={0.0: 2.5, 1.0: 2.5},
        sun_mie={0.0: 0.0, 1.0: 0.0},
        moon_mie={0.0: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 1.0: 0.0},
    ),
    "crimson": dict(
        zenith={0.0: [46, 16, 26], 1.0: [46, 16, 26]},
        horizon={0.0: [106, 30, 38], 1.0: [106, 30, 38]},
        rayleigh={0.0: 2.0, 1.0: 2.0},
        sun_mie={0.0: 0.0, 1.0: 0.0},
        moon_mie={0.0: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 1.0: 0.0},
    ),
    "warped": dict(
        zenith={0.0: [16, 44, 46], 1.0: [16, 44, 46]},
        horizon={0.0: [30, 108, 104], 1.0: [30, 108, 104]},
        rayleigh={0.0: 2.0, 1.0: 2.0},
        sun_mie={0.0: 0.0, 1.0: 0.0},
        moon_mie={0.0: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 1.0: 0.0},
    ),
    "basalt": dict(
        zenith={0.0: [38, 34, 40], 1.0: [38, 34, 40]},
        horizon={0.0: [74, 66, 74], 1.0: [74, 66, 74]},
        rayleigh={0.0: 2.0, 1.0: 2.0},
        sun_mie={0.0: 0.0, 1.0: 0.0},
        moon_mie={0.0: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 1.0: 0.0},
    ),
    "end": dict(
        zenith={0.0: [26, 18, 44], 1.0: [26, 18, 44]},
        horizon={0.0: [62, 44, 92], 1.0: [62, 44, 92]},
        rayleigh={0.0: 1.5, 1.0: 1.5},
        sun_mie={0.0: 0.0, 1.0: 0.0},
        moon_mie={0.0: 0.0, 1.0: 0.0},
        glare={0.0: 0.0, 1.0: 0.0},
    ),
}

# حدود الأفق (كيف الفانيلا — مالازمش نبدلوها)
HORIZON_BLEND_STOPS = {
    "min": kf({0.0: 0.0, 1.0: 0.0}),
    "start": kf({0.0: 0.8, 0.25: 0.5, 0.300912: 0.25, 0.75: 0.25, 0.827004: 0.5, 1.0: 0.8}),
    "mie_start": kf({0.0: 0.5, 0.1: 0.5, 0.2: 1.0, 0.8: 1.0, 0.9: 0.5, 1.0: 0.5}),
    "max": kf({0.0: 0.25, 1.0: 0.25}),
}


def build_atmospherics() -> None:
    out = SRC_DIR / "atmospherics"
    clean_dir(out)
    for name, v in ATMO_VARIANTS.items():
        data = {
            "format_version": "1.21.40",
            "minecraft:atmosphere_settings": {
                "description": {"identifier": f"cinematic:{name}_atmospherics"},
                "horizon_blend_stops": HORIZON_BLEND_STOPS,
                "rayleigh_strength": kf(v["rayleigh"]),
                "sun_mie_strength": kf(v["sun_mie"]),
                "moon_mie_strength": kf(v["moon_mie"]),
                "sun_glare_shape": kf(v["glare"]),
                "sky_zenith_color": kf(v["zenith"]),
                "sky_horizon_color": kf(v["horizon"]),
            },
        }
        write_json(out / f"{name}.atmospherics.json", data)
    log(f"✅ atmospherics: {len(ATMO_VARIANTS)} نسخة (default/warmish/jungle/cold/desert/mesa/swamp/dark_forest/mushroom/pale_garden/snow_peaks/nether/soulsand/crimson/warped/basalt/end)")


# ============================================================================
# 2) الإضاءة
# ============================================================================
SUN_ILLUM = kf({0.0: 105.0, 0.05: 105.0, 0.14: 78.0, 0.20: 34.0, 0.25: 8.0, 0.282: 0.6,
                0.2915: 0.02, 0.5: 0.0, 0.709: 0.02, 0.719: 0.6, 0.75: 8.0, 0.80: 34.0,
                0.86: 78.0, 0.95: 105.0, 1.0: 105.0})
SUN_COLOR = kf({0.0: [255, 232, 208], 0.14: [255, 196, 142], 0.2169: [255, 152, 96],
                0.2429: [255, 124, 74], 0.2695: [255, 118, 70], 0.3146: [255, 140, 128],
                0.507: [255, 108, 76], 0.7179: [255, 138, 132], 0.8011: [255, 170, 96],
                1.0: [255, 232, 208]})
MOON_ILLUM = kf({0.0: 0.0, 0.2: 0.0, 0.225: 0.5, 0.5: 0.5, 0.735: 0.5, 0.75: 0.0, 1.0: 0.0})

LIGHT_VARIANTS = {
    "default": dict(ambient_color="#B9CBE8", ambient=0.028, sky=0.92, emissive=0.12,
                    moon_color=[196, 214, 255]),
    "warmish": dict(ambient_color="#C6C4DE", ambient=0.030, sky=0.95, emissive=0.14,
                    moon_color=[198, 210, 255]),
    "jungle": dict(ambient_color="#AECBB2", ambient=0.034, sky=0.95, emissive=0.16,
                   moon_color=[186, 214, 226]),
    "cold": dict(ambient_color="#BCCCE8", ambient=0.032, sky=0.97, emissive=0.12,
                 moon_color=[180, 202, 255]),
    "desert": dict(ambient_color="#E0CFB0", ambient=0.030, sky=0.90, emissive=0.16,
                   moon_color=[208, 210, 240]),
    "mesa": dict(ambient_color="#DCBB9A", ambient=0.029, sky=0.90, emissive=0.15,
                 moon_color=[206, 202, 234]),
    "swamp": dict(ambient_color="#A8B49C", ambient=0.032, sky=0.93, emissive=0.18,
                  moon_color=[186, 208, 214]),
    "dark_forest": dict(ambient_color="#9AB0C0", ambient=0.022, sky=0.85, emissive=0.14,
                        moon_color=[174, 196, 240]),
    "mushroom": dict(ambient_color="#BEB6D8", ambient=0.032, sky=0.93, emissive=0.18,
                     moon_color=[196, 196, 250]),
    "pale_garden": dict(ambient_color="#B4B8BE", ambient=0.024, sky=0.86, emissive=0.14,
                        moon_color=[186, 194, 206]),
    "snow_peaks": dict(ambient_color="#C8D8F0", ambient=0.034, sky=1.0, emissive=0.12,
                       moon_color=[186, 208, 255]),
    "nether": dict(ambient_color="#7E3A24", ambient=0.05, sky=1.0, emissive=0.06,
                   moon_color=[255, 160, 120]),
    "soulsand": dict(ambient_color="#4E7E92", ambient=0.045, sky=1.0, emissive=0.06,
                     moon_color=[160, 220, 240]),
    "crimson": dict(ambient_color="#8A3A40", ambient=0.045, sky=1.0, emissive=0.08,
                    moon_color=[255, 170, 180]),
    "warped": dict(ambient_color="#3E8A86", ambient=0.045, sky=1.0, emissive=0.08,
                   moon_color=[170, 240, 230]),
    "basalt": dict(ambient_color="#6E6A72", ambient=0.05, sky=1.0, emissive=0.06,
                   moon_color=[210, 210, 220]),
    "end": dict(ambient_color="#8E7ECB", ambient=0.03, sky=1.0, emissive=0.10,
                moon_color=[214, 176, 255]),
}


def build_lighting() -> None:
    out = SRC_DIR / "lighting"
    clean_dir(out)
    for name, v in LIGHT_VARIANTS.items():
        data = {
            "format_version": "1.21.80",
            "minecraft:lighting_settings": {
                "description": {"identifier": f"cinematic:{name}_lighting"},
                "directional_lights": {
                    "orbital": {
                        "sun": {"illuminance": SUN_ILLUM, "color": SUN_COLOR},
                        "moon": {"illuminance": MOON_ILLUM,
                                 "color": kf({0.0: v["moon_color"], 1.0: v["moon_color"]})},
                        "orbital_offset_degrees": 0.0,
                    },
                    "flash": {"illuminance": 12.0, "color": [222, 150, 255]},
                },
                "emissive": {"desaturation": v["emissive"]},
                "ambient": {"color": v["ambient_color"],
                            "illuminance": v["ambient"]},
                "sky": {"intensity": v["sky"]},
            },
        }
        write_json(out / f"{name}.lighting.json", data)
    log(f"✅ lighting: {len(LIGHT_VARIANTS)} نسخة (شمس بلون دافي + قمر أزرق + ظلال أعمق)")


# ============================================================================
# 3) تصحيح الألوان + tone mapping
# ============================================================================
# السينمائي: تباين، ألوان دافية فالضوء، وباردة فالظلال
GRADE_VARIANTS = {
    "default": dict(temp=6350, mid=dict(contrast=[1.22, 1.22, 1.20], gain=[1.02, 1.0, 0.985],
                                        gamma=[2.15, 2.18, 2.25], offset=[0.0, 0.0, 0.0],
                                        saturation=[1.08, 1.08, 1.08]),
                    hi=dict(enabled=True, min=1.45, gain=[1.03, 1.0, 0.965],
                             saturation=[1.02, 1.02, 1.02], contrast=[1.05, 1.05, 1.05]),
                    sh=dict(enabled=True, max=0.55, gain=[0.97, 0.99, 1.06],
                            saturation=[1.0, 1.0, 1.02])),
    "warmish": dict(temp=6250, mid=dict(contrast=[1.20, 1.20, 1.20], gain=[1.03, 1.005, 0.98],
                                        gamma=[2.15, 2.18, 2.24], offset=[0.0, 0.0, 0.0],
                                        saturation=[1.10, 1.09, 1.07]),
                    hi=dict(enabled=True, min=1.45, gain=[1.04, 1.005, 0.96]),
                    sh=dict(enabled=True, max=0.55, gain=[0.975, 0.99, 1.05])),
    "jungle": dict(temp=6300, mid=dict(contrast=[1.24, 1.24, 1.22], gain=[0.995, 1.03, 1.0],
                                       gamma=[2.13, 2.17, 2.24], offset=[0.0, 0.0, 0.0],
                                       saturation=[1.10, 1.12, 1.08]),
                   hi=dict(enabled=True, min=1.5, gain=[1.0, 1.03, 0.99]),
                   sh=dict(enabled=True, max=0.55, gain=[0.96, 1.0, 1.05])),
    "cold": dict(temp=6800, mid=dict(contrast=[1.24, 1.24, 1.24], gain=[0.99, 1.0, 1.03],
                                     gamma=[2.15, 2.18, 2.26], offset=[0.0, 0.0, 0.0],
                                     saturation=[1.06, 1.07, 1.10]),
                 hi=dict(enabled=True, min=1.5, gain=[0.99, 1.0, 1.02]),
                 sh=dict(enabled=True, max=0.55, gain=[0.96, 0.99, 1.07])),
    "desert": dict(temp=6100, mid=dict(contrast=[1.18, 1.18, 1.18], gain=[1.045, 1.02, 0.97],
                                       gamma=[2.15, 2.18, 2.24], offset=[0.0, 0.0, 0.0],
                                       saturation=[1.06, 1.05, 1.03]),
                   hi=dict(enabled=True, min=1.45, gain=[1.05, 1.02, 0.96]),
                   sh=dict(enabled=True, max=0.55, gain=[0.98, 0.99, 1.04])),
    "mesa": dict(temp=6150, mid=dict(contrast=[1.22, 1.20, 1.18], gain=[1.04, 1.005, 0.965],
                                     gamma=[2.14, 2.18, 2.25], offset=[0.0, 0.0, 0.0],
                                     saturation=[1.07, 1.05, 1.02]),
                 hi=dict(enabled=True, min=1.45, gain=[1.05, 1.01, 0.95]),
                 sh=dict(enabled=True, max=0.55, gain=[0.98, 0.985, 1.03])),
    "swamp": dict(temp=6500, mid=dict(contrast=[1.26, 1.26, 1.24], gain=[0.995, 1.02, 0.995],
                                      gamma=[2.14, 2.17, 2.24], offset=[0.0, 0.0, 0.0],
                                      saturation=[1.08, 1.10, 1.04]),
                  hi=dict(enabled=True, min=1.5, gain=[1.0, 1.02, 0.99]),
                  sh=dict(enabled=True, max=0.55, gain=[0.96, 0.99, 1.05])),
    "dark_forest": dict(temp=6600, mid=dict(contrast=[1.28, 1.28, 1.26], gain=[0.98, 0.99, 1.01],
                                            gamma=[2.12, 2.16, 2.24], offset=[0.0, 0.0, 0.0],
                                            saturation=[1.06, 1.08, 1.06]),
                        hi=dict(enabled=True, min=1.55, gain=[1.0, 1.01, 1.0]),
                        sh=dict(enabled=True, max=0.5, gain=[0.95, 0.98, 1.06])),
    "mushroom": dict(temp=6400, mid=dict(contrast=[1.20, 1.20, 1.20], gain=[1.01, 0.995, 1.03],
                                         gamma=[2.16, 2.18, 2.26], offset=[0.0, 0.0, 0.0],
                                         saturation=[1.09, 1.07, 1.12]),
                     hi=dict(enabled=True, min=1.5, gain=[1.01, 1.0, 1.03]),
                     sh=dict(enabled=True, max=0.55, gain=[0.97, 0.98, 1.06])),
    "pale_garden": dict(temp=6600, mid=dict(contrast=[1.30, 1.30, 1.28], gain=[0.97, 0.975, 0.985],
                                            gamma=[2.12, 2.16, 2.24], offset=[0.0, 0.0, 0.0],
                                            saturation=[0.94, 0.95, 0.96]),
                        hi=dict(enabled=True, min=1.55, gain=[0.99, 0.99, 1.0]),
                        sh=dict(enabled=True, max=0.5, gain=[0.94, 0.96, 1.03])),
    "snow_peaks": dict(temp=7000, mid=dict(contrast=[1.24, 1.24, 1.24], gain=[0.995, 1.0, 1.04],
                                           gamma=[2.16, 2.19, 2.28], offset=[0.0, 0.0, 0.0],
                                           saturation=[1.04, 1.06, 1.10]),
                       hi=dict(enabled=True, min=1.55, gain=[0.995, 1.0, 1.04]),
                       sh=dict(enabled=True, max=0.55, gain=[0.96, 0.99, 1.08])),
    "nether": dict(temp=5600, mid=dict(contrast=[1.30, 1.26, 1.24], gain=[1.06, 0.985, 0.95],
                                       gamma=[2.12, 2.16, 2.24], offset=[0.0, 0.0, 0.0],
                                       saturation=[1.10, 1.04, 0.96]),
                   hi=dict(enabled=True, min=1.45, gain=[1.06, 0.99, 0.92]),
                   sh=dict(enabled=True, max=0.55, gain=[0.98, 0.96, 1.0])),
    "soulsand": dict(temp=5200, mid=dict(contrast=[1.28, 1.26, 1.26], gain=[0.94, 1.02, 1.08],
                                         gamma=[2.12, 2.16, 2.26], offset=[0.0, 0.0, 0.0],
                                         saturation=[0.98, 1.06, 1.12]),
                     hi=dict(enabled=True, min=1.5, gain=[0.95, 1.02, 1.08]),
                     sh=dict(enabled=True, max=0.55, gain=[0.95, 0.99, 1.06])),
    "crimson": dict(temp=5800, mid=dict(contrast=[1.28, 1.26, 1.24], gain=[1.05, 0.97, 0.99],
                                        gamma=[2.12, 2.16, 2.24], offset=[0.0, 0.0, 0.0],
                                        saturation=[1.08, 0.99, 1.02]),
                    hi=dict(enabled=True, min=1.5, gain=[1.05, 0.97, 0.99]),
                    sh=dict(enabled=True, max=0.55, gain=[0.98, 0.95, 1.0])),
    "warped": dict(temp=6000, mid=dict(contrast=[1.26, 1.26, 1.26], gain=[0.97, 1.02, 1.05],
                                       gamma=[2.13, 2.17, 2.26], offset=[0.0, 0.0, 0.0],
                                       saturation=[0.99, 1.06, 1.08]),
                   hi=dict(enabled=True, min=1.5, gain=[0.97, 1.02, 1.05]),
                   sh=dict(enabled=True, max=0.55, gain=[0.96, 0.99, 1.05])),
    "basalt": dict(temp=6000, mid=dict(contrast=[1.28, 1.28, 1.28], gain=[1.0, 0.99, 1.0],
                                       gamma=[2.13, 2.16, 2.24], offset=[0.0, 0.0, 0.0],
                                       saturation=[0.96, 0.97, 1.02]),
                   hi=dict(enabled=True, min=1.5, gain=[1.0, 0.99, 1.0]),
                   sh=dict(enabled=True, max=0.5, gain=[0.96, 0.97, 1.02])),
    "end": dict(temp=6200, mid=dict(contrast=[1.28, 1.26, 1.26], gain=[0.99, 0.96, 1.09],
                                    gamma=[2.13, 2.17, 2.28], offset=[0.0, 0.0, 0.0],
                                    saturation=[0.98, 0.95, 1.10]),
                hi=dict(enabled=True, min=1.5, gain=[0.99, 0.96, 1.10]),
                sh=dict(enabled=True, max=0.55, gain=[0.96, 0.95, 1.08])),
}


def build_grading(lite: bool = False) -> None:
    out = SRC_DIR / "color_grading"
    clean_dir(out)
    for name, v in GRADE_VARIANTS.items():
        cg = {"midtones": {"contrast": v["mid"]["contrast"],
                           "gain": v["mid"]["gain"],
                           "gamma": v["mid"]["gamma"],
                           "offset": v["mid"]["offset"],
                           "saturation": v["mid"]["saturation"]}}
        if "hi" in v:
            hi = dict(v["hi"])
            hi.setdefault("contrast", [1.0, 1.0, 1.0])
            hi.setdefault("gamma", [2.2, 2.2, 2.2])
            hi.setdefault("offset", [0.0, 0.0, 0.0])
            hi["highlightsMin"] = hi.pop("min")
            hi.setdefault("saturation", [1.0, 1.0, 1.0])
            cg["highlights"] = hi
        if "sh" in v:
            sh = dict(v["sh"])
            sh.setdefault("contrast", [1.0, 1.0, 1.0])
            sh.setdefault("gamma", [2.2, 2.2, 2.2])
            sh.setdefault("offset", [0.0, 0.0, 0.0])
            sh["shadowsMax"] = sh.pop("max")
            sh.setdefault("saturation", [1.0, 1.0, 1.0])
            cg["shadows"] = sh
        cg["temperature"] = {"enabled": True, "temperature": v["temp"],
                             "type": "color_temperature"}
        data = {
            "format_version": "1.21.90",
            "minecraft:color_grading_settings": {
                "description": {"identifier": f"cinematic:{name}_color_grading"},
                "color_grading": cg,
                # ACES = بحال الأفلام (ثقيل شوية) — فالنسخة الخفيفة كنستعملو generic
                "tone_mapping": {"operator": "generic" if lite else "aces"},
            },
        }
        write_json(out / f"{name}.color_grading.json", data)
    log(f"✅ color_grading: {len(GRADE_VARIANTS)} نسخة (تباين سينمائي + حرارة + tone mapping {'generic' if lite else 'ACES'})")


# ============================================================================
# 4) الماء
# ============================================================================
WATER_VARIANTS = {
    "default_water": dict(chl=0.35, sed=0.6, cdom=0.6,
                          waves=dict(enabled=True, depth=0.12, direction_increment=55.0,
                                     frequency=1.4, frequency_scaling=1.15, mix=0.18,
                                     octaves=18, pull=0.35, sampleWidth=0.02, shape=1.6,
                                     speed=1.1, speed_scaling=1.02),
                          caustics=dict(enabled=True, frame_length=0.09, power=2, scale=0.45)),
    "ocean_water": dict(chl=0.55, sed=0.35, cdom=0.2,
                        waves=dict(enabled=True, depth=0.22, direction_increment=70.0,
                                   frequency=1.6, frequency_scaling=1.18, mix=0.22,
                                   octaves=24, pull=0.4, sampleWidth=0.015, shape=1.8,
                                   speed=1.35, speed_scaling=1.03),
                        caustics=dict(enabled=True, frame_length=0.07, power=2, scale=0.4)),
    "river_water": dict(chl=0.9, sed=3.2, cdom=2.4,
                        waves=dict(enabled=True, depth=0.07, direction_increment=40.0,
                                   frequency=2.0, frequency_scaling=1.1, mix=0.15,
                                   octaves=14, pull=0.3, sampleWidth=0.03, shape=1.4,
                                   speed=1.7, speed_scaling=1.0),
                        caustics=dict(enabled=True, frame_length=0.11, power=1, scale=0.55)),
    "swamp_water": dict(chl=3.2, sed=4.5, cdom=6.5,
                        waves=dict(enabled=True, depth=0.04, direction_increment=30.0,
                                   frequency=1.2, frequency_scaling=1.05, mix=0.12,
                                   octaves=10, pull=0.2, sampleWidth=0.04, shape=1.2,
                                   speed=0.7, speed_scaling=1.0),
                        caustics=dict(enabled=True, frame_length=0.16, power=1, scale=0.65)),
    "warm_water": dict(chl=0.75, sed=0.5, cdom=0.3,
                       waves=dict(enabled=True, depth=0.16, direction_increment=60.0,
                                  frequency=1.5, frequency_scaling=1.16, mix=0.2,
                                  octaves=20, pull=0.36, sampleWidth=0.018, shape=1.7,
                                  speed=1.2, speed_scaling=1.02),
                       caustics=dict(enabled=True, frame_length=0.08, power=2, scale=0.42)),
}


def build_water(lite: bool = False) -> None:
    out = SRC_DIR / "water"
    clean_dir(out)
    for name, v in WATER_VARIANTS.items():
        waves = dict(v["waves"])
        caustics = dict(v["caustics"])
        if lite:
            # النسخة الخفيفة: موج أهدأ و octaves أقل و caustics أرخى
            waves["octaves"] = max(6, waves["octaves"] // 3)
            waves["depth"] = round(waves["depth"] * 0.7, 3)
            caustics["frame_length"] = round(min(0.25, caustics["frame_length"] * 1.6), 3)
            caustics["power"] = 1
        data = {
            "format_version": "1.21.120",
            "minecraft:water_settings": {
                "description": {"identifier": f"cinematic:{name}"},
                "particle_concentrations": {"chlorophyll": v["chl"],
                                            "suspended_sediment": v["sed"],
                                            "cdom": v["cdom"]},
                "waves": waves,
                "caustics": caustics,
            },
        }
        write_json(out / f"{name}.water.json", data)
    log(f"✅ water: {len(WATER_VARIANTS)} نوع (بحيرة صافية، محيط، نهر، مستنقع، ماء دافي) + موج + caustics")


# ============================================================================
# 5) الظلال
# ============================================================================
def build_shadows() -> None:
    out = SRC_DIR / "shadows"
    clean_dir(out)
    write_json(out / "shadows.json", {
        "format_version": "1.21.80",
        "minecraft:shadow_settings": {"shadow_style": "soft_shadows", "texel_size": 16},
    })
    log("✅ shadows: ظلال ناعمة (soft_shadows)")


# ============================================================================
# 6) Fogs — ضباب لكل بايوم (كنديرو بلوك الهواء فوق الضباب الرسمي)
# ============================================================================
# (بداية الضباب, لون النهار) حسب نوع البايوم
FOG_STYLE = {
    "open":     (0.90, "#BFD6EC"),
    "forest":   (0.74, "#B4CBDF"),
    "jungle":   (0.68, "#BED8C4"),
    "swamp":    (0.62, "#A9B79C"),
    "dark":     (0.60, "#9CB2C6"),
    "desert":   (0.60, "#E6D2AE"),
    "mesa":     (0.58, "#E0B892"),
    "snow":     (0.76, "#DCE8F6"),
    "mountain": (0.80, "#BFD0E6"),
    "ocean":    (0.88, "#B6D4EC"),
    "cave":     (0.45, "#6E7580"),
    "mushroom": (0.72, "#C6BFDA"),
    "pale":     (0.66, "#CBD0D6"),
    "nether":   (0.52, "#4E1A12"),
    "soulsand": (0.48, "#33606F"),
    "crimson":  (0.50, "#5A1C24"),
    "warped":   (0.50, "#1F5E5C"),
    "basalt":   (0.55, "#4A464E"),
    "end":      (0.35, "#2E2050"),
}


SPECIAL_FOG_STYLE = {
    "default": "open",
    "dry": "desert",
    "humid": "jungle",
    "semi_humid": "forest",
    "powder_snow": "snow",
    "lush_caves": "cave",
    "sulfur_caves": "cave",
    "deep_dark": "cave",
}


def style_for(biome: str) -> str:
    b = biome
    if b in SPECIAL_FOG_STYLE:
        return SPECIAL_FOG_STYLE[b]
    if b in ("hell", "nether_wastes"):
        return "nether"
    if b == "soulsand_valley":
        return "soulsand"
    if b == "crimson_forest":
        return "crimson"
    if b == "warped_forest":
        return "warped"
    if b == "basalt_deltas":
        return "basalt"
    if b in ("the_end",):
        return "end"
    if "ocean" in b or b in ("river", "frozen_river", "beach", "cold_beach", "stone_beach"):
        return "ocean"
    if b in ("deep_dark", "dripstone_caves", "lush_caves"):
        return "cave"
    if b == "mushroom_island" or b == "mushroom_island_shore":
        return "mushroom"
    if "pale_garden" in b:
        return "pale"
    if b in ("desert", "desert_hills", "desert_mutated"):
        return "desert"
    if b.startswith("mesa"):
        return "mesa"
    if any(k in b for k in ("ice", "snow", "frozen", "grove", "jagged_peaks")):
        return "snow"
    if any(k in b for k in ("extreme_hills", "stony", "meadow")):
        return "mountain"
    if b in ("swampland", "swampland_mutated", "mangrove_swamp"):
        return "swamp"
    if any(k in b for k in ("jungle",)):
        return "jungle"
    if b in ("roofed_forest", "roofed_forest_mutated"):
        return "dark"
    if any(k in b for k in ("forest", "taiga", "grove", "cherry")):
        return "forest"
    return "open"


def build_fogs() -> Report:
    out = SRC_DIR / "fogs"
    clean_dir(out)
    rep = Report()
    n = 0
    for path in sorted(VANILLA_FOGS.glob("*.json")):
        data = load_json(path)
        fog = data["minecraft:fog_settings"]
        ident = fog["description"]["identifier"]
        biome = ident.replace("minecraft:fog_", "")
        style = style_for(biome)
        start, color = FOG_STYLE[style]
        dist = fog.setdefault("distance", {})

        # --- بلوك الهواء: كنحافظو على البنية ديال الفانيلا ونبدلو غير القيم ---
        air = dist.setdefault("air", {})
        air.pop("volumetric", None)
        air["fog_start"] = start
        air["fog_end"] = 1.0
        air["fog_color"] = color
        air["render_distance_type"] = "render"

        # --- الجو (رين/رعد) إلا كانت الفانيلا كتعرفها ---
        if "weather" in dist:
            w = dist["weather"]
            w["fog_start"] = round(max(0.3, start - 0.25), 3)
            w["fog_end"] = 1.0
            w["render_distance_type"] = "render"
            w["fog_color"] = "#7B8794" if style not in ("nether", "crimson", "soulsand",
                                                        "warped", "end") else "#3A3038"

        data["format_version"] = data.get("format_version", "1.16.100")
        write_json(out / path.name, data)
        n += 1

    log(f"✅ fogs: {n} بايوم (ضباب أفق ناعم حسب نوع كل منطقة)")
    rep.ok(f"أنواع الضباب المستعملة: {len(FOG_STYLE)}")
    return rep


# ============================================================================
# 7) client_biome files
# ============================================================================
def variant_for(biome: str, comps: dict) -> str:
    """كنختارو نوع الأجواء/الإضاءة/الألوان من المعطيات ديال الفانيلا"""
    atmo = (comps.get("minecraft:atmosphere_identifier", {}) or {}).get("atmosphere_identifier") or ""
    light = (comps.get("minecraft:lighting_identifier", {}) or {}).get("lighting_identifier") or ""
    grade = (comps.get("minecraft:color_grading_identifier", {}) or {}).get("color_grading_identifier") or ""
    blob = f"{atmo} {light} {grade}"

    if any(k in blob for k in ("hell_atmospherics", "basalt_deltas", "crimson_forest",
                               "warped_forest", "soulsand_valley", "nether_lighting")):
        if "soulsand" in blob:
            return "soulsand"
        if "crimson" in blob:
            return "crimson"
        if "warped" in blob:
            return "warped"
        if "basalt" in blob:
            return "basalt"
        return "nether"
    if "end_" in blob or biome == "the_end":
        return "end"
    if "desert_" in blob:
        return "desert"
    if "mesa_" in blob:
        return "mesa"
    if "swampland" in blob or "mangrove" in blob:
        return "swamp"
    if "roofed_forest" in blob:
        return "dark_forest"
    if "mushroom_island" in blob:
        return "mushroom"
    if "pale_garden" in blob:
        return "pale_garden"
    if "ice_plains_spikes" in blob:
        return "snow_peaks"
    if "cold_" in blob or "coolish" in blob:
        return "cold"
    if "warmish" in blob:
        if "jungle" in biome:
            return "jungle"
        return "warmish"
    if "jungle" in biome:
        return "jungle"
    if "snow" in biome or "frozen" in biome or "ice" in biome:
        return "snow_peaks"
    return "default"


def water_for(biome: str) -> str:
    if "swamp" in biome or "mangrove" in biome:
        return "cinematic:swamp_water"
    if "ocean" in biome:
        if "warm" in biome or "lukewarm" in biome:
            return "cinematic:warm_water"
        return "cinematic:ocean_water"
    if biome in ("river", "frozen_river"):
        return "cinematic:river_water"
    return "cinematic:default_water"


def build_biomes() -> Report:
    out = SRC_DIR / "biomes"
    clean_dir(out)
    rep = Report()
    n = 0
    for biome, info in sorted(VANILLA_BIOMES.items()):
        short = biome.replace("minecraft:", "")
        comps = info["components"]
        variant = variant_for(short, comps)
        if variant not in ATMO_VARIANTS:
            rep.warn(f"نوع ماشي معروف ({variant}) لـ {short} — كنستعملو default")
            variant = "default"

        new = {
            "format_version": "1.21.120",
            "minecraft:client_biome": {
                "description": {"identifier": biome},
                "components": {},
            },
        }
        c = new["minecraft:client_biome"]["components"]

        # الضباب: كنحافظو على المعرّف الرسمي ديال الفانيلا — حنا كنبدلو نفس الملف
        # (fogs/xxx_fog_setting.json) من داخل الباك، فكل بايوم كياخد ضبابنا بلا مشاكل.
        if "minecraft:fog_appearance" in comps:
            c["minecraft:fog_appearance"] = comps["minecraft:fog_appearance"]

        # لون الماء على السطح (كيتستعمل برا VV)
        if "minecraft:water_appearance" in comps:
            c["minecraft:water_appearance"] = comps["minecraft:water_appearance"]

        # أصوات وموسيقى البايوم كيف ما هي (باش ما نفسدوش أجواء الفانيلا)
        for key in ("minecraft:ambient_sounds", "minecraft:biome_music",
                    "minecraft:precipitation", "minecraft:sky_color",
                    "minecraft:grass_appearance", "minecraft:fog_appearance" ):
            if key in comps and key not in c:
                c[key] = comps[key]

        # --- الطبقة السينمائية ---
        c["minecraft:atmosphere_identifier"] = {
            "atmosphere_identifier": f"cinematic:{variant}_atmospherics"}
        c["minecraft:color_grading_identifier"] = {
            "color_grading_identifier": f"cinematic:{variant}_color_grading"}
        c["minecraft:lighting_identifier"] = {
            "lighting_identifier": f"cinematic:{variant}_lighting"}
        c["minecraft:water_identifier"] = {"water_identifier": water_for(short)}

        write_json(out / f"{short}.client_biome.json", new)
        n += 1

    log(f"✅ biomes: {n} ملف client_biome (ربط كامل: ضباب + إضاءة + ألوان + ماء)")
    rep.ok("كل بايوم عندو نسختو — كنستعملو معطيات الفانيلا الرسمية كأساس")
    return rep


# ============================================================================
# 8) pbr/global.json — قيم افتراضية للمواد لي ماعندهاش texture set
# ============================================================================
def build_pbr_fallback() -> None:
    out = SRC_DIR / "pbr"
    clean_dir(out)
    v = [0, 0, 235, 8]   # بلا معدن، بلا إشعاع، خشن شوية، subsurface خفيف
    write_json(out / "global.json", {
        "format_version": "1.21.40",
        "minecraft:pbr_fallback_settings": {
            "blocks": {"global_metalness_emissive_roughness_subsurface": v},
            "actors": {"global_metalness_emissive_roughness_subsurface": v},
            "particles": {"global_metalness_emissive_roughness_subsurface": [0, 0, 40, 60]},
            "items": {"global_metalness_emissive_roughness_subsurface": v},
        },
    })
    log("✅ pbr/global.json: قيم افتراضية للمواد (بلا معدن/إشعاع، خشونة عالية)")


# ============================================================================
def main(lite: bool = False) -> None:
    build_atmospherics()
    build_lighting()
    build_grading(lite=lite)
    build_water(lite=lite)
    build_shadows()
    rep = build_fogs()
    rep2 = build_biomes()
    build_pbr_fallback()
    rep.warnings.extend(rep2.warnings)
    rep.print()


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--lite", action="store_true")
    a = ap.parse_args()
    main(lite=a.lite)
