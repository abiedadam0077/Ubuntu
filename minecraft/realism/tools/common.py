"""
common.py — أدوات مشتركة بين كل سكربتات التوليد
Cinematic Realism — Minecraft Bedrock PBR resource pack
"""
from __future__ import annotations

import json
import os
import pathlib
import shutil
import sys
import zlib

# ----------------------------------------------------------------------------
# المسارات
# ----------------------------------------------------------------------------
TOOLS_DIR = pathlib.Path(__file__).resolve().parent
PACK_ROOT = TOOLS_DIR.parent                      # minecraft/realism
SRC_DIR = PACK_ROOT / "pack"                      # الباك (المصدر)
DATA_DIR = PACK_ROOT / "data"                     # بيانات محفوظة (vanilla snapshot)
DIST_DIR = PACK_ROOT / "dist"                     # ملفات .mcpack النهائية

# مسار الملفات الأصلية ديال Mojang (bedrock-samples/resource_pack)
DEFAULT_VANILLA = "/tmp/bedrock-samples/resource_pack"


def vanilla_path() -> pathlib.Path:
    p = os.environ.get("MINECRAFT_VANILLA") or DEFAULT_VANILLA
    p = pathlib.Path(p)
    if not (p / "textures" / "blocks").is_dir():
        sys.exit(
            f"❌ ماكاينش الملفات الأصلية ديال ماينكرافت فـ: {p}\n"
            "   حمّل bedrock-samples من Mojang ولا دير MINECRAFT_VANILLA=/path"
        )
    return p


# ----------------------------------------------------------------------------
# JSON
# ----------------------------------------------------------------------------
def write_json(path: pathlib.Path, data, indent: int = 2) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=indent, ensure_ascii=False)
        f.write("\n")


def load_json(path: pathlib.Path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def clean_dir(path: pathlib.Path) -> None:
    """كتحيد مجلد كامل (بلا ما تحيد الباك نفسه غلط)"""
    if path.exists():
        shutil.rmtree(path)


def hex_to_rgb(s: str):
    s = s.lstrip("#")
    return [int(s[i:i + 2], 16) for i in (0, 2, 4)]


def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(round(v))))


def log(msg: str) -> None:
    print(msg, flush=True)


class Report:
    """كنجمعو فيه التحذيرات باش نطبعهوم فالآخر"""

    def __init__(self) -> None:
        self.warnings: list[str] = []
        self.info: list[str] = []

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)

    def ok(self, msg: str) -> None:
        self.info.append(msg)

    def print(self) -> None:
        for m in self.info:
            log("   " + m)
        for m in self.warnings:
            log("   ⚠️  " + m)
        if self.warnings:
            log(f"   ({len(self.warnings)} تحذير — الباك كيتصبط بحال ما هو)")
