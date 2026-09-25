#!/usr/bin/env bash
# ============================================================================
# backup.sh
# كياخد "صورة" (snapshot) من الحالة ديال السيرفر (بوتات، سكربتات، containers...)
# وكيرفعها ك asset فوق GitHub Release (vps-state) باش تولي متاحة للتشغيلة الجاية.
# ============================================================================
set -euo pipefail

REPO="${GITHUB_REPOSITORY:-}"
RELEASE_TAG="vps-state"
BACKUP_LOCAL="/tmp/vps-backup.tar.gz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATHS_FILE="${SCRIPT_DIR}/persist-paths.txt"

log() { echo -e "\n\033[1;35m==> $*\033[0m"; }

log "كنحفظ لائحة البوتات الخدامين دابا (pm2 save)"
export HOME=/root
sudo env HOME=/root pm2 save >/dev/null 2>&1 || true

log "كنبني الأرشيف (tar) لكل المسارات المحفوظة"
mapfile -t RAW_PATHS < <(grep -vE '^\s*#|^\s*$' "$PATHS_FILE")
EXISTING=()
for p in "${RAW_PATHS[@]}"; do
  if [ -e "$p" ]; then
    EXISTING+=("${p#/}")
  fi
done

if [ "${#EXISTING[@]}" -eq 0 ]; then
  echo "ماكاين حتى مسار كاين، تسالتاو"
  exit 0
fi

sudo tar -czpf "$BACKUP_LOCAL" \
  --exclude='var/snap/lxd/common/lxd/images/*' \
  --exclude='root/.cache' \
  --exclude='root/.npm' \
  --exclude='home/*/.cache' \
  -C / "${EXISTING[@]}" 2>/dev/null || \
sudo tar -czpf "$BACKUP_LOCAL" -C / "${EXISTING[@]}"

SIZE="$(du -h "$BACKUP_LOCAL" | cut -f1)"
log "حجم النسخة الاحتياطية: $SIZE"

if [ -z "$REPO" ]; then
  echo "GITHUB_REPOSITORY مش معروف، ماقدرتش نرفع الباك أب"
  exit 0
fi

log "كنرفع النسخة الاحتياطية ل GitHub Release ($RELEASE_TAG)"
if ! gh release view "$RELEASE_TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release create "$RELEASE_TAG" --repo "$REPO" \
    --title "VPS persistent state (auto)" \
    --notes "هادي نسخة احتياطية أوتوماتيكية للـ VPS ديال GitHub Actions. ماتمسحهاش يدويا." \
    "$BACKUP_LOCAL#backup.tar.gz"
else
  gh release upload "$RELEASE_TAG" "$BACKUP_LOCAL#backup.tar.gz" --repo "$REPO" --clobber
fi

log "تم الحفظ بنجاح في $(date -u +%FT%TZ) ✅"
