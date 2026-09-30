"""
gen_pbr.py — كيصايب خامات PBR (MERS + Normal maps) للباك

كيفاش كيخدم:
 1. كيقرا الخامة الأصلية (color) من ملفات ماينكرافت الرسمية (bedrock-samples).
 2. كيقرا MERS ديال الفانيلا (R=معدنية, G=إشعاع, B=خشونة, A=تحت-سطحي)
    — حنا كنعززوها حسب نوع المادة (مثلا المعادن كنخليوهم لامعين).
 3. كيصايب normal map من الضوء/الظل ديال الخامة (Sobel) باش الحجر والخشب
    يبان فيهم البروز والعمق.
 4. كيكتب texture_set.json + الملفات فالباك.

الاستعمال:
    python3 gen_pbr.py [--lite] [--vanilla PATH]
      --lite : بلا normal maps (أخف بزاف على GPU الضعيف)
"""
from __future__ import annotations

import argparse
import pathlib

import numpy as np
from PIL import Image

from common import (DATA_DIR, PACK_ROOT, SRC_DIR, Report, clamp, clean_dir,
                    load_json, log, vanilla_path, write_json)

# ----------------------------------------------------------------------------
# أنواع المواد: كل نوع وشنو بغينا منو (القيم 0-255)
# ----------------------------------------------------------------------------
# metal  = نسبة اللمعان المعدني (R)
# emiss  = الإشعاع/الضوء ديال الخامة (G)
# rough  = الخشونة (B) — قل = انعكاس أكثر
# sub    = التشتت تحت السطحي (A) — كيفاش الضو كيدوز فالوراق والثلج والجلد
# blend  = شحال كنبدلو من قيم الفانيلا (1 = نبدلوها كاملة)
# normal = قوة الـ normal map (0 = بلا)
MATERIALS: dict[str, dict] = {
    "metal": dict(metal=232, emiss=None, rough=62, sub=0, blend=0.75, normal=0.9),
    "metal_dark": dict(metal=210, emiss=None, rough=88, sub=0, blend=0.7, normal=0.9),
    "polished": dict(metal=6, emiss=None, rough=52, sub=0, blend=0.6, normal=0.55),
    "stone": dict(metal=2, emiss=None, rough=152, sub=0, blend=0.55, normal=1.15),
    "stone_soft": dict(metal=0, emiss=None, rough=178, sub=0, blend=0.5, normal=1.0),
    "brick": dict(metal=0, emiss=None, rough=165, sub=0, blend=0.5, normal=1.2),
    "wood": dict(metal=0, emiss=None, rough=210, sub=0, blend=0.6, normal=0.95),
    "foliage": dict(metal=0, emiss=None, rough=255, sub=110, blend=0.65, normal=0.85),
    "soft": dict(metal=0, emiss=None, rough=248, sub=12, blend=0.5, normal=0.7),
    "sand": dict(metal=0, emiss=None, rough=252, sub=0, blend=0.4, normal=0.6),
    "glass": dict(metal=0, emiss=0, rough=22, sub=0, blend=0.85, normal=0.0),
    "ice": dict(metal=0, emiss=None, rough=42, sub=190, blend=0.8, normal=0.5),
    "snow": dict(metal=0, emiss=None, rough=232, sub=210, blend=0.7, normal=0.7),
    "water": dict(metal=0, emiss=0, rough=16, sub=40, blend=0.8, normal=0.35),
    "emissive": dict(metal=0, emiss=235, rough=190, sub=0, blend=0.6, normal=0.5),
    "emissive_soft": dict(metal=0, emiss=170, rough=200, sub=0, blend=0.55, normal=0.5),
    "ore": dict(metal=95, emiss=None, rough=132, sub=0, blend=0.45, normal=1.05),
    "gem": dict(metal=35, emiss=None, rough=38, sub=150, blend=0.7, normal=0.5),
}

# ----------------------------------------------------------------------------
# خريطة الخامات: اسم المادة -> نوعها
# (المسميات هي ديال Bedrock فـ textures/blocks — لي ماكاينش كيتسكت)
# ----------------------------------------------------------------------------
TEXTURES: dict[str, list[str]] = {
    # --- معادن لامعة ---
    "metal": [
        "iron_block", "gold_block", "netherite_block", "copper_block",
        "exposed_copper", "weathered_copper", "oxidized_copper", "cut_copper",
        "chiseled_copper", "copper_grate", "copper_bars", "copper_chain1",
        "copper_chain2", "chain1", "chain2", "iron_bars", "iron_trapdoor",
        "ancient_debris_side", "ancient_debris_top", "raw_iron_block",
        "raw_gold_block", "raw_copper_block", "lodestone_top", "lodestone_side",
        "copper_bulb", "copper_bulb_powered",
    ],
    # --- معادن داكنة / سطوح زجاجية داكنة ---
    "metal_dark": [
        "obsidian", "crying_obsidian", "gilded_blackstone", "polished_blackstone",
        "polished_blackstone_bricks", "chiseled_polished_blackstone",
        "cracked_polished_blackstone_bricks", "sculk",
        "deepslate/reinforced_deepslate_side", "deepslate/reinforced_deepslate_top",
    ],
    # --- حجر مصقول (انعكاس خفيف) ---
    "polished": [
        "stone_andesite_smooth", "stone_diorite_smooth", "stone_granite_smooth",
        "quartz_block_side", "quartz_block_top", "quartz_block_bottom",
        "quartz_block_lines", "quartz_block_lines_top", "quartz_block_chiseled",
        "quartz_block_chiseled_top", "quartz_bricks", "purpur_block",
        "purpur_pillar", "purpur_pillar_top", "end_bricks", "prismarine_bricks",
        "polished_tuff", "polished_sulfur", "polished_cinnabar",
        "chiseled_tuff", "chiseled_tuff_top", "chiseled_sulfur",
        "chiseled_cinnabar", "polished_basalt_side", "polished_basalt_top",
        "deepslate/polished_deepslate", "deepslate/chiseled_deepslate",
        "deepslate/deepslate_bricks", "deepslate/reinforced_deepslate_side",
        "glazed_terracotta_white", "glazed_terracotta_red", "glazed_terracotta_orange",
        "glazed_terracotta_blue", "glazed_terracotta_black", "glazed_terracotta_green",
    ],
    # --- حجر / طوب / تراكوتا: رطب شوية بضلال واضحة ---
    "stone": [
        "stone", "cobblestone", "cobblestone_mossy", "stonebrick",
        "stonebrick_cracked", "stonebrick_mossy", "stonebrick_carved",
        "stone_andesite", "stone_diorite", "stone_granite", "tuff",
        "tuff_bricks", "chiseled_tuff_bricks", "chiseled_tuff_bricks_top",
        "calcite", "dripstone_block", "basalt_side", "basalt_top",
        "netherrack", "nether_brick", "red_nether_brick", "cracked_nether_bricks",
        "chiseled_nether_bricks", "end_stone", "prismarine_rough",
        "prismarine_dark", "hardened_clay", "resin_block", "resin_bricks",
        "chiseled_resin_bricks", "sulfur", "sulfur_bricks", "cinnabar",
        "cinnabar_bricks", "mud_bricks", "packed_mud", "gravel",
        "deepslate/deepslate", "deepslate/cobbled_deepslate",
        "deepslate/cracked_deepslate_bricks", "deepslate/cracked_deepslate_tiles",
        "sandstone_top", "sandstone_bottom", "sandstone_smooth",
        "sandstone_carved", "red_sandstone_top", "red_sandstone_bottom",
        "red_sandstone_smooth", "red_sandstone_carved",
    ],
    # --- خامات المعادن (بريق صغير فوق الحجر) ---
    "ore": [
        "iron_ore", "gold_ore", "diamond_ore", "emerald_ore", "lapis_ore",
        "redstone_ore", "copper_ore", "coal_ore",
        "deepslate/deepslate_iron_ore", "deepslate/deepslate_gold_ore",
        "deepslate/deepslate_diamond_ore", "deepslate/deepslate_emerald_ore",
        "deepslate/deepslate_lapis_ore", "deepslate/deepslate_redstone_ore",
        "deepslate/deepslate_copper_ore", "deepslate/deepslate_coal_ore",
        "quartz_ore", "nether_gold_ore",
    ],
    # --- خشب ---
    "wood": [
        "planks_oak", "planks_spruce", "planks_birch", "planks_jungle",
        "planks_acacia", "planks_big_oak", "mangrove_planks", "cherry_planks",
        "bamboo_planks", "pale_oak_planks", "poplar_planks",
        "huge_fungus/crimson_planks", "huge_fungus/warped_planks",
        "log_oak", "log_oak_top", "log_spruce", "log_spruce_top",
        "log_birch", "log_birch_top", "log_jungle", "log_jungle_top",
        "log_acacia", "log_acacia_top", "log_big_oak", "log_big_oak_top",
        "mangrove_log_side", "mangrove_log_top", "cherry_log_side",
        "cherry_log_top", "pale_oak_log_side", "pale_oak_log_top",
        "huge_fungus/crimson_log_side", "huge_fungus/crimson_log_top",
        "stripped_crimson_stem_side", "stripped_warped_stem_side",
        "bookshelf", "chiseled_bookshelf_side", "chiseled_bookshelf_top",
        "crafting_table_side", "crafting_table_top", "chest_side", "chest_top",
        "barrel_side", "barrel_top", "scaffolding_side", "bamboo_block",
        "bamboo_block_top", "bamboo_mosaic",
    ],
    # --- وراق (الضو كيدوز فيها = subsurface) ---
    "foliage": [
        "leaves_oak", "leaves_spruce", "leaves_birch", "leaves_jungle",
        "leaves_acacia", "leaves_big_oak", "mangrove_leaves", "cherry_leaves",
        "pale_oak_leaves", "azalea_leaves", "azalea_leaves_flowers",
        "vine", "waterlily", "weeping_vines", "weeping_vines_base",
        "twisting_vines_base", "twisting_vines_bottom", "big_dripleaf_side1",
        "big_dripleaf_side2", "big_dripleaf_top", "moss_block", "pale_moss_block",
        "warped_wart_block", "nether_wart_block", "crimson_roots",
        "warped_roots", "azalea_side", "azalea_top",
    ],
    # --- تراب، عشب، طين ---
    "soft": [
        "dirt", "coarse_dirt", "grass_side", "grass_side_snowed",
        "grass_path_top", "grass_path_side", "grass_top", "grass_carried",
        "grass_block_snow", "dirt_podzol_top", "dirt_podzol_side",
        "mycelium_top", "farmland_dry", "farmland_wet", "soul_sand",
        "soul_soil", "mud", "clay", "sculk_vein", "crimson_nylium_top",
        "crimson_nylium_side", "warped_nylium_top", "warped_nylium_side",
        "pale_moss_carpet_side_base", "pale_moss_carpet_side_tip",
        "mangrove_roots_side", "mangrove_roots_top",
    ],
    # --- رمل ---
    "sand": [
        "sand", "red_sand", "suspicious_sand_0", "suspicious_sand_1",
        "suspicious_sand_2", "suspicious_sand_3", "suspicious_gravel_0",
        "suspicious_gravel_1", "suspicious_gravel_2", "suspicious_gravel_3",
    ],
    # --- جلد ---
    "glass": [
        "glass", "glass_pane_top", "tinted_glass", "glass_black", "glass_blue",
        "glass_brown", "glass_cyan", "glass_gray", "glass_green",
        "glass_light_blue", "glass_lime", "glass_magenta", "glass_orange",
        "glass_pink", "glass_purple", "glass_red", "glass_silver",
        "glass_white", "glass_yellow", "glass_pane_top_black",
        "glass_pane_top_white", "glass_pane_top_silver",
    ],
    # --- تلج ---
    "ice": [
        "ice", "ice_packed", "blue_ice", "frosted_ice_0", "frosted_ice_1",
        "frosted_ice_2", "frosted_ice_3",
    ],
    # --- ثلج ---
    "snow": ["snow", "powder_snow"],
    # --- الماء ---
    "water": [
        "water_still", "water_flow", "cauldron_water",
        "cauldron_water_placeholder",
    ],
    # --- حوايج كتشعل ---
    "emissive": [
        "glowstone", "sea_lantern", "shroomlight", "lantern", "soul_lantern",
        "copper_lantern", "exposed_copper_lantern", "weathered_copper_lantern",
        "oxidized_copper_lantern", "redstone_lamp_on", "magma", "lava_still",
        "lava_flow", "ochre_froglight_side", "ochre_froglight_top",
        "verdant_froglight_side", "verdant_froglight_top",
        "pearlescent_froglight_side", "pearlescent_froglight_top", "torch_on",
        "redstone_torch_on", "respawn_anchor_top", "respawn_anchor_side1",
        "end_rod", "sea_pickle", "copper_bulb_lit", "copper_bulb_lit_powered",
    ],
    "emissive_soft": [
        "sculk_sensor_top", "sculk_sensor_side", "sculk_shrieker_side",
        "sculk_catalyst_top_bloom", "sculk_catalyst_side_bloom", "endframe_top",
        "soul_fire_0", "soul_fire_1", "fire_0", "fire_1", "campfire_log_lit",
        "soul_campfire_log_lit", "campfire_log", "candles/candle_lit",
        "candles/white_candle_lit", "candles/red_candle_lit",
    ],
    # --- كريستالات وأحجار كريمة ---
    "gem": [
        "amethyst_block", "amethyst_cluster", "budding_amethyst",
        "small_amethyst_bud", "medium_amethyst_bud", "large_amethyst_bud",
        "diamond_block", "emerald_block", "lapis_block", "redstone_block",
    ],
}


# ----------------------------------------------------------------------------
# أدوات معالجة الصور
# ----------------------------------------------------------------------------
def find_texture(blocks_dir: pathlib.Path, name: str):
    """كيلقى الخامة بأي امتداد (png / tga) وكيرجع المسار"""
    for ext in (".png", ".tga"):
        p = blocks_dir / f"{name}{ext}"
        if p.exists():
            return p
    return None


def load_rgba(path: pathlib.Path) -> Image.Image:
    im = Image.open(path)
    return im.convert("RGBA")


def default_mers(size: tuple[int, int]) -> np.ndarray:
    """MERS افتراضي: بلا معدن، بلا إشعاع، خشن كامل، بلا تشتت"""
    arr = np.zeros((size[1], size[0], 4), dtype=np.uint8)
    arr[..., 2] = 255
    return arr


def blend_channel(base: np.ndarray, target: int | None, amount: float) -> np.ndarray:
    """كنخلطو قناة معينة مع قيمة الهدف"""
    if target is None:
        return base
    return np.clip(base.astype(np.float32) * (1 - amount) + target * amount, 0, 255)


def luminance_normal(im: Image.Image, strength: float) -> Image.Image:
    """
    Normal map من الإضاءة/الظل ديال الخامة:
    1. اللمعان (luminance) + تنعيم خفيف.
    2. Sobel = فين كاين التغيير (الحواف والبروز).
    3. auto-scale: كنقيسو قوة التفاضل وكنكبروها باش البروز يبان دايما
       (كل خامة عندها تباين مختلف — بلا هادشي الحجر الناعم ماكيبانش فيه والو).
    4. تحويل ل surface normal مقيّس.
    """
    rgba = np.asarray(im.convert("RGBA"), dtype=np.float32) / 255.0
    rgb = rgba[..., :3]
    alpha = rgba[..., 3:4]
    lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]

    # تنعيم 3x3 (wrap = بلا خطوط على الحدود حيت الخامات كتعاود)
    k = np.array([[1, 2, 1], [2, 4, 2], [1, 2, 1]], dtype=np.float32) / 16.0
    padded = np.pad(lum, 1, mode="wrap")
    smooth = np.zeros_like(lum)
    for dy in range(3):
        for dx in range(3):
            smooth += k[dy, dx] * padded[dy:dy + lum.shape[0], dx:dx + lum.shape[1]]

    # Sobel
    sx = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], dtype=np.float32) / 8.0
    sy = np.array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]], dtype=np.float32) / 8.0
    p = np.pad(smooth, 1, mode="wrap")
    dx_ = np.zeros_like(smooth)
    dy_ = np.zeros_like(smooth)
    for i in range(3):
        for j in range(3):
            win = p[i:i + smooth.shape[0], j:j + smooth.shape[1]]
            dx_ += sx[i, j] * win
            dy_ += sy[i, j] * win

    # --- auto-scale: كنوصلو للـ 95% ديال التفاضل لقيمة مستهدفة ---
    target = 0.30 * max(strength, 0.05)     # شحال من انحراف بغينا فالـ normal
    mag = np.sqrt(dx_ * dx_ + dy_ * dy_)
    p95 = float(np.percentile(mag, 95)) if mag.size else 0.0
    scale = (target / p95) if p95 > 1e-5 else 1.0
    scale = float(np.clip(scale, 0.0, 60.0))

    nx = -dx_ * scale
    ny = dy_ * scale
    nz = np.ones_like(smooth)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / length, ny / length, nz / length

    out = np.zeros((*smooth.shape, 4), dtype=np.uint8)
    out[..., 0] = np.clip((nx * 0.5 + 0.5) * 255, 0, 255).astype(np.uint8)
    out[..., 1] = np.clip((ny * 0.5 + 0.5) * 255, 0, 255).astype(np.uint8)
    out[..., 2] = np.clip((nz * 0.5 + 0.5) * 255, 0, 255).astype(np.uint8)
    out[..., 3] = 255
    # المناطق الشفافة (وراق/جلد): سطح مسطح
    out[alpha[..., 0] < 0.5] = (128, 128, 255, 255)
    return Image.fromarray(out, "RGBA")


# ----------------------------------------------------------------------------
# السكريبت الرئيسي
# ----------------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lite", action="store_true", help="بلا normal maps (أخف)")
    ap.add_argument("--vanilla", default=None, help="مسار bedrock-samples/resource_pack")
    args = ap.parse_args()

    if args.vanilla:
        import os
        os.environ["MINECRAFT_VANILLA"] = args.vanilla
    vanilla = vanilla_path()
    blocks_dir = vanilla / "textures" / "blocks"

    out_dir = SRC_DIR / "textures" / "blocks"
    clean_dir(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    rep = Report()
    made = 0
    normal_on = not args.lite

    for material, names in TEXTURES.items():
        cfg = MATERIALS[material]
        for name in names:
            color_path = find_texture(blocks_dir, name)
            if color_path is None:
                rep.warn(f"ماكايناش الخامة الأصلية: {name} (تسكتت)")
                continue

            color = load_rgba(color_path)
            size = color.size
            (out_dir / name).parent.mkdir(parents=True, exist_ok=True)

            # --- نسخ الخامة الأصلية (ضروري: texture_set خاصو اللون فنفس الباك) ---
            color.save(out_dir / f"{name}.png")

            # --- MERS ---
            mers_path = find_texture(blocks_dir, f"{name}_mers")
            base = np.asarray(load_rgba(mers_path), dtype=np.float32) if mers_path else \
                default_mers(size).astype(np.float32)
            if base.shape[0] != size[1] or base.shape[1] != size[0]:
                # بعض الخامات المتحركة كيكونو مختلفين — كنعاودو التصغير
                mers_img = load_rgba(mers_path).resize(size, Image.NEAREST)
                base = np.asarray(mers_img, dtype=np.float32)

            b = cfg["blend"]
            base[..., 0] = blend_channel(base[..., 0], cfg["metal"], b)
            base[..., 1] = blend_channel(base[..., 1], cfg["emiss"], b)
            base[..., 2] = blend_channel(base[..., 2], cfg["rough"], b)
            base[..., 3] = blend_channel(base[..., 3], cfg["sub"], b * 0.8)
            mers = np.clip(base, 0, 255).astype(np.uint8)
            Image.fromarray(mers, "RGBA").save(out_dir / f"{name}_mers.png")

            # --- texture_set.json ---
            # ملاحظة: المراجع داخل texture_set كيكونو أسماء الملفات فقط (ماشي مسار)
            base_name = pathlib.PurePosixPath(name).name
            ts = {
                "format_version": "1.21.30",
                "minecraft:texture_set": {
                    "color": base_name,
                    "metalness_emissive_roughness_subsurface": f"{base_name}_mers",
                },
            }

            # --- Normal map ---
            strength = float(cfg["normal"])
            if normal_on and strength > 0:
                luminance_normal(color, strength).save(out_dir / f"{name}_normal.png")
                ts["minecraft:texture_set"]["normal"] = f"{base_name}_normal"

            write_json(out_dir / f"{name}.texture_set.json", ts)
            made += 1

    log(f"✅ gen_pbr: {made} خامة PBR (normal maps: {'آه' if normal_on else 'لا (lite)'})")
    rep.print()


if __name__ == "__main__":
    main()
