#!/usr/bin/env bash
# Install Hysteria2 support on an existing SC Cassanova installation.
set -Eeuo pipefail
umask 077

[[ $EUID -eq 0 ]] || { echo 'Jalankan sebagai root.' >&2; exit 1; }
[[ -r /etc/os-release ]] || { echo 'OS tidak dikenali.' >&2; exit 1; }
. /etc/os-release
major=${VERSION_ID%%.*}
case "${ID,,}" in
  ubuntu) [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 22 )) || { echo 'Diperlukan Ubuntu 22.04+.' >&2; exit 1; }
          if (( major == 22 )); then minor=${VERSION_ID#*.}; minor=${minor%%.*}; (( ${minor:-0} >= 4 )) || { echo 'Diperlukan Ubuntu 22.04+.' >&2; exit 1; }; fi ;;
  debian) [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 12 )) || { echo 'Diperlukan Debian 12+.' >&2; exit 1; } ;;
  *) echo "OS tidak didukung: ${PRETTY_NAME:-$ID}." >&2; exit 1 ;;
esac
command -v systemctl >/dev/null 2>&1 || { echo 'systemd tidak tersedia.' >&2; exit 1; }
command -v apt-get >/dev/null 2>&1 || { echo 'apt-get tidak tersedia.' >&2; exit 1; }

BASE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO='https://raw.githubusercontent.com/amiercassanova-21/sc-tunnel/r6-testing'
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

# A recoverable snapshot is created before package installation or DB migration.
PRE_BACKUP_DIR="/var/backups/cassanova/pre-hy2-install-$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 0700 "$PRE_BACKUP_DIR"
PRE_PATHS=()
for path in etc/sing-box var/lib/cassanova/hysteria2 etc/systemd/system/sing-box.service \
            etc/systemd/system/cassanova-expire.service etc/systemd/system/cassanova-expire.timer \
            usr/bin/menu usr/bin/hy2-manager usr/bin/m-hysteria2 usr/bin/cassanova-expire \
            usr/bin/cassanova-ssh-expire usr/bin/cassanova-domain usr/bin/update-sc \
            usr/local/bin/bot-tele.py etc/letsencrypt/renewal-hooks \
            etc/apt/keyrings/sagernet.asc etc/apt/sources.list.d/sagernet.sources; do
  [[ -e "/$path" || -L "/$path" ]] && PRE_PATHS+=("$path")
done
if ((${#PRE_PATHS[@]})); then
  tar -czpf "$PRE_BACKUP_DIR/pre-hy2-install.tar.gz" -C / "${PRE_PATHS[@]}" || {
    echo 'Gagal membuat snapshot pra-instalasi Hysteria2. Tidak ada perubahan dilakukan.' >&2; exit 1;
  }
  chmod 0600 "$PRE_BACKUP_DIR/pre-hy2-install.tar.gz"
fi
if crontab -l > "$PRE_BACKUP_DIR/root.crontab" 2>/dev/null; then chmod 0600 "$PRE_BACKUP_DIR/root.crontab"; else rm -f "$PRE_BACKUP_DIR/root.crontab"; fi

echo "Snapshot pra-instalasi Hysteria2: $PRE_BACKUP_DIR"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl jq openssl
install -d -m 0755 /etc/apt/keyrings
curl -fsSL --retry 3 https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
chmod 0644 /etc/apt/keyrings/sagernet.asc
cat > /etc/apt/sources.list.d/sagernet.sources <<'REPO'
Types: deb
URIs: https://deb.sagernet.org/
Suites: *
Components: *
Enabled: yes
Signed-By: /etc/apt/keyrings/sagernet.asc
REPO
apt-get update
apt-get install -y sing-box

getent group sing-box >/dev/null 2>&1 || groupadd --system sing-box
getent passwd sing-box >/dev/null 2>&1 || useradd --system --gid sing-box --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin sing-box
install -d -o root -g sing-box -m 0750 /etc/sing-box
install -d -o root -g root -m 0700 /var/lib/cassanova/hysteria2 /var/backups/cassanova/hysteria2
LEGACY_HY2_DB=/etc/sing-box/users.json
HY2_DB=/var/lib/cassanova/hysteria2/users.json
validate_hy2_db() {
  jq -e 'type == "array" and all(.[]; type == "object" and (.username|type=="string" and test("^[A-Za-z0-9_.-]{1,32}$")) and (.password|type=="string" and test("^[A-Za-z0-9._~-]{12,128}$")) and (.expiry|type=="string") and (.expiry as $d | ($d|test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")) and (try (($d|strptime("%Y-%m-%d")|mktime|strftime("%Y-%m-%d")) == $d) catch false)) and (.status=="active" or .status=="locked" or .status=="expired")) and (. as $rows | ([ $rows[].username ] | unique | length) == ($rows|length))' "$1" >/dev/null 2>&1
}
if [[ -e "$HY2_DB" ]] && ! validate_hy2_db "$HY2_DB"; then
  echo 'Database Hysteria2 baru tidak valid; tidak akan ditimpa.' >&2; exit 1
fi
if [[ -e "$LEGACY_HY2_DB" ]]; then
  stamp=$(date +%Y%m%d-%H%M%S)
  if [[ ! -e "$HY2_DB" ]]; then
    if validate_hy2_db "$LEGACY_HY2_DB"; then
      install -o root -g root -m 0600 "$LEGACY_HY2_DB" "$HY2_DB"
      validate_hy2_db "$HY2_DB" || { rm -f "$HY2_DB"; echo 'DB hasil migrasi gagal divalidasi; legacy tetap dipertahankan.' >&2; exit 1; }
    else
      mv -- "$LEGACY_HY2_DB" "/var/backups/cassanova/hysteria2/legacy-users-${stamp}.invalid.json.bak"
      echo 'Peringatan: database legacy tidak sesuai schema dan disimpan utuh sebagai backup invalid.' >&2
    fi
  fi
  [[ ! -e "$LEGACY_HY2_DB" ]] || mv -- "$LEGACY_HY2_DB" "/var/backups/cassanova/hysteria2/legacy-users-${stamp}.json.bak"
fi
if [[ ! -e "$HY2_DB" ]]; then printf '[]\n' > "$HY2_DB"; chmod 0600 "$HY2_DB"; fi
validate_hy2_db "$HY2_DB" || { echo 'Database Hysteria2 baru tidak valid.' >&2; exit 1; }
chown root:root "$HY2_DB"; chmod 0600 "$HY2_DB"
if [[ ! -s /etc/sing-box/config.json ]]; then
  cat > /etc/sing-box/config.json <<'JSON'
{"log":{"level":"warn"},"inbounds":[],"outbounds":[{"type":"direct","tag":"direct"}]}
JSON
fi
chown root:sing-box /etc/sing-box/config.json; chmod 0640 /etc/sing-box/config.json

install_file() {
  local rel="$1" dest="$2" src="$BASE_DIR/$rel"
  if [[ -s "$src" ]]; then cp "$src" "$STAGE/$(basename "$dest")"
  else curl -fsSL --retry 3 "$REPO/$rel" -o "$STAGE/$(basename "$dest")"; fi
  [[ -s "$STAGE/$(basename "$dest")" ]] || { echo "File kosong: $rel" >&2; exit 1; }
  [[ "$rel" != *.sh ]] || bash -n "$STAGE/$(basename "$dest")"
  local mode=0755
  case "$dest" in
    /etc/systemd/system/*.service|/etc/systemd/system/*.timer) mode=0644 ;;
    /etc/letsencrypt/renewal-hooks/*/*) mode=0755 ;;
  esac
  install -D -m "$mode" "$STAGE/$(basename "$dest")" "$dest"
}
install_file modules/hy2-manager.sh /usr/bin/hy2-manager
install_file modules/m-hysteria2.sh /usr/bin/m-hysteria2
install_file modules/cassanova-expire.sh /usr/bin/cassanova-expire
install_file modules/cassanova-ssh-expire.sh /usr/bin/cassanova-ssh-expire
install_file modules/cassanova-domain.sh /usr/bin/cassanova-domain
install_file modules/cassanova-cert-renew.sh /etc/letsencrypt/renewal-hooks/deploy/50-cassanova.sh
install_file modules/cassanova-cert-pre.sh /etc/letsencrypt/renewal-hooks/pre/50-cassanova-stop-nginx.sh
install_file modules/cassanova-cert-post.sh /etc/letsencrypt/renewal-hooks/post/50-cassanova-start-nginx.sh
install_file systemd/cassanova-expire.service /etc/systemd/system/cassanova-expire.service
install_file systemd/cassanova-expire.timer /etc/systemd/system/cassanova-expire.timer
install_file menu.sh /usr/bin/menu
install_file update.sh /usr/bin/update-sc
install_file bot-tele.py /usr/local/bin/bot-tele.py
chmod 0644 /usr/local/bin/bot-tele.py
chmod 0755 /usr/bin/cassanova-domain /etc/letsencrypt/renewal-hooks/deploy/50-cassanova.sh /etc/letsencrypt/renewal-hooks/pre/50-cassanova-stop-nginx.sh /etc/letsencrypt/renewal-hooks/post/50-cassanova-start-nginx.sh
chmod 0644 /etc/systemd/system/cassanova-expire.service /etc/systemd/system/cassanova-expire.timer

# Remove the obsolete standalone HY2 cron entry only when a crontab exists.
# Never replace an unreadable/missing crontab with an empty one.
if crontab -l > "$STAGE/root.crontab.current" 2>/dev/null; then
  awk '!/hy2-manager expire/' "$STAGE/root.crontab.current" > "$STAGE/root.crontab.filtered"
  crontab "$STAGE/root.crontab.filtered"
fi
systemctl daemon-reload
sing-box check -c /etc/sing-box/config.json
systemctl enable --now cassanova-expire.timer
systemctl enable sing-box
systemctl restart sing-box
if [[ $(jq 'length' "$HY2_DB") -gt 0 ]]; then
  if ! /usr/bin/hy2-manager recover; then
    echo 'Hysteria2 DB berhasil dipertahankan, tetapi sinkronisasi akun ke runtime gagal.' >&2
    echo 'Periksa domain/sertifikat, sing-box, lalu jalankan: hy2-manager recover' >&2
    exit 1
  fi
fi
if systemctl is-active --quiet bot-tele; then systemctl restart bot-tele; fi

echo
echo 'Hysteria2 backend berhasil dipasang.'
echo 'Menu utama: menu -> 5) HYSTERIA2'
echo 'PENTING: pastikan domain memiliki sertifikat CA-valid dan buka UDP/443 pada firewall VPS/provider.'
echo 'Buat akun pertama melalui menu Hysteria2; perubahan akun berikutnya memakai SIGHUP reload (tanpa full restart) setelah validasi konfigurasi.'
