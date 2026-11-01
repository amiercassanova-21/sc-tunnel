#!/usr/bin/env bash
# Safe domain change: obtain/verify the new certificate before changing live config.
set -Eeuo pipefail
umask 077

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'Jalankan sebagai root.' >&2; exit 1; }
for cmd in certbot openssl getent curl install systemctl nginx xray; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Dependensi tidak ditemukan: $cmd" >&2; exit 1; }
done

read -rp 'Domain baru (contoh: vpn.example.com): ' NEW_DOMAIN
NEW_DOMAIN=${NEW_DOMAIN,,}
DOMAIN_PATTERN='^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]{0,61}[a-z0-9]?$'
if (( ${#NEW_DOMAIN} > 253 )) || [[ ! "$NEW_DOMAIN" =~ $DOMAIN_PATTERN ]]; then
  echo 'Format domain tidak valid. Gunakan FQDN tanpa http://, port, atau wildcard.' >&2
  exit 1
fi
OLD_DOMAIN=$(tr -d '[:space:]' < /etc/xray/domain.txt 2>/dev/null || true)
if [[ "$NEW_DOMAIN" == "$OLD_DOMAIN" ]]; then
  echo "Domain $NEW_DOMAIN sudah aktif. Tidak ada perubahan."; exit 0
fi

PUBLIC_IP=$(curl -4fsS --connect-timeout 5 --max-time 10 https://api.ipify.org | tr -d '[:space:]') || {
  echo 'Tidak dapat mendeteksi IPv4 publik VPS. Periksa koneksi internet.' >&2; exit 1;
}
DNS_IPS=$(getent ahostsv4 "$NEW_DOMAIN" | awk '{print $1}' | sort -u || true)
DNS_IPV6S=$(getent ahostsv6 "$NEW_DOMAIN" | awk '{print $1}' | sort -u || true)
if [[ "$DNS_IPS" != "$PUBLIC_IP" ]]; then
  echo "DNS A $NEW_DOMAIN harus hanya mengarah ke IPv4 publik VPS ($PUBLIC_IP)." >&2
  printf 'Alamat A yang ditemukan:\n%s\n' "${DNS_IPS:-(tidak ada)}"
  echo 'Proxy Cloudflare, load balancer, atau A record tambahan harus dinonaktifkan selama proses ini.' >&2
  exit 1
fi
if [[ -n "$DNS_IPV6S" ]]; then
  printf 'Domain memiliki AAAA record IPv6 (%s). Tool ini memvalidasi IPv4 saja; sesuaikan/hapus AAAA sementara agar validasi HTTP-01 tidak salah arah.\n' "$DNS_IPV6S" >&2
  exit 1
fi

PANEL_NGINX=/etc/nginx/conf.d/cassanova-xray.conf
XRAY_CONFIG=/usr/local/etc/xray/config.json
SBOX_CONFIG=/etc/sing-box/config.json
[[ -s "$PANEL_NGINX" && -s "$XRAY_CONFIG" ]] || { echo 'Konfigurasi panel Xray/Nginx tidak ditemukan.' >&2; exit 1; }

WORK=$(mktemp -d /var/tmp/cassanova-domain.XXXXXX)
verify_cert_chain() {
  local bundle="$1" leaf="$WORK/leaf.pem" chain="$WORK/chain.pem"
  awk 'BEGIN{n=0} /-----BEGIN CERTIFICATE-----/{n++} n==1{print} /-----END CERTIFICATE-----/ && n==1{exit}' "$bundle" > "$leaf"
  awk 'BEGIN{n=0} /-----BEGIN CERTIFICATE-----/{n++} n>=2{print}' "$bundle" > "$chain"
  [[ -s "$leaf" ]] || return 1
  if [[ -s "$chain" ]]; then
    openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt -untrusted "$chain" "$leaf" >/dev/null 2>&1
  else
    openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt "$leaf" >/dev/null 2>&1
  fi
}
NGINX_WAS_ACTIVE=0
XRAY_WAS_ACTIVE=0
SBOX_WAS_ACTIVE=0
[[ -n "$(systemctl is-active nginx 2>/dev/null || true)" && "$(systemctl is-active nginx 2>/dev/null || true)" == active ]] && NGINX_WAS_ACTIVE=1
[[ "$(systemctl is-active xray 2>/dev/null || true)" == active ]] && XRAY_WAS_ACTIVE=1
[[ "$(systemctl is-active sing-box 2>/dev/null || true)" == active ]] && SBOX_WAS_ACTIVE=1

for file in /etc/xray/domain.txt /etc/xray/sni.txt /etc/xray/xray.crt /etc/xray/xray.key "$PANEL_NGINX"; do
  [[ -e "$file" ]] && cp -a "$file" "$WORK/$(basename "$file")"
done
for file in /etc/sing-box/certs/fullchain.pem /etc/sing-box/certs/privkey.pem; do
  [[ -e "$file" ]] && cp -a "$file" "$WORK/$(basename "$file")"
done

ROLLBACK_DONE=0
MUTATION_STARTED=0
rollback() {
  echo '[ROLLBACK] Mengembalikan domain, sertifikat, dan konfigurasi sebelumnya.' >&2
  restore_xray_file() {
    local name="$1" mode="$2" backup="$WORK/$1"
    if [[ -e "$backup" ]]; then install -o root -g root -m "$mode" "$backup" "/etc/xray/$name"
    else rm -f "/etc/xray/$name"; fi
  }
  restore_xray_file domain.txt 0644
  restore_xray_file sni.txt 0644
  restore_xray_file xray.crt 0644
  restore_xray_file xray.key 0600
  if [[ -e "$WORK/cassanova-xray.conf" ]]; then
    install -o root -g root -m 0644 "$WORK/cassanova-xray.conf" "$PANEL_NGINX"
  else
    rm -f "$PANEL_NGINX"
  fi
  if [[ -d /etc/sing-box/certs ]]; then
    getent group sing-box >/dev/null 2>&1 || groupadd --system sing-box
    if [[ -e "$WORK/fullchain.pem" ]]; then install -o root -g sing-box -m 0640 "$WORK/fullchain.pem" /etc/sing-box/certs/fullchain.pem; else rm -f /etc/sing-box/certs/fullchain.pem; fi
    if [[ -e "$WORK/privkey.pem" ]]; then install -o root -g sing-box -m 0640 "$WORK/privkey.pem" /etc/sing-box/certs/privkey.pem; else rm -f /etc/sing-box/certs/privkey.pem; fi
  fi
  systemctl daemon-reload >/dev/null 2>&1 || true
  nginx -t >/dev/null 2>&1 || true
  (( XRAY_WAS_ACTIVE == 0 )) || systemctl restart xray >/dev/null 2>&1 || true
  (( SBOX_WAS_ACTIVE == 0 )) || systemctl restart sing-box >/dev/null 2>&1 || true
  if (( NGINX_WAS_ACTIVE )); then
    systemctl restart nginx >/dev/null 2>&1 || true
    NGINX_STOPPED_BY_SCRIPT=0
  fi
  ROLLBACK_DONE=1
}

NGINX_STOPPED_BY_SCRIPT=0
cleanup() {
  local exit_status=$?
  trap - EXIT
  if (( exit_status != 0 && MUTATION_STARTED && !ROLLBACK_DONE )); then rollback; fi
  rm -f /etc/xray/.xray.crt.new /etc/xray/.xray.key.new /etc/sing-box/certs/.fullchain.pem.new /etc/sing-box/certs/.privkey.pem.new
  # Safety net: never leave a previously active Nginx stopped after an early error.
  if (( NGINX_WAS_ACTIVE && NGINX_STOPPED_BY_SCRIPT )); then
    systemctl start nginx >/dev/null 2>&1 || echo 'PERINGATAN: Nginx perlu dinyalakan manual: systemctl start nginx' >&2
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

if (( NGINX_WAS_ACTIVE )); then
  systemctl stop nginx
  NGINX_STOPPED_BY_SCRIPT=1
fi
if ! certbot certonly --standalone --agree-tos --register-unsafely-without-email \
    -d "$NEW_DOMAIN" --non-interactive --preferred-challenges http; then
  echo 'Penerbitan sertifikat gagal. Domain lama tetap dipakai.' >&2
  if (( NGINX_STOPPED_BY_SCRIPT )); then systemctl start nginx; NGINX_STOPPED_BY_SCRIPT=0; fi
  exit 1
fi

CERT="/etc/letsencrypt/live/$NEW_DOMAIN/fullchain.pem"
KEY="/etc/letsencrypt/live/$NEW_DOMAIN/privkey.pem"
if [[ ! -s "$CERT" || ! -s "$KEY" ]] || \
   ! openssl x509 -in "$CERT" -noout -checkhost "$NEW_DOMAIN" >/dev/null 2>&1 || \
   ! openssl x509 -in "$CERT" -noout -checkend 0 >/dev/null 2>&1 || \
   ! verify_cert_chain "$CERT"; then
  echo 'Sertifikat baru tidak valid/CA tidak tepercaya. Domain lama dipertahankan.' >&2
  if (( NGINX_STOPPED_BY_SCRIPT )); then systemctl start nginx; NGINX_STOPPED_BY_SCRIPT=0; fi
  exit 1
fi
CERT_PUB=$(openssl x509 -in "$CERT" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')
KEY_PUB=$(openssl pkey -in "$KEY" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')
if [[ -z "$CERT_PUB" || "$CERT_PUB" != "$KEY_PUB" ]]; then
  echo 'Sertifikat dan private key tidak cocok. Domain lama dipertahankan.' >&2
  if (( NGINX_STOPPED_BY_SCRIPT )); then systemctl start nginx; NGINX_STOPPED_BY_SCRIPT=0; fi
  exit 1
fi

if ! install -m 0644 "$CERT" /etc/xray/.xray.crt.new || ! install -m 0600 "$KEY" /etc/xray/.xray.key.new; then
  if (( NGINX_STOPPED_BY_SCRIPT )); then systemctl start nginx; NGINX_STOPPED_BY_SCRIPT=0; fi
  echo 'Gagal menyalin sertifikat. Domain lama dipertahankan.' >&2; exit 1
fi
MUTATION_STARTED=1
mv -f /etc/xray/.xray.crt.new /etc/xray/xray.crt
mv -f /etc/xray/.xray.key.new /etc/xray/xray.key
printf '%s\n' "$NEW_DOMAIN" > /etc/xray/domain.txt
printf '%s\n' "$NEW_DOMAIN" > /etc/xray/sni.txt
sed -i -E "s/server_name[[:space:]]+[^;]+;/server_name ${NEW_DOMAIN};/" "$PANEL_NGINX"

if [[ -d /etc/sing-box/certs ]]; then
  getent group sing-box >/dev/null 2>&1 || groupadd --system sing-box
  install -d -o root -g sing-box -m 0750 /etc/sing-box/certs
  install -o root -g sing-box -m 0640 "$CERT" /etc/sing-box/certs/.fullchain.pem.new
  install -o root -g sing-box -m 0640 "$KEY" /etc/sing-box/certs/.privkey.pem.new
  mv -f /etc/sing-box/certs/.fullchain.pem.new /etc/sing-box/certs/fullchain.pem
  mv -f /etc/sing-box/certs/.privkey.pem.new /etc/sing-box/certs/privkey.pem
fi

if ! xray run -test -config "$XRAY_CONFIG" >/dev/null || ! nginx -t >/dev/null; then
  rollback
  echo 'Validasi Xray/Nginx gagal. Domain lama dikembalikan.' >&2
  exit 1
fi
if command -v sing-box >/dev/null 2>&1 && [[ -s "$SBOX_CONFIG" ]]; then
  if ! sing-box check -c "$SBOX_CONFIG" >/dev/null; then
    rollback
    echo 'Validasi sing-box gagal. Domain lama dikembalikan.' >&2
    exit 1
  fi
fi

if (( XRAY_WAS_ACTIVE )); then
  if ! systemctl restart xray || ! systemctl is-active --quiet xray; then rollback; echo 'Xray gagal setelah ganti domain; rollback dijalankan.' >&2; exit 1; fi
fi
if (( SBOX_WAS_ACTIVE )); then
  if ! systemctl kill --signal=HUP --kill-whom=main sing-box || ! systemctl is-active --quiet sing-box; then
    if ! systemctl restart sing-box || ! systemctl is-active --quiet sing-box; then rollback; echo 'sing-box gagal memuat sertifikat baru; rollback dijalankan.' >&2; exit 1; fi
  fi
fi
if (( NGINX_WAS_ACTIVE )); then
  if ! systemctl start nginx || ! systemctl is-active --quiet nginx; then rollback; echo 'Nginx gagal setelah ganti domain; rollback dijalankan.' >&2; exit 1; fi
  NGINX_STOPPED_BY_SCRIPT=0
fi

echo "Domain berhasil diubah menjadi $NEW_DOMAIN. Sertifikat Xray, Nginx, dan sing-box telah diperbarui."
echo 'Catatan: pastikan firewall/provider mengizinkan TCP 80/443/2096 dan UDP 443 bila Hysteria2 digunakan.'
