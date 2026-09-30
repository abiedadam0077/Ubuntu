#!/usr/bin/env bash
# ============================================================================
# build.sh — كيصبّط باك الشادر (LowEnd Vibes) فـ ملف .mcpack واجد للتحميل
# الاستعمال: ./build.sh     (النتيجة: ../dist/LowEnd-Vibes.mcpack)
# ============================================================================
set -euo pipefail

cd "$(dirname "$0")"
PACK_DIR="lowendvibes"
OUT_DIR="dist"
OUT_NAME="LowEnd-Vibes"

command -v zip >/dev/null || { echo "خطأ: خاصك 'zip' (sudo apt install zip)"; exit 1; }
command -v python3 >/dev/null || { echo "خطأ: خاصك python3"; exit 1; }

echo "==> 1/3 كتحقق من صحة ملفات JSON"
python3 - "$PACK_DIR" <<'PY'
import json, sys, pathlib
root = pathlib.Path(sys.argv[1])
files = sorted(root.rglob("*.json"))
for f in files:
    try:
        json.loads(f.read_text(encoding="utf-8"))
    except Exception as e:
        sys.exit(f"JSON مكسور فـ {f}: {e}")
man = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
assert man["format_version"] == 2, "format_version خاصو يكون 2"
assert man["modules"][0]["type"] == "resources", "module type خاصو resources"
pp = root / "pack_icon.png"
assert pp.exists() and pp.stat().st_size > 0, "pack_icon.png ناقص"
print(f"    ✅ {len(files)} ملف JSON صحيحين + pack_icon.png موجود")
PY

echo "==> 2/3 كنمسح النسخة القديمة"
mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/$OUT_NAME.mcpack"

echo "==> 3/3 كنصايب $OUT_NAME.mcpack"
( cd "$PACK_DIR" && zip -r -X -q "../$OUT_DIR/$OUT_NAME.mcpack" . -x '.*' -x '__MACOSX/*' )

ls -lh "$OUT_DIR/$OUT_NAME.mcpack"
echo "✅ واجد: $OUT_DIR/$OUT_NAME.mcpack"
echo "   ديرو فالهاتف: حل الملف ب Minecraft، ولا بدلو لـ .zip وديرو فـ resource_packs/"
