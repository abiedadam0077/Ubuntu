#!/usr/bin/env bash
# ============================================================================
# make.sh — كيصايب الباك كامل من الصفر: خامات + سماء + VV + أصوات + تغليف
#
# الاستعمال:
#   ./make.sh              # النسخة الكاملة (سينمائي، ACES، normal maps)
#   ./make.sh --lite       # النسخة الخفيفة للأجهزة الضعيفة
#   ./make.sh --no-pbr     # بلا إعادة توليد الخامات (سريع)
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

PY="${PY:-/home/user/.venv/bin/python}"
[ -x "$PY" ] || PY="python3"

LITE=""
SKIP_PBR=""
for a in "$@"; do
  case "$a" in
    --lite) LITE="--lite" ;;
    --no-pbr) SKIP_PBR="1" ;;
  esac
done

echo "🎬 Cinematic Realism — بناء الباك $( [ -n "$LITE" ] && echo '(نسخة خفيفة)' )"
echo

if [ -z "$SKIP_PBR" ]; then
  echo "1/6 خامات PBR (334 خامة: لون + MERS + normal map)"
  "$PY" tools/gen_pbr.py $LITE
else
  echo "1/6 خامات PBR — تسكتت (--no-pbr)"
fi

echo "2/6 الجو (غيوم واقعية، شمس، قمر، مطر)"

"$PY" tools/gen_env.py $LITE

echo "3/6 ملفات Vibrant Visuals (أجواء، إضاءة، ألوان، ماء، ظلال، ضباب، بايومات)"
"$PY" tools/gen_vv.py $LITE

echo "4/6 الأصوات (مطر، رعد، تحت الما، ماء)"
"$PY" tools/gen_sounds.py

echo "5/6 الجزيئات (قطرات، فقاعات، لهب)"
"$PY" tools/gen_particles.py

echo "6/6 المانيفست + التحقق + التغليف"
"$PY" tools/gen_manifest.py $LITE
"$PY" tools/build.py $LITE

echo
echo "✅ سالا! الملف النهائي كاين فـ dist/"
ls -lh dist/
