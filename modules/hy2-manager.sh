#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

DB=/etc/sing-box/users.json
CONFIG=/etc/sing-box/config.json
LOCK=/run/lock/cassanova-hy2.lock
BACKUP=/var/backups/cassanova/hysteria2
SERVICE=sing-box
PORT=443
NOTIFIER=/usr/local/bin/cassanova-notify.py

[[ $EUID -eq 0 ]] || { echo "Jalankan sebagai root." >&2; exit 1; }
for c in jq flock sing-box openssl install mktemp systemctl; do command -v "$c" >/dev/null 2>&1 || { echo "Dependensi tidak ditemukan: $c" >&2; exit 1; }; done
install -d -m 0700 "$(dirname "$DB")" "$BACKUP" /run/lock
[[ -s "$DB" ]] || printf '[]\n' > "$DB"
[[ -s "$CONFIG" ]] || printf '{"log":{"level":"warn"},"inbounds":[],"outbounds":[{"type":"direct","tag":"direct"}]}\n' > "$CONFIG"
jq -e 'type == "array"' "$DB" >/dev/null || { echo "Database Hysteria2 rusak; hentikan agar data tidak tertimpa." >&2; exit 1; }
exec 9>"$LOCK"; flock -x 9

valid_user(){ [[ "$1" =~ ^[A-Za-z0-9_.-]{1,32}$ ]]; }
valid_days(){ [[ "$1" =~ ^[0-9]{1,5}$ ]] && (( 10#$1 >= 1 )); }

get_tls_paths(){
  DOMAIN=$(tr -d '[:space:]' < /etc/xray/domain.txt 2>/dev/null || true)
  [[ -n "$DOMAIN" ]] || { echo "Domain belum disetel. Hysteria2 membutuhkan domain dengan sertifikat TLS valid." >&2; return 1; }
  local le="/etc/letsencrypt/live/${DOMAIN}"
  if [[ -s "$le/fullchain.pem" && -s "$le/privkey.pem" ]]; then CERT="$le/fullchain.pem"; KEY="$le/privkey.pem"
  else CERT=/etc/xray/xray.crt; KEY=/etc/xray/xray.key; fi
  [[ -s "$CERT" && -s "$KEY" ]] || { echo "Sertifikat/privkey tidak ditemukan." >&2; return 1; }
  openssl x509 -in "$CERT" -noout -checkhost "$DOMAIN" >/dev/null 2>&1 || { echo "Sertifikat tidak cocok dengan domain $DOMAIN." >&2; return 1; }
  openssl x509 -in "$CERT" -noout -checkend 0 >/dev/null 2>&1 || { echo "Sertifikat TLS sudah kedaluwarsa." >&2; return 1; }
  openssl verify -CApath /etc/ssl/certs "$CERT" >/dev/null 2>&1 || { echo "Sertifikat bukan rantai CA tepercaya. Terbitkan sertifikat Let's Encrypt atau pasang sertifikat CA-valid." >&2; return 1; }
  local certpub keypub
  certpub=$(openssl x509 -in "$CERT" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')
  keypub=$(openssl pkey -in "$KEY" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')
  [[ -n "$certpub" && "$certpub" == "$keypub" ]] || { echo "Sertifikat dan private key tidak berpasangan." >&2; return 1; }
  # Make a protected copy readable by the packaged sing-box service account.
  # Never relax permissions on Certbot's original private key.
  if ! getent group sing-box >/dev/null 2>&1; then groupadd --system sing-box; fi
  if ! getent passwd sing-box >/dev/null 2>&1; then
    useradd --system --gid sing-box --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin sing-box
  fi
  install -d -o root -g sing-box -m 0750 /etc/sing-box/certs
  install -o root -g sing-box -m 0640 "$CERT" /etc/sing-box/certs/fullchain.pem
  install -o root -g sing-box -m 0640 "$KEY" /etc/sing-box/certs/privkey.pem
  CERT=/etc/sing-box/certs/fullchain.pem
  KEY=/etc/sing-box/certs/privkey.pem
}

build_config(){
  local dbfile="$1" outfile="$2"
  get_tls_paths
  jq -n --arg cert "$CERT" --arg key "$KEY" --arg today "$(date +%F)" --slurpfile records "$dbfile" '
    {log:{level:"warn"},
     inbounds:[{type:"hysteria2",tag:"hysteria2-in",listen:"::",listen_port:443,
       users:([$records[0][] | select(.status == "active" and .expiry >= $today) | {name:.username,password:.password}]),
       tls:{enabled:true,certificate_path:$cert, key_path:$key},
       masquerade:{type:"string",status_code:404,headers:{},content:"Not Found"}}],
     outbounds:[{type:"direct",tag:"direct"}]}' > "$outfile"
  sing-box check -c "$outfile" >/dev/null
}

apply_db(){
  local newdb="$1" stamp tmpcfg olddb oldcfg restart_needed=1
  stamp=$(date +%Y%m%d-%H%M%S)
  tmpcfg=$(mktemp /etc/sing-box/config.json.XXXXXX)
  olddb=$(mktemp); oldcfg=$(mktemp)
  cp -a "$DB" "$olddb"
  cp -a "$CONFIG" "$oldcfg"
  if ! build_config "$newdb" "$tmpcfg"; then
    rm -f "$tmpcfg" "$olddb" "$oldcfg"
    echo "Validasi sing-box gagal; perubahan dibatalkan." >&2
    return 1
  fi
  # Renewal or metadata-only changes should not interrupt active Hysteria2 users
  # when the effective sing-box runtime configuration is unchanged.
  if cmp -s "$tmpcfg" "$CONFIG"; then restart_needed=0; fi
  cp -a "$DB" "$BACKUP/users-${stamp}.json"
  cp -a "$CONFIG" "$BACKUP/config-${stamp}.json"
  if ! install -o root -g root -m 0600 "$newdb" "$DB"; then
    rm -f "$tmpcfg" "$olddb" "$oldcfg"
    echo "Gagal menyimpan database Hysteria2; perubahan dibatalkan." >&2
    return 1
  fi
  if ! install -o root -g sing-box -m 0640 "$tmpcfg" "$CONFIG"; then
    install -o root -g root -m 0600 "$olddb" "$DB" || true
    install -o root -g sing-box -m 0640 "$oldcfg" "$CONFIG" || true
    rm -f "$tmpcfg" "$olddb" "$oldcfg"
    echo "Gagal memasang konfigurasi sing-box; state lama dipulihkan." >&2
    return 1
  fi
  rm -f "$tmpcfg"
  if (( restart_needed )); then
    # sing-box handles SIGHUP by reloading its configuration. Avoid a full
    # restart so existing Hysteria2 sessions are not deliberately torn down.
    if ! systemctl is-active --quiet "$SERVICE" ||
       ! systemctl kill --signal=HUP --kill-whom=main "$SERVICE"; then
      install -o root -g root -m 0600 "$olddb" "$DB" || true
      install -o root -g sing-box -m 0640 "$oldcfg" "$CONFIG" || true
      systemctl kill --signal=HUP --kill-whom=main "$SERVICE" >/dev/null 2>&1 || true
      rm -f "$olddb" "$oldcfg"
      echo "Gagal mengirim SIGHUP ke sing-box. Database dan konfigurasi lama telah dipulihkan." >&2
      return 1
    fi
    sleep 1
    if ! systemctl is-active --quiet "$SERVICE"; then
      install -o root -g root -m 0600 "$olddb" "$DB" || true
      install -o root -g sing-box -m 0640 "$oldcfg" "$CONFIG" || true
      systemctl restart "$SERVICE" >/dev/null 2>&1 || true
      rm -f "$olddb" "$oldcfg"
      echo "sing-box tidak aktif setelah reload. State lama dipulihkan; layanan dicoba dinyalakan kembali." >&2
      return 1
    fi
  fi
  rm -f "$olddb" "$oldcfg"
  if (( restart_needed )); then
    echo "Konfigurasi dimuat ulang dengan SIGHUP; tidak ada full restart sing-box."
  else
    echo "Konfigurasi runtime tidak berubah; sing-box tidak direload."
  fi
}

list_users(){
  printf '\n%-18s %-12s %-10s\n' USERNAME EXPIRED STATUS
  jq -r '.[] | [.username,.expiry,.status] | @tsv' "$DB" | while IFS=$'\t' read -r u e st; do printf '%-18s %-12s %-10s\n' "$u" "$e" "$st"; done
}
show_link(){
  local u="$1" pass="$2" host
  host=$(tr -d '[:space:]' < /etc/xray/domain.txt)
  printf '\nHYSTERIA2 ACCOUNT\nUsername : %s\nDomain   : %s\nPort     : %s/UDP\nPassword : %s\n' "$u" "$host" "$PORT" "$pass"
  printf 'Link     : hysteria2://%s@%s:%s/?sni=%s#%s-Cassanova\n' "$pass" "$host" "$PORT" "$host" "$u"
}
notify_event(){
  local event="$1" username="${2:-}" expiry="${3:-}" credential="${4:-}" details="${5:-[]}" links="${6:-}"
  local host; host=$(tr -d '[:space:]' < /etc/xray/domain.txt 2>/dev/null || true)
  [[ -f "$NOTIFIER" ]] || { echo 'Peringatan: notifier Telegram belum terpasang.' >&2; return 0; }
  jq -cn --arg event "$event" --arg protocol HYSTERIA2 --arg username "$username" \
    --arg expiry "$expiry" --arg credential "$credential" --arg links "$links" \
    --arg context "sing-box | UDP/$PORT | Domain: ${host:-tidak diketahui}" --argjson details "$details" \
    '{event:$event,protocol:$protocol,username:$username,expiry:$expiry,credential:$credential,links:$links,context:$context,details:$details}' \
    | python3 "$NOTIFIER" || echo 'Peringatan: notifikasi Telegram gagal; perubahan akun telah diterapkan.' >&2
}

ACTION="${1:-menu}"
case "$ACTION" in
 create|custom)
  read -rp 'Username: ' U; valid_user "$U" || { echo 'Username tidak valid.'; exit 1; }
  jq -e --arg u "$U" 'any(.[]; .username==$u)' "$DB" >/dev/null && { echo 'Username sudah digunakan.'; exit 1; } || true
  if [[ "$ACTION" == custom ]]; then read -rsp 'Password: ' PASS; echo; else PASS=$(openssl rand -hex 20); fi
  [[ "$PASS" =~ ^[A-Za-z0-9._~-]{12,128}$ ]] || { echo 'Password harus 12-128 karakter (A-Z a-z 0-9 . _ ~ -).'; exit 1; }
  read -rp 'Masa aktif (hari): ' DAYS; valid_days "$DAYS" || { echo 'Masa aktif tidak valid.'; exit 1; }
  EXP=$(date -d "+${DAYS} days" +%Y-%m-%d)
  NEW=$(mktemp); jq --arg u "$U" --arg p "$PASS" --arg e "$EXP" '. + [{username:$u,password:$p,expiry:$e,status:"active"}]' "$DB" > "$NEW"
  apply_db "$NEW"; rm -f "$NEW"; show_link "$U" "$PASS"; LINK=$(printf 'hysteria2://%s@%s:%s/?sni=%s#%s-Cassanova' "$PASS" "$(tr -d '[:space:]' < /etc/xray/domain.txt)" "$PORT" "$(tr -d '[:space:]' < /etc/xray/domain.txt)" "$U"); echo "Akun dibuat; kedaluwarsa $EXP. Pastikan UDP/$PORT dibuka di firewall VPS dan firewall provider."; notify_event create "$U" "$EXP" "$PASS" '[]' "$LINK" ;;
 list) list_users ;;
 delete|renew|modify|lock|unlock)
  list_users; read -rp 'Username: ' U; valid_user "$U" || exit 1
  jq -e --arg u "$U" 'any(.[]; .username==$u)' "$DB" >/dev/null || { echo 'Akun tidak ditemukan.'; exit 1; }
  OLD_RECORD=$(jq -c --arg u "$U" '.[] | select(.username==$u)' "$DB")
  OLD_EXP=$(jq -r '.expiry' <<< "$OLD_RECORD"); OLD_PASS=$(jq -r '.password' <<< "$OLD_RECORD")
  NEW=$(mktemp)
  case "$ACTION" in
   delete) jq --arg u "$U" '[.[] | select(.username!=$u)]' "$DB" > "$NEW" ;;
   renew) read -rp 'Tambah masa aktif (hari): ' DAYS; valid_days "$DAYS" || exit 1; jq --arg u "$U" --arg e "$(date -d "+${DAYS} days" +%Y-%m-%d)" 'map(if .username==$u then .expiry=$e else . end)' "$DB" > "$NEW" ;;
   modify) read -rsp 'Password baru: ' PASS; echo; [[ "$PASS" =~ ^[A-Za-z0-9._~-]{12,128}$ ]] || { rm -f "$NEW"; echo 'Password tidak valid.'; exit 1; }; jq --arg u "$U" --arg p "$PASS" 'map(if .username==$u then .password=$p else . end)' "$DB" > "$NEW" ;;
   lock) jq --arg u "$U" 'map(if .username==$u then .status="locked" else . end)' "$DB" > "$NEW" ;;
   unlock) jq --arg u "$U" 'map(if .username==$u then .status="active" else . end)' "$DB" > "$NEW" ;;
  esac
  apply_db "$NEW"; rm -f "$NEW"; echo "Operasi $ACTION berhasil untuk $U."
  case "$ACTION" in
    delete) notify_event delete "$U" "$OLD_EXP" "$OLD_PASS" ;;
    renew) NEW_EXP=$(jq -r --arg u "$U" '.[] | select(.username==$u) | .expiry' "$DB"); notify_event renew "$U" "$NEW_EXP" "$OLD_PASS" ;;
    modify) notify_event modify "$U" "$OLD_EXP" "$PASS" ;;
    lock|unlock) notify_event "$ACTION" "$U" "$OLD_EXP" "$OLD_PASS" ;;
  esac
  ;;
 expire)
  TODAY=$(date +%F); EXPIRED=$(jq -c --arg d "$TODAY" '[.[] | select(.expiry < $d and .status=="active")]' "$DB"); NEW=$(mktemp); jq --arg d "$TODAY" '[.[] | select(.expiry >= $d)]' "$DB" > "$NEW"
  if ! cmp -s "$DB" "$NEW"; then apply_db "$NEW"; while IFS= read -r item; do [[ -n "$item" ]] || continue; notify_event expired "$(jq -r '.username' <<< "$item")" "$(jq -r '.expiry' <<< "$item")" "$(jq -r '.password' <<< "$item")"; done < <(jq -c '.[]' <<< "$EXPIRED"); echo 'Akun kedaluwarsa dibersihkan.'; else echo 'Tidak ada akun kedaluwarsa.'; fi
  rm -f "$NEW" ;;
 recover|recovery)
  DETAILS=$(jq -c --arg d "$(date +%F)" '[.[] | select(.status=="active" and .expiry >= $d) | {username,expiry,password,status}]' "$DB")
  TMP=$(mktemp); cp -a "$DB" "$TMP"
  if apply_db "$TMP"; then COUNT=$(jq 'length' <<< "$DETAILS"); echo "Recovery Hysteria2 selesai: $COUNT akun aktif dan belum expired disinkronkan."; notify_event recovery '' '' '' "$DETAILS"; else echo 'Recovery Hysteria2 gagal; konfigurasi lama dipulihkan.' >&2; exit 1; fi
  rm -f "$TMP" ;;
 check)
  sing-box check -c "$CONFIG" && systemctl is-active "$SERVICE" ;;
 *)
  echo 'Gunakan: hy2-manager {create|custom|list|delete|renew|modify|lock|unlock|expire|recover|check}' ; exit 2 ;;
esac
