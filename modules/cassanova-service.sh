#!/usr/bin/env bash
# SC Cassanova Tunneling V2 - guarded service and reverse-proxy manager
set -Eeuo pipefail
umask 077

XRAY_CONFIG='/usr/local/etc/xray/config.json'
SBOX_CONFIG='/etc/sing-box/config.json'
NGINX_PANEL='/etc/nginx/conf.d/cassanova-xray.conf'

fail() { printf 'ERROR: %s\n' "$*" >&2; return 1; }
need_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || fail 'Jalankan sebagai root.'; }

validate_xray() {
  command -v xray >/dev/null 2>&1 || { echo 'Xray: binary tidak ditemukan'; return 1; }
  [[ -s "$XRAY_CONFIG" ]] || { echo "Xray: konfigurasi tidak ditemukan: $XRAY_CONFIG"; return 1; }
  xray run -test -config "$XRAY_CONFIG"
}
validate_singbox() {
  command -v sing-box >/dev/null 2>&1 || { echo 'sing-box: binary tidak ditemukan'; return 1; }
  [[ -s "$SBOX_CONFIG" ]] || { echo "sing-box: konfigurasi tidak ditemukan: $SBOX_CONFIG"; return 1; }
  sing-box check -c "$SBOX_CONFIG"
}
validate_nginx() {
  command -v nginx >/dev/null 2>&1 || { echo 'Nginx: binary tidak ditemukan'; return 1; }
  nginx -t
}

validate_all() {
  local rc=0
  echo '=== Validasi konfigurasi ==='
  validate_xray || rc=1
  validate_singbox || rc=1
  validate_nginx || rc=1
  (( rc == 0 )) && echo 'Semua konfigurasi valid.' || echo 'Ada konfigurasi yang gagal. Tidak ada service yang direstart.'
  return "$rc"
}

service_state() {
  local svc=$1
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    printf '%-24s %s\n' "$svc" 'ACTIVE'
  elif systemctl is-enabled --quiet "$svc" 2>/dev/null; then
    printf '%-24s %s\n' "$svc" 'INACTIVE (enabled)'
  else
    printf '%-24s %s\n' "$svc" 'NOT ACTIVE / NOT ENABLED'
  fi
}

status_all() {
  echo '=== Status service Cassanova ==='
  local svc
  for svc in xray sing-box nginx cassanova-dropbear ssh fail2ban vnstat bot-tele; do
    systemctl list-unit-files "${svc}.service" --no-legend 2>/dev/null | grep -q . || continue
    service_state "$svc"
  done
  echo
  echo '=== Status konfigurasi ==='
  [[ -s "$XRAY_CONFIG" ]] && echo 'Xray config       : tersedia' || echo 'Xray config       : tidak ada'
  [[ -s "$SBOX_CONFIG" ]] && echo 'sing-box config   : tersedia' || echo 'sing-box config   : tidak ada'
  [[ -s "$NGINX_PANEL" ]] && echo 'Nginx panel conf  : tersedia' || echo 'Nginx panel conf  : tidak ada'
}

port_status() {
  command -v ss >/dev/null 2>&1 || fail 'Perintah ss tidak ditemukan.'
  echo '=== Listener TCP/UDP ==='
  ss -H -lntup
  echo
  echo 'Catatan: output menunjukkan proses yang sedang listen; aturan firewall provider tidak dapat diverifikasi dari VPS.'
}

tls_status() {
  local domain cert key tmp_dir tmp_leaf tmp_chain cert_pub key_pub verify_rc
  domain=$(tr -d '[:space:]' < /etc/xray/domain.txt 2>/dev/null || true)
  cert='/etc/xray/xray.crt'; key='/etc/xray/xray.key'
  echo '=== Pemeriksaan sertifikat TLS ==='
  [[ -n "$domain" ]] || { echo 'Domain belum diatur.'; return 1; }
  [[ -s "$cert" && -s "$key" ]] || { echo 'Sertifikat atau private key tidak ditemukan.'; return 1; }
  openssl x509 -in "$cert" -noout -subject -issuer -dates || return 1
  openssl x509 -in "$cert" -checkend 0 -noout >/dev/null || { echo 'Sertifikat sudah kedaluwarsa.'; return 1; }
  openssl x509 -in "$cert" -checkhost "$domain" -noout >/dev/null 2>&1 || { echo "Sertifikat tidak cocok dengan domain $domain."; return 1; }
  cert_pub=$(openssl x509 -in "$cert" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}') || return 1
  key_pub=$(openssl pkey -in "$key" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}') || return 1
  [[ -n "$cert_pub" && "$cert_pub" == "$key_pub" ]] || { echo 'Private key tidak cocok dengan sertifikat.'; return 1; }
  tmp_dir=$(mktemp -d)
  tmp_leaf="$tmp_dir/leaf.pem"
  tmp_chain="$tmp_dir/chain.pem"
  awk 'BEGIN{n=0} /-----BEGIN CERTIFICATE-----/{n++} n==1{print} /-----END CERTIFICATE-----/ && n==1{exit}' "$cert" > "$tmp_leaf"
  awk 'BEGIN{n=0} /-----BEGIN CERTIFICATE-----/{n++} n>=2{print}' "$cert" > "$tmp_chain"
  if openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt -untrusted "$tmp_chain" "$tmp_leaf" >/dev/null 2>&1; then
    verify_rc=0
  else
    verify_rc=1
  fi
  rm -rf "$tmp_dir"
  if (( verify_rc != 0 )); then
    echo 'Trust status       : TIDAK TERVERIFIKASI oleh CA sistem (kemungkinan self-signed/private CA)'
    return 1
  fi
  echo 'Trust status       : CA terpercaya (validasi lokal berhasil)'
  echo 'Hostname           : cocok'
  echo 'Private key        : cocok'
}

restart_one() {
  local svc=$1
  case "$svc" in
    xray) validate_xray || return 1 ;;
    sing-box) validate_singbox || return 1 ;;
    nginx) validate_nginx || return 1 ;;
    cassanova-dropbear|ssh|fail2ban|vnstat|bot-tele) ;;
    *) fail "Service tidak diizinkan: $svc"; return 1 ;;
  esac
  systemctl cat "$svc" >/dev/null 2>&1 || { echo "Unit $svc tidak ditemukan."; return 1; }
  systemctl restart "$svc" && systemctl is-active --quiet "$svc" || {
    echo "Service $svc gagal aktif. Periksa: journalctl -u $svc -n 80 --no-pager" >&2
    return 1
  }
  echo "Service $svc berhasil direstart dan aktif."
}

reload_nginx() {
  validate_nginx || { echo 'Nginx tidak direload karena validasi gagal.' >&2; return 1; }
  systemctl is-active --quiet nginx || { echo 'Nginx belum aktif; gunakan restart nginx.' >&2; return 1; }
  systemctl reload nginx && echo 'Nginx berhasil reload tanpa memutus proses master.'
}

restart_all() {
  local failed=0 svc
  validate_all || return 1
  for svc in xray sing-box nginx cassanova-dropbear fail2ban vnstat; do
    systemctl cat "$svc" >/dev/null 2>&1 || continue
    restart_one "$svc" || failed=1
  done
  if (( failed )); then
    echo 'Sebagian service gagal direstart. Lihat status dan journalctl masing-masing.' >&2
    return 1
  fi
  echo 'Seluruh service yang terpasang berhasil direstart.'
}

ui() {
  while true; do
    clear 2>/dev/null || true
    echo '════════ CASSANOVA SERVICE MANAGER ════════'
    echo '1) Status service'
    echo '2) Validasi semua konfigurasi'
    echo '3) Tampilkan port TCP/UDP'
    echo '4) Periksa sertifikat TLS'
    echo '5) Restart Xray'
    echo '6) Restart sing-box / Hysteria2'
    echo '7) Restart Nginx (setelah validasi)'
    echo '8) Reload Nginx (setelah validasi)'
    echo '9) Restart Dropbear'
    echo '10) Restart semua service'
    echo 'x) Kembali'
    read -rp 'Pilih: ' opt || return 0
    case "$opt" in
      1) status_all ;;
      2) validate_all ;;
      3) port_status ;;
      4) tls_status ;;
      5) restart_one xray ;;
      6) restart_one sing-box ;;
      7) restart_one nginx ;;
      8) reload_nginx ;;
      9) restart_one cassanova-dropbear ;;
      10) restart_all ;;
      x|X) return 0 ;;
      *) echo 'Pilihan tidak valid.' ;;
    esac
    echo
    read -rp 'Tekan Enter untuk kembali...' _ || true
  done
}

main() {
  need_root
  local action=${1:-ui}
  case "$action" in
    status) status_all ;;
    validate) validate_all ;;
    ports) port_status ;;
    tls-check) tls_status ;;
    restart) [[ $# -eq 2 ]] || fail 'Gunakan: cassanova-service restart SERVICE'; restart_one "$2" ;;
    restart-all) restart_all ;;
    reload-nginx) reload_nginx ;;
    ui) ui ;;
    *) echo 'Penggunaan: cassanova-service {ui|status|validate|ports|tls-check|restart SERVICE|restart-all|reload-nginx}'; return 2 ;;
  esac
}
main "$@"
