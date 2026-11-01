#!/usr/bin/env bash
# Controlled restore: validate archive, stage first, preserve a pre-restore snapshot.
set -Eeuo pipefail
umask 077

[[ ${EUID} -eq 0 ]] || { echo 'Jalankan sebagai root.' >&2; exit 1; }
ARCHIVE="${1:-}"
if [[ -z "$ARCHIVE" ]]; then
  ARCHIVE='/root/Backup penting/Restore Vps induk/Cassanova_bot_untuk_restore_vps_induk.tar.gz'
fi
[[ -f "$ARCHIVE" && -s "$ARCHIVE" ]] || { echo "File backup tidak ditemukan: $ARCHIVE" >&2; exit 1; }
command -v sha256sum >/dev/null; command -v tar >/dev/null; command -v systemctl >/dev/null

# Enforce supported OS before touching files.
. /etc/os-release
major=${VERSION_ID%%.*}
case "${ID,,}" in
  ubuntu) [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 22 )) || { echo 'Restore membutuhkan Ubuntu 22.04+.' >&2; exit 1; }
          if (( major == 22 )); then minor=${VERSION_ID#*.}; minor=${minor%%.*}; (( ${minor:-0} >= 4 )) || { echo 'Restore membutuhkan Ubuntu 22.04+.' >&2; exit 1; }; fi ;;
  debian) [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 12 )) || { echo 'Restore membutuhkan Debian 12+.' >&2; exit 1; } ;;
  *) echo "OS tidak didukung: ${PRETTY_NAME:-$ID}" >&2; exit 1 ;;
esac

# Verify adjacent checksum when provided. A missing checksum is rejected by default.
if [[ -f "$ARCHIVE.sha256" ]]; then
  (cd "$(dirname "$ARCHIVE")" && sha256sum -c "$(basename "$ARCHIVE").sha256")
else
  echo 'Checksum .sha256 tidak ditemukan; restore dibatalkan.' >&2; exit 1
fi

STAGE=$(mktemp -d /var/tmp/cassanova-restore.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT

# Reject absolute paths, traversal, and anything outside known panel paths.
while IFS= read -r item; do
  item=${item#./}
  [[ -z "$item" || "$item" == '.' ]] && continue
  [[ "$item" != /* && "/$item/" != *'/../'* ]] || { echo "Path berbahaya dalam arsip: $item" >&2; exit 1; }
  case "$item" in
    etc|etc/ssh|etc/systemd|etc/systemd/system|usr|usr/local|usr/local/etc|usr/local/bin|usr/bin|var|var/lib|var/lib/cassanova|root|root/.config|etc/xray|etc/xray/*|usr/local/etc/xray|usr/local/etc/xray/*|etc/sing-box|etc/sing-box/*|etc/bot|etc/bot/*|etc/nginx|etc/nginx/*|etc/letsencrypt|etc/letsencrypt/*|etc/ssh/sshd_config|etc/ssh/sshd_config.d|etc/ssh/sshd_config.d/*|etc/ssh/.ssh.db|etc/dropbear|etc/dropbear/*|etc/systemd/system/xray.service|etc/systemd/system/sing-box.service|etc/systemd/system/nginx.service.d|etc/systemd/system/nginx.service.d/*|etc/systemd/system/ws-ssh.service|etc/systemd/system/bot-tele.service|etc/systemd/system/cassanova-bandwidth.service|etc/systemd/system/cassanova-bandwidth.timer|etc/systemd/system/dropbear.service.d|etc/systemd/system/dropbear.service.d/*|usr/bin/menu|usr/bin/m-ssh|usr/bin/m-vless|usr/bin/m-vmess|usr/bin/m-trojan|usr/bin/m-hysteria2|usr/bin/m-feature|usr/bin/m-bot|usr/bin/xray-manager|usr/bin/hy2-manager|usr/bin/cassanova-bandwidth|usr/bin/auto-exp|usr/bin/autokill-xray|usr/bin/update-sc|usr/bin/install-hysteria2|usr/local/bin/bot-tele.py|var/lib/cassanova/bandwidth-xray.json|root/RESTORE-INFO.txt|root/cassanova-root.crontab|root/.config/cassanova|root/.config/cassanova/*) ;;
    *) echo "Path tidak diizinkan dalam arsip: $item" >&2; exit 1 ;;
  esac
done < <(tar -tzf "$ARCHIVE")

mkdir -p "$STAGE/rootfs"
tar -xzpf "$ARCHIVE" -C "$STAGE/rootfs" --no-same-owner
[[ -s "$STAGE/rootfs/RESTORE-INFO.txt" ]] || { echo 'Metadata backup tidak ditemukan.' >&2; exit 1; }

cat <<'WARN'
PERHATIAN RESTORE:
- File konfigurasi panel, database akun, sertifikat TLS, dan bot akan dipulihkan.
- Konfigurasi Nginx/SSH dari server sumber dapat memerlukan penyesuaian pada VPS tujuan.
- File /etc/passwd dan /etc/shadow tidak dipulihkan; akun login Linux perlu dibuat ulang.
- Proses ini akan mengganti file panel yang memiliki path sama.
WARN
read -rp 'Ketik RESTORE untuk melanjutkan: ' CONFIRM
[[ "$CONFIRM" == 'RESTORE' ]] || { echo 'Dibatalkan.'; exit 0; }

# Create a safety snapshot of the target before changing anything.
PRE='/var/backups/cassanova/pre-restore'
mkdir -p "$PRE"
STAMP=$(date +%Y%m%d-%H%M%S)
PRE_TAR="$PRE/target-before-restore-$STAMP.tar.gz"
TARGET_PATHS=()
for p in etc/xray usr/local/etc/xray etc/sing-box var/lib/cassanova/bandwidth-xray.json etc/bot etc/nginx etc/letsencrypt etc/ssh/sshd_config etc/ssh/sshd_config.d etc/ssh/.ssh.db etc/dropbear etc/systemd/system/xray.service etc/systemd/system/sing-box.service etc/systemd/system/nginx.service.d etc/systemd/system/ws-ssh.service etc/systemd/system/bot-tele.service etc/systemd/system/cassanova-bandwidth.service etc/systemd/system/cassanova-bandwidth.timer etc/systemd/system/dropbear.service.d usr/bin/menu usr/bin/m-ssh usr/bin/m-vless usr/bin/m-vmess usr/bin/m-trojan usr/bin/m-hysteria2 usr/bin/m-feature usr/bin/m-bot usr/bin/xray-manager usr/bin/hy2-manager usr/bin/cassanova-bandwidth usr/bin/auto-exp usr/bin/autokill-xray usr/bin/update-sc usr/bin/install-hysteria2 usr/local/bin/bot-tele.py; do
  [[ -e "/$p" || -L "/$p" ]] && TARGET_PATHS+=("$p")
done
if ((${#TARGET_PATHS[@]})); then tar -czpf "$PRE_TAR" -C / "${TARGET_PATHS[@]}"; chmod 0600 "$PRE_TAR"; fi

# Copy only allowlisted top-level roots/files, preserving modes and symlinks.
while IFS= read -r -d '' src; do
  rel=${src#"$STAGE/rootfs/"}
  case "$rel" in
    root/RESTORE-INFO.txt|root/cassanova-root.crontab) continue ;;
  esac
  if [[ -d "$src" && ! -L "$src" ]]; then
    mkdir -p "/$rel"
    cp -a "$src/." "/$rel/"
  else
    mkdir -p "/$(dirname "$rel")"
    cp -a "$src" "/$rel"
  fi
done < <(find "$STAGE/rootfs" -mindepth 1 \( -path "$STAGE/rootfs/root/RESTORE-INFO.txt" -o -path "$STAGE/rootfs/root/cassanova-root.crontab" \) -prune -o -print0)

if [[ -f "$STAGE/rootfs/root/cassanova-root.crontab" ]]; then
  crontab "$STAGE/rootfs/root/cassanova-root.crontab"
fi

systemctl daemon-reload
# Validate configs where the binaries exist before attempting restarts.
if command -v xray >/dev/null 2>&1 && [[ -f /usr/local/etc/xray/config.json ]]; then
  xray run -test -config /usr/local/etc/xray/config.json
fi
if command -v sing-box >/dev/null 2>&1 && [[ -f /etc/sing-box/config.json ]]; then
  sing-box check -c /etc/sing-box/config.json
fi

FAILED=0
for service in xray sing-box nginx ws-ssh dropbear bot-tele; do
  if systemctl list-unit-files "${service}.service" --no-legend 2>/dev/null | grep -q "${service}.service"; then
    systemctl restart "$service" || FAILED=1
  fi
done
if (( FAILED )); then
  echo 'PERINGATAN: minimal satu service gagal restart. Periksa systemctl status dan journalctl.' >&2
  echo "Snapshot sebelum restore: $PRE_TAR" >&2
  exit 1
fi

if [[ -s /usr/local/etc/xray/config.json ]] && jq -e '((.api.services // []) | index("StatsService") != null) and (.policy.levels["0"].statsUserUplink == true) and (.policy.levels["0"].statsUserDownlink == true) and any(.inbounds[]?; .tag == "api-in" and .protocol == "dokodemo-door" and .port == 10085) and any(.routing.rules[]?; ((.inboundTag // []) | index("api-in") != null) and .outboundTag == "api")' /usr/local/etc/xray/config.json >/dev/null 2>&1 && ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Fq '127.0.0.1:10085'; then systemctl enable --now cassanova-bandwidth.timer >/dev/null 2>&1 || true; fi
echo 'Restore panel selesai.'
echo "Snapshot target sebelum restore: ${PRE_TAR:-tidak ada}"
echo 'Langkah manual: pastikan domain/IP, firewall TCP/UDP, akun Linux SSH, dan konfigurasi jaringan VPS tujuan.'
