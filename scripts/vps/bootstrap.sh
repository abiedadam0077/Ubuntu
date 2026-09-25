#!/usr/bin/env bash
# ============================================================================
# bootstrap.sh
# كيصايب VPS كامل فوق GitHub Actions runner:
#  - Tailscale (باش تدخل ليه من بعيد، بحال من الهاتف)
#  - LXD/LXC (containers)
#  - Node.js + pm2 (باش يرجع البوتات يخدمو بحالهم)
#  - كيرجع (restore) آخر نسخة محفوظة من الحالة ديال السيرفر (GitHub Release)
# ============================================================================
set -euo pipefail

REPO="${GITHUB_REPOSITORY:-}"
RELEASE_TAG="vps-state"
BACKUP_LOCAL="/tmp/vps-backup.tar.gz"
TS_HOSTNAME="${TAILSCALE_HOSTNAME:-gh-vps}"

log() { echo -e "\n\033[1;36m==> $*\033[0m"; }

log "1/7 تحديث النظام وتنصيب الأدوات الأساسية"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  curl wget git tar gnupg jq ca-certificates openssh-server

log "2/7 تفعيل خدمة SSH العادية (احتياطي، بجانب Tailscale)"
sudo systemctl enable --now ssh || true
sudo mkdir -p /root/.ssh
sudo chmod 700 /root/.ssh
if [ -n "${SSH_PUBLIC_KEY:-}" ]; then
  if ! sudo grep -qF "$SSH_PUBLIC_KEY" /root/.ssh/authorized_keys 2>/dev/null; then
    echo "$SSH_PUBLIC_KEY" | sudo tee -a /root/.ssh/authorized_keys >/dev/null
    sudo chmod 600 /root/.ssh/authorized_keys
    log "تزادت المفتاح ديالك ل authorized_keys"
  fi
fi

log "3/7 محاولة استرجاع آخر نسخة محفوظة من السيرفر (GitHub Release: $RELEASE_TAG)"
if [ -n "$REPO" ] && gh release download "$RELEASE_TAG" -p "backup.tar.gz" -O "$BACKUP_LOCAL" --repo "$REPO" 2>/dev/null; then
  log "لقيت نسخة قديمة، كنرجعها (restore)..."
  sudo tar -xzpf "$BACKUP_LOCAL" -C / || echo "تحذير: مشكل فالاسترجاع، كنكمل بحال أول مرة"
  log "تم الاسترجاع بنجاح ✅"
else
  log "ماكاينش نسخة سابقة، هادي أول مرة كتبداو (فريش VPS)"
fi

log "4/7 تنصيب Node.js + pm2 (باش البوتات يرجعو يخدمو وحدهم)"
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null
  sudo apt-get install -y nodejs
fi
if ! command -v pm2 >/dev/null 2>&1; then
  sudo npm install -g pm2
fi

log "5/7 تنصيب/تشغيل LXD (LXC containers)"
if ! command -v lxc >/dev/null 2>&1; then
  sudo snap install lxd
fi
sudo usermod -aG lxd "$(whoami)" || true
sudo systemctl enable --now snap.lxd.daemon || true
sudo lxd waitready --timeout=60 || true
# lxd init --auto كيعطي error إلا كان مصايب من قبل (بعد الاسترجاع) - عادي، كنتجاهلوه
sudo lxd init --auto 2>/dev/null || true
log "الحاويات (containers) لي عندها boot.autostart=true غادي يبداو وحدهم مع الخدمة"
sudo lxc list || true

log "6/7 الاتصال ب Tailscale"
if [ -z "${TAILSCALE_AUTHKEY:-}" ]; then
  echo "خطأ: خاصك تزيد secret اسمو TAILSCALE_AUTHKEY فالريبو (Settings > Secrets > Actions)" >&2
  exit 1
fi
curl -fsSL https://tailscale.com/install.sh | sudo sh >/dev/null
sudo tailscale up \
  --auth-key="${TAILSCALE_AUTHKEY}" \
  --hostname="${TS_HOSTNAME}" \
  --ssh \
  --accept-dns=true
echo "Tailscale status:"
sudo tailscale status || true
echo "Tailscale IP:"
sudo tailscale ip -4 || true

log "7/7 رجوع البوتات لي كانو خدامين (pm2 resurrect)"
export HOME=/root
if [ -f /root/.pm2/dump.pm2 ]; then
  sudo env HOME=/root pm2 resurrect || true
  sudo env HOME=/root pm2 status || true
else
  echo "ماكاينش لائحة بوتات محفوظة من قبل (طبيعي إلا كانت أول مرة)"
fi

# رجوع services (بحال بوتات مصايبين ك systemd service بحال bot-xxx.service)
sudo systemctl daemon-reload || true
if compgen -G "/etc/systemd/system/bot-*.service" > /dev/null; then
  for f in /etc/systemd/system/bot-*.service; do
    name="$(basename "$f")"
    sudo systemctl enable --now "$name" || true
  done
fi

echo ""
echo "==========================================================="
echo " VPS واجد! (Tailscale hostname: ${TS_HOSTNAME})"
echo " دخل ليه من أي جهاز فنفس ال-tailnet ديالك:"
echo "   tailscale ssh root@${TS_HOSTNAME}"
echo "   ولا: ssh root@\$(tailscale ip -4)"
echo "==========================================================="
