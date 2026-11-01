#!/usr/bin/env bash
# SC Cassanova Tunneling V2 - transactional GitHub updater
set -Eeuo pipefail
umask 077

readonly REPO='https://raw.githubusercontent.com/amiercassanova-21/sc-tunnel/r6-testing'
readonly BACKUP_ROOT='/var/backups/cassanova/update'
readonly LOCK_FILE='/run/lock/cassanova-update.lock'
readonly VERSION_FILE='/usr/local/share/cassanova/VERSION'

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; NC='\033[0m'
log() { printf '%b[%s]%b %s\n' "$BLUE" "$1" "$NC" "$2"; }
die() { printf '%b[ERROR]%b %s\n' "$RED" "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die 'Jalankan sebagai root.'
for cmd in curl install bash python3 tar sha256sum flock systemctl; do
  command -v "$cmd" >/dev/null 2>&1 || die "Dependensi tidak ditemukan: $cmd"
done

install -d -m 0700 "$BACKUP_ROOT" /usr/local/share/cassanova /run/lock
exec 9>"$LOCK_FILE"
flock -n 9 || die 'Proses update lain sedang berjalan. Tunggu hingga selesai.'

# Format: source path|absolute destination|mode
TARGETS=(
  'VERSION|/usr/local/share/cassanova/VERSION|0644'
  'menu.sh|/usr/bin/menu|0755'
  'modules/m-vless.sh|/usr/bin/m-vless|0755'
  'modules/m-vmess.sh|/usr/bin/m-vmess|0755'
  'modules/m-trojan.sh|/usr/bin/m-trojan|0755'
  'modules/xray-manager.sh|/usr/bin/xray-manager|0755'
  'modules/cassanova-notify.py|/usr/local/bin/cassanova-notify.py|0644'
  'modules/cassanova-bandwidth.py|/usr/bin/cassanova-bandwidth|0755'
  'modules/cassanova-expire.sh|/usr/bin/cassanova-expire|0755'
  'modules/cassanova-ssh-expire.sh|/usr/bin/cassanova-ssh-expire|0755'
  'modules/hy2-manager.sh|/usr/bin/hy2-manager|0755'
  'modules/m-hysteria2.sh|/usr/bin/m-hysteria2|0755'
  'install-hysteria2.sh|/usr/bin/install-hysteria2|0755'
  'modules/m-ssh.sh|/usr/bin/m-ssh|0755'
  'modules/m-feature.sh|/usr/bin/m-feature|0755'
  'modules/m-bot.sh|/usr/bin/m-bot|0755'
  'modules/cassanova-backup.sh|/usr/bin/cassanova-backup|0755'
  'modules/cassanova-restore.sh|/usr/bin/cassanova-restore|0755'
  'modules/cassanova-service.sh|/usr/bin/cassanova-service|0755'
  'modules/cassanova-domain.sh|/usr/bin/cassanova-domain|0755'
  'modules/cassanova-cert-renew.sh|/etc/letsencrypt/renewal-hooks/deploy/50-cassanova.sh|0755'
  'modules/cassanova-cert-pre.sh|/etc/letsencrypt/renewal-hooks/pre/50-cassanova-stop-nginx.sh|0755'
  'modules/cassanova-cert-post.sh|/etc/letsencrypt/renewal-hooks/post/50-cassanova-start-nginx.sh|0755'
  'bot-tele.py|/usr/local/bin/bot-tele.py|0644'
  'systemd/cassanova-expire.service|/etc/systemd/system/cassanova-expire.service|0644'
  'systemd/cassanova-expire.timer|/etc/systemd/system/cassanova-expire.timer|0644'
  'systemd/cassanova-bandwidth.service|/etc/systemd/system/cassanova-bandwidth.service|0644'
  'systemd/cassanova-bandwidth.timer|/etc/systemd/system/cassanova-bandwidth.timer|0644'
  'update.sh|/usr/bin/update-sc|0755'
  'setup.sh|/usr/local/share/cassanova/setup.sh|0644'
  'README.md|/usr/local/share/cassanova/README.md|0644'
  'RESTORE-GUIDE.md|/usr/local/share/cassanova/RESTORE-GUIDE.md|0644'
)

STAGE=$(mktemp -d /var/tmp/cassanova-update.XXXXXX)
BACKUP_TAR=''
BOT_WAS_ACTIVE=0
[[ -f /etc/systemd/system/bot-tele.service ]] && systemctl is-active --quiet bot-tele && BOT_WAS_ACTIVE=1 || true
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

log INFO 'Mengambil seluruh file dari branch r6-testing dan memvalidasi sebelum perubahan.'
mkdir -p "$STAGE/download" "$STAGE/rollback"

for item in "${TARGETS[@]}"; do
  IFS='|' read -r src dest mode <<< "$item"
  out="$STAGE/download/$(printf '%s' "$src" | tr '/' '_')"
  curl --fail --silent --show-error --location --retry 3 --retry-delay 1 \
    --connect-timeout 15 --max-time 120 "$REPO/$src" -o "$out" \
    || die "Gagal mengunduh $src. File aktif belum diubah."
  [[ -s "$out" ]] || die "File kosong: $src"
  case "$src" in
    *.sh) bash -n "$out" || die "Sintaks Bash tidak valid: $src" ;;
    *.py) PYTHONPYCACHEPREFIX="$STAGE/pycache" python3 -m py_compile "$out" || die "Sintaks Python tidak valid: $src" ;;
    VERSION)
      grep -Eq '^[0-9A-Za-z][0-9A-Za-z._+-]{0,63}$' "$out" || die 'Format VERSION tidak valid.'
      ;;
  esac
done

# Validate required runtime files are present in this release.
for required in \
  'modules/xray-manager.sh' 'modules/cassanova-notify.py' 'modules/cassanova-bandwidth.py' 'modules/cassanova-expire.sh' 'modules/cassanova-ssh-expire.sh' 'modules/hy2-manager.sh' 'modules/m-feature.sh' \
  'modules/m-bot.sh' 'modules/cassanova-backup.sh' 'modules/cassanova-restore.sh' \
  'modules/cassanova-service.sh' 'modules/cassanova-domain.sh' 'modules/cassanova-cert-renew.sh' 'modules/cassanova-cert-pre.sh' 'modules/cassanova-cert-post.sh' \
  'bot-tele.py' 'systemd/cassanova-expire.service' 'systemd/cassanova-expire.timer' 'systemd/cassanova-bandwidth.service' 'systemd/cassanova-bandwidth.timer' 'setup.sh'; do
  found=0
  for item in "${TARGETS[@]}"; do IFS='|' read -r src _ _ <<< "$item"; [[ "$src" == "$required" ]] && found=1; done
  (( found == 1 )) || die "Manifest tidak lengkap: $required"
done

NEW_VERSION=$(<"$STAGE/download/VERSION")
OLD_VERSION='belum tercatat'
[[ -s "$VERSION_FILE" ]] && OLD_VERSION=$(<"$VERSION_FILE")
log INFO "Versi terpasang: $OLD_VERSION | Versi GitHub: $NEW_VERSION"

# Snapshot every target that will be replaced. Keep the archive after the update.
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP_TAR="$BACKUP_ROOT/pre-update-$STAMP.tar.gz"
EXISTING=()
for item in "${TARGETS[@]}"; do
  IFS='|' read -r _ dest _ <<< "$item"
  [[ -e "$dest" || -L "$dest" ]] && EXISTING+=("${dest#/}")
done
if ((${#EXISTING[@]})); then
  tar -czpf "$BACKUP_TAR" -C / "${EXISTING[@]}" || die 'Gagal membuat backup sebelum update.'
else
  tar -czpf "$BACKUP_TAR" --files-from /dev/null
fi
sha256sum "$BACKUP_TAR" > "$BACKUP_TAR.sha256"
chmod 0600 "$BACKUP_TAR" "$BACKUP_TAR.sha256"

# Preserve exact old files in staging for in-process rollback (including missing targets).
for index in "${!TARGETS[@]}"; do
  IFS='|' read -r _ dest _ <<< "${TARGETS[$index]}"
  if [[ -e "$dest" || -L "$dest" ]]; then
    mkdir -p "$STAGE/rollback/$index"
    cp -a "$dest" "$STAGE/rollback/$index/old"
    : > "$STAGE/rollback/$index/existed"
  fi
done

rollback() {
  local index item dest
  log WARN 'Update gagal. Mengembalikan file versi sebelumnya.'
  for index in "${!TARGETS[@]}"; do
    IFS='|' read -r _ dest _ <<< "${TARGETS[$index]}"
    if [[ -f "$STAGE/rollback/$index/existed" ]]; then
      install -d "$(dirname "$dest")"
      rm -rf -- "$dest"
      cp -a "$STAGE/rollback/$index/old" "$dest"
    else
      rm -f -- "$dest"
    fi
  done
  systemctl daemon-reload || true
  if (( BOT_WAS_ACTIVE )); then systemctl restart bot-tele || true; fi
  log WARN "Rollback selesai. Backup pra-update: $BACKUP_TAR"
}

log INFO 'Menerapkan file secara atomik.'
for index in "${!TARGETS[@]}"; do
  IFS='|' read -r src dest mode <<< "${TARGETS[$index]}"
  staged="$STAGE/download/$(printf '%s' "$src" | tr '/' '_')"
  install -d "$(dirname "$dest")"
  tmp="$(dirname "$dest")/.cassanova-update.$$.${index}"
  if ! install -m "$mode" "$staged" "$tmp" || ! mv -fT "$tmp" "$dest"; then
    rm -f "$tmp"
    rollback
    die "Gagal memasang $dest. Perubahan dibatalkan."
  fi
done

# Validate live engine/web configuration after replacing runtime scripts, before restarting anything.
if command -v xray >/dev/null 2>&1 && [[ -s /usr/local/etc/xray/config.json ]]; then
  if ! xray run -test -config /usr/local/etc/xray/config.json >/dev/null; then rollback; die 'Validasi konfigurasi Xray gagal; file versi lama dipulihkan.'; fi
fi
if command -v sing-box >/dev/null 2>&1 && [[ -s /etc/sing-box/config.json ]]; then
  if ! sing-box check -c /etc/sing-box/config.json >/dev/null; then rollback; die 'Validasi konfigurasi sing-box gagal; file versi lama dipulihkan.'; fi
fi
if command -v nginx >/dev/null 2>&1; then
  if ! nginx -t >/dev/null; then rollback; die 'Validasi konfigurasi Nginx gagal; file versi lama dipulihkan.'; fi
fi

# Reload systemd metadata; enable expiry timer only if Xray API is already listening locally.
systemctl daemon-reload
if [[ -s /usr/local/etc/xray/config.json ]] && jq -e '((.api.services // []) | index("StatsService") != null) and (.policy.levels["0"].statsUserUplink == true) and (.policy.levels["0"].statsUserDownlink == true) and any(.inbounds[]?; .tag == "api-in" and .protocol == "dokodemo-door" and .port == 10085) and any(.routing.rules[]?; ((.inboundTag // []) | index("api-in") != null) and .outboundTag == "api")' /usr/local/etc/xray/config.json >/dev/null 2>&1 && ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Fq '127.0.0.1:10085'; then systemctl enable --now cassanova-bandwidth.timer >/dev/null 2>&1 || log WARN 'Timer bandwidth belum aktif; periksa systemctl status cassanova-bandwidth.timer.'; fi
if ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Fq '127.0.0.1:10085'; then systemctl enable --now cassanova-expire.timer >/dev/null 2>&1 || true; fi

# Restart the bot only if it was active before updating; do not unexpectedly enable/start it.
if (( BOT_WAS_ACTIVE )); then
  if ! systemctl restart bot-tele || ! systemctl is-active --quiet bot-tele; then
    rollback
    die 'Bot gagal hidup setelah update; file lama telah dipulihkan.'
  fi
fi

log OK "Update berhasil: $OLD_VERSION -> $NEW_VERSION"
log INFO "Backup sebelum update: $BACKUP_TAR"
log INFO 'Database akun, token bot, sertifikat, dan konfigurasi layanan tidak disentuh.'
if [[ -t 0 && -t 1 ]] && command -v menu >/dev/null 2>&1; then
  exec /usr/bin/menu
fi
