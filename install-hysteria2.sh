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
REPO='https://raw.githubusercontent.com/amiercassanova-21/sc-tunnel/main'
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

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
install -d -m 0700 /var/backups/cassanova/hysteria2
[[ -s /etc/sing-box/users.json ]] || printf '[]\n' > /etc/sing-box/users.json
chown root:root /etc/sing-box/users.json; chmod 0600 /etc/sing-box/users.json
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
  install -D -m 0755 "$STAGE/$(basename "$dest")" "$dest"
}
install_file modules/hy2-manager.sh /usr/bin/hy2-manager
install_file modules/m-hysteria2.sh /usr/bin/m-hysteria2
install_file menu.sh /usr/bin/menu
install_file update.sh /usr/bin/update-sc
install_file bot-tele.py /usr/local/bin/bot-tele.py
chmod 0644 /usr/local/bin/bot-tele.py

(crontab -l 2>/dev/null | grep -v 'hy2-manager expire' || true; echo '1 0 * * * /usr/bin/hy2-manager expire') | crontab -
systemctl daemon-reload
systemctl enable sing-box
systemctl restart sing-box
if systemctl is-active --quiet bot-tele; then systemctl restart bot-tele; fi

echo
echo 'Hysteria2 backend berhasil dipasang.'
echo 'Menu utama: menu -> 5) HYSTERIA2'
echo 'PENTING: pastikan domain memiliki sertifikat CA-valid dan buka UDP/443 pada firewall VPS/provider.'
echo 'Buat akun pertama melalui menu Hysteria2; perubahan akun berikutnya memakai SIGHUP reload (tanpa full restart) setelah validasi konfigurasi.'
