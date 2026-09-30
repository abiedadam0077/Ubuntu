"""
gen_manifest.py — كيصايب manifest.json ديال الباك

نقطة مهمة: باش Vibrant Visuals تقرا خامات PBR خاص:
   "capabilities": ["pbr"]   و   "min_engine_version": [1, 21, 120] ولا أكثر
(المرجع: learn.microsoft.com/minecraft/creator/documents/vibrantvisuals/vvresourcepacks)
"""
from __future__ import annotations

import argparse
import sys

from common import SRC_DIR, write_json, log

# UUIDs ثابتة (بدّلهم إلا بغيتي تنشر الباك بإسمك)
HEADER_UUID = "8f2c5b41-3d7a-4c9e-a6d1-5b8e7f2093aa"
MODULE_UUID = "1d6b93e5-7a24-4f80-9c33-2e5f8a71d4bb"

NAMES = {
    "full": "Cinematic Realism — PBR + Vibrant Visuals",
    "lite": "Cinematic Realism Lite — خفيف للأجهزة الضعيفة",
}


def build(lite: bool = False) -> None:
    version = [1, 0, 0]
    data = {
        "format_version": 2,
        "header": {
            "name": "pack.name",
            "description": "pack.description",
            "uuid": HEADER_UUID,
            "version": version,
            "min_engine_version": [1, 21, 120],
        },
        "modules": [
            {
                "description": "PBR + Vibrant Visuals + Atmospherics",
                "type": "resources",
                "uuid": MODULE_UUID,
                "version": version,
            }
        ],
        # هادي هي لي كتفعّل PBR فالـ Vibrant Visuals
        "capabilities": ["pbr"],
        "metadata": {
            "authors": ["Arena Agent Mode"],
            "license": "CC-BY-4.0",
            "product_type": "addon",
            "generated_with": {"minecraft": ["1.21.120"]},
        },
    }
    write_json(SRC_DIR / "manifest.json", data)
    log(f"✅ manifest: {NAMES['lite' if lite else 'full']} (capabilities: pbr، min_engine 1.21.120)")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--lite", action="store_true")
    a = ap.parse_args()
    build(lite=a.lite)
