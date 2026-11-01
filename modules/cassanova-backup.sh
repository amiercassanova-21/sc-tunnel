#!/usr/bin/env bash
# Full panel backup for migration/recovery. Includes secrets: keep archive private.
set -Eeuo pipefail
umask 077

[[ ${EUID} -eq 0 ]] || { echo 'Jalankan sebagai root.' >&2; exit 1; }
DEST_DIR='/root/Backup penting/Restore Vps induk'
DEST_FILE="$DEST_DIR/Cassanova_bot_untuk_restore_vps_induk.tar.gz"
WORK=$(mktemp -d /var/tmp/cassanova-backup.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

# Only panel-owned configuration and executables are archived. OS identity files
# (/etc/passwd, shadow, machine-id, network config) are intentionally excluded.
PATHS=(
  etc/xray
  usr/local/etc/xray
  etc/sing-box
  etc/bot
  etc/nginx
  etc/letsencrypt
  etc/ssh/sshd_config
  etc/ssh/sshd_config.d
  etc/ssh/.ssh.db
  etc/dropbear
  etc/systemd/system/xray.service
  etc/systemd/system/sing-box.service
  etc/systemd/system/nginx.service.d
  etc/systemd/system/ws-ssh.service
  etc/systemd/system/bot-tele.service
  etc/systemd/system/cassanova-bandwidth.service
  etc/systemd/system/cassanova-bandwidth.timer
  etc/systemd/system/dropbear.service.d
  usr/bin/menu
  usr/bin/m-ssh
  usr/bin/m-vless
  usr/bin/m-vmess
  usr/bin/m-trojan
  usr/bin/m-hysteria2
  usr/bin/m-feature
  usr/bin/m-bot
  usr/bin/xray-manager
  usr/bin/hy2-manager
  usr/bin/cassanova-bandwidth
  usr/bin/auto-exp
  usr/bin/autokill-xray
  usr/bin/update-sc
  usr/bin/install-hysteria2
  usr/local/bin/bot-tele.py
  var/lib/cassanova/bandwidth-xray.json
  root/.config/cassanova
)

mkdir -p "$WORK/rootfs" "$DEST_DIR"
: > "$WORK/included.txt"
for rel in "${PATHS[@]}"; do
  src="/$rel"
  [[ -e "$src" || -L "$src" ]] || continue
  mkdir -p "$WORK/rootfs/$(dirname "$rel")"
  cp -a "$src" "$WORK/rootfs/$rel"
  printf '%s\n' "$rel" >> "$WORK/included.txt"
done

# Save root's scheduled jobs, if any, without exporting unrelated system crontabs.
if crontab -l > "$WORK/rootfs/root/cassanova-root.crontab" 2>/dev/null; then
  printf '%s\n' 'root/cassanova-root.crontab' >> "$WORK/included.txt"
fi

cat > "$WORK/rootfs/RESTORE-INFO.txt" <<INFO
SC Cassanova Tunneling V2 - Full Panel Backup
Created UTC: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
Hostname: $(hostname)
OS: $(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-unknown}")
Archive purpose: panel migration/recovery, not a disk image.
Sensitive: contains bot token, TLS private keys and account credentials if present.
Restore target supported: Ubuntu 22.04+ or Debian 12+.
Excluded intentionally: /etc/passwd, /etc/shadow, /etc/group, /etc/gshadow,
/etc/fstab, network config, machine-id, package database, kernel and OS files.
SSH Linux login users are not recreated by this archive; migrate/recreate them separately.
Xray per-user bandwidth usage counters are included when present.
INFO

# Build archive in destination directory, then atomically replace previous backup.
TMP_ARCHIVE="$DEST_DIR/.Cassanova_restore.$$.tmp"
tar -czpf "$TMP_ARCHIVE" -C "$WORK/rootfs" .
tar -tzf "$TMP_ARCHIVE" >/dev/null
sha256sum "$TMP_ARCHIVE" > "$TMP_ARCHIVE.sha256"
mv -f "$TMP_ARCHIVE" "$DEST_FILE"
mv -f "$TMP_ARCHIVE.sha256" "$DEST_FILE.sha256"
chmod 0600 "$DEST_FILE" "$DEST_FILE.sha256"
echo "Backup selesai: $DEST_FILE"
echo "Ukuran: $(du -h "$DEST_FILE" | awk '{print $1}')"
echo 'PERINGATAN: arsip berisi rahasia. Simpan di tempat aman dan jangan bagikan publik.'
