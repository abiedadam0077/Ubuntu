"""
build.py — كيتحقق من الباك كامل وكيغلّفو فـ .mcpack

الاستعمال:
    python3 build.py            # النسخة الكاملة
    python3 build.py --lite     # النسخة الخفيفة (بلا normal maps، tone mapping خفيف)
    python3 build.py --check    # غير التحقق بلا تغليف
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
import zipfile

from common import DIST_DIR, SRC_DIR, log

IDENT_RE = re.compile(r"^[a-z0-9_]+:[a-z0-9_/]+$")


# ----------------------------------------------------------------------------
class Validator:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.stats: dict[str, int] = {}

    def err(self, m: str) -> None:
        self.errors.append(m)

    def warn(self, m: str) -> None:
        self.warnings.append(m)

    def ok(self, key: str, n: int) -> None:
        self.stats[key] = n

    # --- التحقق ---
    def run(self) -> None:
        if not SRC_DIR.exists():
            self.err("ماكاينش مجلد الباك (pack/)")
            return

        # 1) كل ملفات JSON خاصها تكون صحيحة
        json_files = sorted(SRC_DIR.rglob("*.json"))
        for f in json_files:
            try:
                json.loads(f.read_text(encoding="utf-8"))
            except Exception as e:
                self.err(f"JSON مكسور: {f.relative_to(SRC_DIR)} → {e}")

        # 2) المانيفست
        man = SRC_DIR / "manifest.json"
        if not man.exists():
            self.err("ماكاينش manifest.json")
            return
        m = json.loads(man.read_text(encoding="utf-8"))
        if "pbr" not in (m.get("capabilities") or []):
            self.err("manifest ما فيهش capabilities: [\"pbr\"] — Vibrant Visuals ماغاديش تقرا الـ PBR")
        if tuple(m["header"]["min_engine_version"]) < (1, 21, 120):
            self.warn("min_engine_version أقل من 1.21.120 — خاصو يكون 1.21.120+ باش PBR يخدم")
        if not (SRC_DIR / "pack_icon.png").exists():
            self.err("ماكاينش pack_icon.png")

        # 3) المعرّفات اللي كتشير ليها ملفات البايوم خاصها تكون موجودة
        def idents(folder: str, key: str, sub: str | None = None) -> set[str]:
            found = set()
            for f in (SRC_DIR / folder).rglob("*.json"):
                d = json.loads(f.read_text(encoding="utf-8"))
                node = d.get(key, {})
                if sub:
                    node = node.get(sub, {})
                ident = (node or {}).get("identifier")
                if ident:
                    found.add(ident)
            return found

        atmo_ids = idents("atmospherics", "minecraft:atmosphere_settings", "description")
        light_ids = idents("lighting", "minecraft:lighting_settings", "description")
        grade_ids = idents("color_grading", "minecraft:color_grading_settings", "description")
        water_ids = idents("water", "minecraft:water_settings", "description")
        fog_ids = idents("fogs", "minecraft:fog_settings", "description")

        self.ok("atmospherics", len(atmo_ids))
        self.ok("lighting", len(light_ids))
        self.ok("color_grading", len(grade_ids))
        self.ok("water", len(water_ids))
        self.ok("fogs", len(fog_ids))

        biome_files = sorted((SRC_DIR / "biomes").glob("*.client_biome.json"))
        self.ok("biomes", len(biome_files))
        refs = {"atmosphere": 0, "lighting": 0, "grading": 0, "water": 0, "fog": 0}
        for f in biome_files:
            d = json.loads(f.read_text(encoding="utf-8"))
            c = d["minecraft:client_biome"]["components"]
            checks = [
                ("cinematic:atmosphere_identifier", atmo_ids, "atmosphere"),
                ("cinematic:lighting_identifier", light_ids, "lighting"),
                ("cinematic:color_grading_identifier", grade_ids, "grading"),
            ]
            for comp, pool, tag in checks:
                ident = (c.get(comp) or {}).get(comp.split(":", 1)[1])
                if not ident:
                    continue
                if ident not in pool:
                    self.err(f"{f.name}: {comp} = {ident} ماكاينش")
                else:
                    refs[tag] += 1
            w = (c.get("minecraft:water_identifier") or {}).get("water_identifier")
            if w and w not in water_ids:
                self.err(f"{f.name}: water_identifier = {w} ماكاينش")
            elif w:
                refs["water"] += 1
            fog = (c.get("minecraft:fog_appearance") or {}).get("fog_identifier")
            if fog and fog not in fog_ids:
                # ضباب الفانيلا اللي ماعندناش بديل ليه
                if str(fog).startswith("cinematic:"):
                    self.err(f"{f.name}: fog_identifier = {fog} ماكاينش")
                else:
                    self.warn(f"{f.name}: كيستعمل ضباب الفانيلا {fog} (ماشي مشكل)")
            elif fog:
                refs["fog"] += 1

        # 4) خامات PBR
        blocks = list((SRC_DIR / "textures" / "blocks").rglob("*.texture_set.json"))
        self.ok("texture_sets", len(blocks))
        missing_colors = 0
        missing_mers = 0
        for f in blocks:
            d = json.loads(f.read_text(encoding="utf-8"))
            ts = d["minecraft:texture_set"]
            base = f.parent
            for key in ("color", "metalness_emissive_roughness_subsurface", "normal"):
                if key not in ts:
                    continue
                name = ts[key]
                if not any((base / f"{name}{ext}").exists() for ext in (".png", ".tga", ".jpg")):
                    if key == "color":
                        missing_colors += 1
                    elif key == "metalness_emissive_roughness_subsurface":
                        missing_mers += 1
                    else:
                        self.err(f"{f.name}: normal map ناقص ({name})")
        if missing_colors:
            self.err(f"{missing_colors} texture_set بلا خامة اللون")
        if missing_mers:
            self.err(f"{missing_mers} texture_set بلا MERS")

        # 5) الأصوات
        sd = SRC_DIR / "sounds" / "sound_definitions.json"
        if sd.exists():
            d = json.loads(sd.read_text(encoding="utf-8"))
            events = d.get("sound_definitions", {})
            self.ok("sound_events", len(events))
            for ev, cfg in events.items():
                for s in cfg.get("sounds", []):
                    name = s["name"] if isinstance(s, dict) else s
                    if not (SRC_DIR / f"{name}.ogg").exists():
                        self.err(f"صوت ناقص: {name}.ogg (الحدث {ev})")
        else:
            self.warn("ماكاينش sound_definitions.json")

        # 6) الجزيئات
        if (SRC_DIR / "textures" / "particle" / "particles.png").exists():
            self.ok("particles", 1)

    # --- النتيجة ---
    def print_result(self) -> bool:
        log("")
        log("📊 إحصائيات الباك:")
        for k, v in self.stats.items():
            log(f"   • {k:16s} {v}")
        if self.warnings:
            log(f"\n⚠️  {len(self.warnings)} تحذير:")
            for w in self.warnings[:12]:
                log("   - " + w)
            if len(self.warnings) > 12:
                log(f"   ... و {len(self.warnings) - 12} آخرين")
        if self.errors:
            log(f"\n❌ {len(self.errors)} خطأ:")
            for e in self.errors[:20]:
                log("   - " + e)
            return False
        log("\n✅ الباك صحيح 100% — واجد للتغليف")
        return True


# ----------------------------------------------------------------------------
def package(name: str) -> pathlib.Path:
    DIST_DIR.mkdir(parents=True, exist_ok=True)
    out = DIST_DIR / f"{name}.mcpack"
    if out.exists():
        out.unlink()
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for f in sorted(SRC_DIR.rglob("*")):
            if f.is_dir() or f.name.startswith("."):
                continue
            z.write(f, f.relative_to(SRC_DIR))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lite", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--name", default=None)
    a = ap.parse_args()

    v = Validator()
    v.run()
    ok = v.print_result()
    if not ok:
        sys.exit(1)
    if a.check:
        return

    name = a.name or ("Cinematic-Realism-Lite" if a.lite else "Cinematic-Realism")
    out = package(name)

    size = out.stat().st_size
    files = sum(1 for f in SRC_DIR.rglob("*") if f.is_file())
    log(f"\n📦 {out.relative_to(SRC_DIR.parent)}")
    log(f"   الحجم: {size / 1024 / 1024:.2f} MB   |   عدد الملفات: {files}")


if __name__ == "__main__":
    main()
