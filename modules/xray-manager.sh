#!/usr/bin/env bash
# SC Cassanova Tunneling V2 - live Xray account manager.
# Account changes use Xray HandlerService API; no Xray restart for CRUD/recovery.
set -Eeuo pipefail
umask 077

PROTO="${1:-}"; ACTION="${2:-}"
case "$PROTO" in vless|vmess|trojan) ;; *) echo "Protokol tidak valid." >&2; exit 2;; esac

DB_FILE="/etc/xray/${PROTO}.db"
CONFIG="/usr/local/etc/xray/config.json"
LOCK_FILE="/run/lock/cassanova-xray-manager.lock"
LIMIT_IP_DIR="/etc/xray/limit/ip"; LIMIT_BW_DIR="/etc/xray/limit/bw"
BACKUP_DIR="/var/backups/cassanova/xray"
XRAY_BIN="$(command -v xray || true)"
API_ADDR="127.0.0.1:10085"
NOTIFIER="/usr/local/bin/cassanova-notify.py"

[[ $EUID -eq 0 ]] || { echo "Jalankan sebagai root." >&2; exit 1; }
[[ -n "$XRAY_BIN" && -s "$CONFIG" && -f "$DB_FILE" ]] || { echo "Xray/config/database belum siap." >&2; exit 1; }
for cmd in jq flock mktemp install python3 date awk ss; do command -v "$cmd" >/dev/null 2>&1 || { echo "Dependensi tidak ditemukan: $cmd" >&2; exit 1; }; done
install -d -m 0700 "$LIMIT_IP_DIR" "$LIMIT_BW_DIR" "$BACKUP_DIR" /run/lock
jq -e '.inbounds | type == "array"' "$CONFIG" >/dev/null || { echo "Config Xray bukan JSON valid." >&2; exit 1; }
exec 9>"$LOCK_FILE"; flock -x 9

valid_user() { [[ "$1" =~ ^[A-Za-z0-9_.@-]{1,32}$ ]]; }
valid_days() { [[ "$1" =~ ^[0-9]{1,5}$ ]] && (( 10#$1 >= 1 && 10#$1 <= 36500 )); }
valid_uuid() { [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ ]]; }
valid_number() { [[ "$1" =~ ^[0-9]{1,9}$ ]]; }

api_configured() {
  jq -e '((.api.services // []) | index("HandlerService") != null) and any(.inbounds[]?; .tag == "api-in" and .protocol == "dokodemo-door" and .listen == "127.0.0.1" and .port == 10085) and any(.outbounds[]?; .tag == "api" and .protocol == "freedom") and any(.routing.rules[]?; ((.inboundTag // []) | index("api-in") != null) and .outboundTag == "api")' "$CONFIG" >/dev/null 2>&1
}
api_enabled() {
  api_configured && ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Fq "$API_ADDR"
}
stats_enabled() {
  api_enabled && jq -e '((.api.services // []) | index("StatsService") != null) and (.policy.levels["0"].statsUserUplink == true) and (.policy.levels["0"].statsUserDownlink == true)' "$CONFIG" >/dev/null 2>&1
}

backup_state() {
  local stamp; stamp=$(date -u +%Y%m%dT%H%M%SZ)
  cp -a "$CONFIG" "$BACKUP_DIR/config-${stamp}.json"
  cp -a "$DB_FILE" "$BACKUP_DIR/${PROTO}-db-${stamp}.db"
  chmod 0600 "$BACKUP_DIR/config-${stamp}.json" "$BACKUP_DIR/${PROTO}-db-${stamp}.db"
}

atomic_install() {
  local src="$1" dst="$2" mode="${3:-0600}" owner="${4:-root:root}" tmp
  tmp=$(mktemp "${dst}.XXXXXX")
  cat "$src" > "$tmp"
  chown "$owner" "$tmp"; chmod "$mode" "$tmp"
  mv -f "$tmp" "$dst"
}

get_record() {
  awk -v u="$1" '$1=="###" && $2==u {print; found=1} END {if(!found) exit 1}' "$DB_FILE"
}
list_records() {
  printf '\n%-4s %-18s %-12s %-10s\n' NO USERNAME EXPIRED STATUS
  awk '$1=="###" {printf "%-4d %-18s %-12s %-10s\n", ++n, $2, $3, ($5=="locked"?"locked":"active")}' "$DB_FILE"
}

protocol_tags() { jq -r --arg p "$PROTO" '.inbounds[] | select(.protocol==$p) | .tag // empty' "$CONFIG"; }
api_add_tag() {
  local tag="$1" user_json="$2" out
  out=$("$XRAY_BIN" api adu --server="$API_ADDR" -inbound="$tag" -users="$user_json" 2>&1) || { printf '%s\n' "$out" >&2; return 1; }
  if ! grep -Eqi 'Added[[:space:]]+[1-9][0-9]*[[:space:]]+user' <<< "$out"; then
    printf 'Xray API tidak mengonfirmasi penambahan pada inbound %s: %s\n' "$tag" "$out" >&2; return 1
  fi
}
api_remove_tag() {
  local tag="$1" emails_json="$2" out
  [[ "$emails_json" != '[]' ]] || return 0
  out=$("$XRAY_BIN" api rmu --server="$API_ADDR" -inbound="$tag" -users="$emails_json" 2>&1) || { printf '%s\n' "$out" >&2; return 1; }
  if ! grep -Eqi 'Removed[[:space:]]+[1-9][0-9]*[[:space:]]+user' <<< "$out"; then
    printf 'Xray API tidak mengonfirmasi penghapusan pada inbound %s: %s\n' "$tag" "$out" >&2; return 1
  fi
}

make_client_json() {
  local username="$1" credential="$2"
  if [[ "$PROTO" == trojan ]]; then
    jq -cn --arg e "$username" --arg p "$credential" '[{email:$e,password:$p}]'
  else
    jq -cn --arg e "$username" --arg id "$credential" '[{email:$e,id:$id}]'
  fi
}

make_emails_json() { jq -cn --arg e "$1" '[$e]'; }

candidate_add() {
  local username="$1" credential="$2" output="$3"
  if [[ "$PROTO" == trojan ]]; then
    jq --arg p "$PROTO" --arg u "$username" --arg c "$credential" \
      '(.inbounds[] | select(.protocol==$p) | .settings.clients) |= ((. // []) | map(select(.email != $u)) + [{"email":$u,"password":$c}])' "$CONFIG" > "$output"
  else
    jq --arg p "$PROTO" --arg u "$username" --arg c "$credential" \
      '(.inbounds[] | select(.protocol==$p) | .settings.clients) |= ((. // []) | map(select(.email != $u)) + [{"email":$u,"id":$c}])' "$CONFIG" > "$output"
  fi
}
candidate_remove() {
  local username="$1" output="$2"
  jq --arg p "$PROTO" --arg u "$username" \
    '(.inbounds[] | select(.protocol==$p) | .settings.clients) |= ((. // []) | map(select(.email != $u)))' "$CONFIG" > "$output"
}
validate_candidate() {
  local file="$1"
  jq -e --arg p "$PROTO" 'any(.inbounds[]; .protocol==$p)' "$file" >/dev/null || { echo "Inbound $PROTO tidak ditemukan." >&2; return 1; }
  "$XRAY_BIN" run -test -config "$file" >/dev/null 2>&1 || { echo "Validasi konfigurasi Xray gagal; perubahan dibatalkan." >&2; return 1; }
}

# Apply one user's runtime change to every inbound of this protocol.
# On partial failure, reverse already-applied changes before returning.
runtime_add_user() {
  local username="$1" credential="$2" tags tag json; local -a done_tags=()
  mapfile -t tags < <(protocol_tags)
  ((${#tags[@]})) || { echo "Tidak ada inbound $PROTO dengan tag." >&2; return 1; }
  json=$(make_client_json "$username" "$credential")
  for tag in "${tags[@]}"; do
    if api_add_tag "$tag" "$json"; then done_tags+=("$tag"); else
      for tag in "${done_tags[@]}"; do api_remove_tag "$tag" "$(make_emails_json "$username")" >/dev/null 2>&1 || true; done
      return 1
    fi
  done
}
runtime_remove_user() {
  local username="$1" tags tag rec old_credential; local -a done_tags=()
  rec=$(get_record "$username" 2>/dev/null || true)
  old_credential=$(awk '{print $4}' <<< "$rec")
  mapfile -t tags < <(protocol_tags)
  ((${#tags[@]})) || { echo "Tidak ada inbound $PROTO dengan tag." >&2; return 1; }
  for tag in "${tags[@]}"; do
    # Locked/deleted accounts may already be absent from this inbound.
    if ! jq -e --arg tag "$tag" --arg u "$username" '.inbounds[] | select(.tag==$tag) | any(.settings.clients[]?; .email==$u)' "$CONFIG" >/dev/null 2>&1; then
      continue
    fi
    if api_remove_tag "$tag" "$(make_emails_json "$username")"; then done_tags+=("$tag"); else
      # Reverse every successful removal to keep the old runtime state intact.
      if [[ -n "$old_credential" ]]; then
        for restore_tag in "${done_tags[@]}"; do api_add_tag "$restore_tag" "$(make_client_json "$username" "$old_credential")" >/dev/null 2>&1 || true; done
      fi
      return 1
    fi
  done
}

notify_event() {
  local event="$1" username="${2:-}" expiry="${3:-}" credential="${4:-}" details_json="${5:-[]}" links="${6:-}"
  [[ -x "$NOTIFIER" || -f "$NOTIFIER" ]] || { echo "Peringatan: notifier belum terpasang; notifikasi dilewati." >&2; return 0; }
  jq -cn --arg event "$event" --arg protocol "$PROTO" --arg username "$username" \
    --arg expiry "$expiry" --arg credential "$credential" --arg links "$links" \
    --argjson details "$details_json" \
    '{event:$event,protocol:$protocol,username:$username,expiry:$expiry,credential:$credential,links:$links,details:$details}' \
    | python3 "$NOTIFIER" || echo "Peringatan: gagal mengirim notifikasi Telegram." >&2
}

build_links() {
  local user="$1" cred="$2" host sni label
  host=$(tr -d '[:space:]' < /etc/xray/domain.txt 2>/dev/null || true)
  [[ -n "$host" ]] || host=$(hostname -I | awk '{print $1}')
  sni=$(tr -d '[:space:]' < /etc/xray/sni.txt 2>/dev/null || true); [[ -n "$sni" ]] || sni="$host"
  label="${user}-Cassanova"
  if [[ "$PROTO" == vless ]]; then
    printf 'WS TLS: vless://%s@%s:443?encryption=none&security=tls&type=ws&host=%s&path=%%2Fvless&sni=%s#%s\n' "$cred" "$host" "$sni" "$sni" "$label"
    printf 'WS Non-TLS: vless://%s@%s:80?encryption=none&security=none&type=ws&host=%s&path=%%2Fvless#%s\n' "$cred" "$host" "$sni" "$label"
    printf 'gRPC TLS: vless://%s@%s:443?encryption=none&security=tls&type=grpc&serviceName=vless-grpc&sni=%s#%s\n' "$cred" "$host" "$sni" "$label"
    printf 'HTTPUpgrade TLS: vless://%s@%s:443?encryption=none&security=tls&type=httpupgrade&host=%s&path=%%2Fupvless&sni=%s#%s\n' "$cred" "$host" "$sni" "$sni" "$label"
    printf 'XHTTP TLS: vless://%s@%s:2096?encryption=none&security=tls&type=xhttp&host=%s&path=%%2Fxhvless&sni=%s#%s\n' "$cred" "$host" "$sni" "$sni" "$label"
  elif [[ "$PROTO" == trojan ]]; then
    printf 'WS TLS: trojan://%s@%s:443?security=tls&type=ws&host=%s&path=%%2Ftrojan&sni=%s#%s\n' "$cred" "$host" "$sni" "$sni" "$label"
    printf 'WS Non-TLS: trojan://%s@%s:80?security=none&type=ws&host=%s&path=%%2Ftrojan#%s\n' "$cred" "$host" "$sni" "$label"
    printf 'gRPC TLS: trojan://%s@%s:443?security=tls&type=grpc&serviceName=trojan-grpc&sni=%s#%s\n' "$cred" "$host" "$sni" "$label"
    printf 'HTTPUpgrade TLS: trojan://%s@%s:443?security=tls&type=httpupgrade&host=%s&path=%%2Fuptrojan&sni=%s#%s\n' "$cred" "$host" "$sni" "$sni" "$label"
    printf 'XHTTP TLS: trojan://%s@%s:2096?security=tls&type=xhttp&host=%s&path=%%2Fxhtrojan&sni=%s#%s\n' "$cred" "$host" "$sni" "$sni" "$label"
  else
    local spec port net path tls b64
    for spec in '443 ws /vmess tls' '80 ws /vmess none' '443 grpc vmess-grpc tls' '443 httpupgrade /upvmess tls' '2096 xhttp /xhvmess tls'; do
      read -r port net path tls <<< "$spec"
      b64=$(jq -cn --arg ps "$label-$net-$port" --arg add "$host" --arg id "$cred" --arg h "$sni" --arg p "$path" --arg n "$net" --arg t "$tls" --arg port "$port" '{v:"2",ps:$ps,add:$add,port:$port,id:$id,aid:"0",scy:"auto",net:$n,type:"none",host:$h,path:$p,tls:$t,sni:$h}' | base64 -w0)
      printf '%s %s: vmess://%s\n' "$net" "$tls" "$b64"
    done
  fi
}

commit_config_db() {
  local cfg="$1" db="$2" old_cfg old_db
  old_cfg=$(mktemp); old_db=$(mktemp)
  cp -a "$CONFIG" "$old_cfg"; cp -a "$DB_FILE" "$old_db"
  if ! atomic_install "$cfg" "$CONFIG" 0600 root:root || ! atomic_install "$db" "$DB_FILE" 0600 root:root; then
    atomic_install "$old_cfg" "$CONFIG" 0600 root:root || true
    atomic_install "$old_db" "$DB_FILE" 0600 root:root || true
    rm -f "$old_cfg" "$old_db"
    echo "Commit konfigurasi/database gagal; file lama dipulihkan." >&2
    return 1
  fi
  rm -f "$old_cfg" "$old_db"
}

write_db_replace() {
  local username="$1" expiry="$2" credential="$3" status="$4" out="$5"
  awk -v u="$username" -v e="$expiry" -v c="$credential" -v s="$status" \
    '$1=="###" && $2==u {$0="### " u " " e " " c " " s; found=1} {print} END {if(!found) exit 3}' "$DB_FILE" > "$out"
}
write_db_delete() {
  local username="$1" out="$2"
  awk -v u="$username" '$1=="###" && $2==u {found=1; next} {print} END {if(!found) exit 3}' "$DB_FILE" > "$out"
}

api_enable() {
  local tmp
  if api_configured && jq -e '((.api.services // []) | index("StatsService") != null) and (.policy.levels["0"].statsUserUplink == true) and (.policy.levels["0"].statsUserDownlink == true)' "$CONFIG" >/dev/null 2>&1; then
    if ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Fq "$API_ADDR"; then
      echo "Xray HandlerService dan StatsService sudah aktif melalui API loopback $API_ADDR."; exit 0
    fi
  fi
  tmp=$(mktemp "${CONFIG}.api.XXXXXX")
  jq '
    .api = ((.api // {}) + {tag:"api",services:(((.api.services // []) + ["HandlerService","StatsService"]) | unique)})
    | .stats = (.stats // {})
    | .policy = ((.policy // {}) + {levels:((.policy.levels // {}) + {"0":((.policy.levels["0"] // {}) + {statsUserUplink:true,statsUserDownlink:true})})})
    | .inbounds = ([ (.inbounds // [])[] | select(.tag != "api-in") ] + [{tag:"api-in",listen:"127.0.0.1",port:10085,protocol:"dokodemo-door",settings:{address:"127.0.0.1"}}])
    | .outbounds = ([ (.outbounds // [])[] | select(.tag != "api") ] + [{protocol:"freedom",tag:"api"}])
    | .routing = ((.routing // {}) + {rules:([ {type:"field",inboundTag:["api-in"],outboundTag:"api"} ] + [(.routing.rules // [])[] | select(((.inboundTag // []) | index("api-in")) == null)])})
  ' "$CONFIG" > "$tmp"
  if ! "$XRAY_BIN" run -test -config "$tmp" >/dev/null 2>&1; then rm -f "$tmp"; echo "Validasi konfigurasi API/StatsService gagal." >&2; exit 1; fi
  backup_state
  atomic_install "$tmp" "$CONFIG" 0600 root:root; rm -f "$tmp"
  echo "Mengaktifkan Xray HandlerService + StatsService pada 127.0.0.1:10085. Diperlukan satu kali restart Xray untuk aktivasi/perbaikan API awal."
  if ! systemctl restart xray || ! systemctl is-active --quiet xray; then
    echo "Xray gagal setelah API diaktifkan. Mengembalikan config sebelumnya." >&2
    local latest; latest=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'config-*.json' -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-)
    [[ -n "$latest" ]] && install -o root -g root -m 0600 "$latest" "$CONFIG"
    systemctl restart xray >/dev/null 2>&1 || true
    exit 1
  fi
  sleep 1
  if ! ss -ltnH | awk '{print $4}' | grep -Fq "$API_ADDR"; then
    echo "Xray aktif tetapi API belum mendengarkan di $API_ADDR. Periksa journalctl -u xray." >&2; exit 1
  fi
  systemctl enable --now cassanova-bandwidth.timer >/dev/null 2>&1 || true
  echo "API aktif di loopback. CRUD akun dan bandwidth polling tidak perlu restart Xray."
}

case "$ACTION" in
 api-enable) api_enable; exit 0 ;;
 check-config) "$XRAY_BIN" run -test -config "$CONFIG" && echo "Konfigurasi Xray valid."; exit $? ;;
 list|cek-login) list_records; exit 0 ;;
 recovery)
  api_enabled || { echo "Xray API belum aktif. Jalankan sekali: xray-manager $PROTO api-enable (akan restart Xray satu kali untuk aktivasi awal)." >&2; exit 1; }
  mapfile -t TAGS < <(protocol_tags); ((${#TAGS[@]})) || { echo "Inbound $PROTO tidak ditemukan." >&2; exit 1; }
  TMP_CFG=$(mktemp); TMP_DB=$(mktemp); cp "$DB_FILE" "$TMP_DB"
  TODAY=$(date +%F)
  if [[ "$PROTO" == trojan ]]; then
    jq --arg p "$PROTO" --arg today "$TODAY" --rawfile db "$DB_FILE" '
      ($db | split("\n") | map(select(startswith("### "))) | map(split(" ")) | map(select(.[4] != "locked" and .[2] >= $today)) | map({email:.[1],password:.[3]})) as $clients
      | (.inbounds[] | select(.protocol==$p) | .settings.clients) = $clients' "$CONFIG" > "$TMP_CFG"
  else
    jq --arg p "$PROTO" --arg today "$TODAY" --rawfile db "$DB_FILE" '
      ($db | split("\n") | map(select(startswith("### "))) | map(split(" ")) | map(select(.[4] != "locked" and .[2] >= $today)) | map({email:.[1],id:.[3]})) as $clients
      | (.inbounds[] | select(.protocol==$p) | .settings.clients) = $clients' "$CONFIG" > "$TMP_CFG"
  fi
  validate_candidate "$TMP_CFG"
  # Reconcile runtime inbound-by-inbound: remove current manager-owned users, then add DB-active users.
  RECOVERY_OLD="$CONFIG"; RECOVERY_DONE=()
  for tag in "${TAGS[@]}"; do
    OLD_EMAILS=$(jq -c --arg tag "$tag" '.inbounds[] | select(.tag==$tag) | [.settings.clients[]?.email // empty]' "$CONFIG")
    [[ -n "$OLD_EMAILS" && "$OLD_EMAILS" != 'null' ]] || OLD_EMAILS='[]'
    if [[ "$OLD_EMAILS" != '[]' ]]; then
      if ! api_remove_tag "$tag" "$OLD_EMAILS"; then
        for restore_tag in "${RECOVERY_DONE[@]}"; do OLD_USERS=$(jq -c --arg tag "$restore_tag" '.inbounds[] | select(.tag==$tag) | .settings.clients // []' "$CONFIG"); [[ "$OLD_USERS" == '[]' ]] || api_add_tag "$restore_tag" "$OLD_USERS" >/dev/null 2>&1 || true; done
        echo "Recovery gagal saat menghapus client lama pada $tag." >&2; rm -f "$TMP_CFG" "$TMP_DB"; exit 1
      fi
    fi
    NEW_USERS=$(jq -c --arg tag "$tag" '.inbounds[] | select(.tag==$tag) | .settings.clients // []' "$TMP_CFG")
    if [[ "$NEW_USERS" != '[]' ]]; then
      if ! api_add_tag "$tag" "$NEW_USERS"; then
        # Restore runtime users from the still-current on-disk configuration.
        [[ "$OLD_EMAILS" == '[]' ]] || api_add_tag "$tag" "$(jq -c --arg tag "$tag" '.inbounds[] | select(.tag==$tag) | .settings.clients // []' "$CONFIG")" >/dev/null 2>&1 || true
        for restore_tag in "${RECOVERY_DONE[@]}"; do OLD_USERS=$(jq -c --arg tag "$restore_tag" '.inbounds[] | select(.tag==$tag) | .settings.clients // []' "$CONFIG"); [[ "$OLD_USERS" == '[]' ]] || api_add_tag "$restore_tag" "$OLD_USERS" >/dev/null 2>&1 || true; done
        rm -f "$TMP_CFG" "$TMP_DB"; echo "Recovery gagal saat menambahkan akun ke $tag." >&2; exit 1
      fi
    fi
    RECOVERY_DONE+=("$tag")
  done
  backup_state
  if ! atomic_install "$TMP_CFG" "$CONFIG" 0600 root:root; then
    for tag in "${TAGS[@]}"; do
      api_remove_tag "$tag" "$(jq -c --arg tag "$tag" '.inbounds[] | select(.tag==$tag) | [.settings.clients[]?.email // empty]' "$TMP_CFG")" >/dev/null 2>&1 || true
      OLD_USERS=$(jq -c --arg tag "$tag" '.inbounds[] | select(.tag==$tag) | .settings.clients // []' "$CONFIG")
      [[ "$OLD_USERS" == '[]' ]] || api_add_tag "$tag" "$OLD_USERS" >/dev/null 2>&1 || true
    done
    rm -f "$TMP_CFG" "$TMP_DB"; echo "Recovery gagal menyimpan konfigurasi; runtime lama dipulihkan sebisa mungkin." >&2; exit 1
  fi
  rm -f "$TMP_CFG" "$TMP_DB"
  DETAILS=$(awk -v d="$(date +%F)" '$1=="###" && $5!="locked" && $3>=d {printf "%s|%s|%s\n",$2,$3,$4}' "$DB_FILE" | jq -Rsc 'split("\n") | map(select(length>0) | split("|") | {username:.[0],expiry:.[1],credential:.[2]})')
  COUNT=$(jq 'length' <<< "$DETAILS")
  echo "Recovery $PROTO selesai: $COUNT akun aktif disinkronkan tanpa restart Xray."
  notify_event recovery "" "" "" "$DETAILS"
  ;;
 expire)
  api_enabled || { echo "Xray API belum aktif; expire otomatis tidak dijalankan." >&2; exit 1; }
  TODAY=$(date +%F); mapfile -t EXPIRED_USERS < <(awk -v d="$TODAY" '$1=="###" && $3<d && $5!="locked" {print $2}' "$DB_FILE")
  for U in "${EXPIRED_USERS[@]}"; do
    DATA=$(get_record "$U") || continue; read -r _ _ E C ST <<< "$DATA"
    runtime_remove_user "$U"
    CFG_TMP=$(mktemp); DB_TMP=$(mktemp); candidate_remove "$U" "$CFG_TMP"; write_db_replace "$U" "$E" "$C" locked "$DB_TMP"
    validate_candidate "$CFG_TMP"; backup_state
    if ! commit_config_db "$CFG_TMP" "$DB_TMP"; then runtime_add_user "$U" "$C" >/dev/null 2>&1 || true; rm -f "$CFG_TMP" "$DB_TMP"; echo "Gagal commit akun expired $U." >&2; exit 1; fi
    rm -f "$CFG_TMP" "$DB_TMP"
    notify_event expired "$U" "$E" "$C"
  done
  echo "Pembersihan akun kedaluwarsa selesai: ${#EXPIRED_USERS[@]} akun." ;;
 create|custom)
  api_enabled || { echo "Xray API belum aktif. Jalankan sekali: xray-manager $PROTO api-enable (akan restart Xray satu kali untuk aktivasi awal)." >&2; exit 1; }
  read -rp "Username (1-32 karakter): " U; U="${U//[[:space:]]/}"
  valid_user "$U" || { echo "Username tidak valid."; exit 1; }
  if get_record "$U" >/dev/null 2>&1; then echo "Username sudah terdaftar pada protokol $PROTO."; exit 1; fi
  for other_db in /etc/xray/vless.db /etc/xray/vmess.db /etc/xray/trojan.db; do
    [[ -f "$other_db" ]] || continue
    if awk -v u="$U" '$1=="###" && $2==u {found=1} END {exit !found}' "$other_db"; then
      echo "Username sudah digunakan pada salah satu protokol Xray. Gunakan username global yang unik agar statistik bandwidth tidak tercampur." >&2; exit 1
    fi
  done
  if [[ "$ACTION" == custom ]]; then read -rsp "UUID/Password: " C; echo
  elif [[ "$PROTO" == trojan ]]; then C=$(openssl rand -hex 16)
  else C=$(cat /proc/sys/kernel/random/uuid); fi
  if [[ "$PROTO" == trojan ]]; then [[ "$C" =~ ^[A-Za-z0-9._-]{8,128}$ ]] || { echo "Password Trojan harus 8-128 karakter."; exit 1; }
  else valid_uuid "$C" || { echo "Credential harus UUID valid."; exit 1; }; fi
  read -rp "Masa aktif (hari): " D; valid_days "$D" || { echo "Jumlah hari tidak valid."; exit 1; }
  echo "Catatan: enforcement limit IP per akun belum tersedia untuk Xray; nilai IP akan diset 0 (unlimited)."
  LIM=0
  read -rp "Limit bandwidth GB (0=unlimited, dihitung per akun): " BW; BW="${BW:-0}"
  valid_number "$BW" || { echo "Limit bandwidth harus angka non-negatif."; exit 1; }
  if (( BW > 0 )) && ! stats_enabled; then echo "StatsService belum aktif. Jalankan: xray-manager $PROTO api-enable (aktivasi awal membutuhkan satu restart Xray)." >&2; exit 1; fi
  E=$(date -d "+${D} days" +%Y-%m-%d); CFG_TMP=$(mktemp); DB_TMP=$(mktemp)
  candidate_add "$U" "$C" "$CFG_TMP"; validate_candidate "$CFG_TMP"
  clear_bw_usage "$U"
  LINKS=$(build_links "$U" "$C")
  runtime_add_user "$U" "$C"
  printf '### %s %s %s unlocked\n' "$U" "$E" "$C" > "$DB_TMP"
  cat "$DB_FILE" >> "$DB_TMP"
  backup_state
  if ! commit_config_db "$CFG_TMP" "$DB_TMP"; then runtime_remove_user "$U" >/dev/null 2>&1 || true; rm -f "$CFG_TMP" "$DB_TMP"; exit 1; fi
  printf '%s\n' "$LIM" > "${LIMIT_IP_DIR}/${PROTO}_${U}"; printf '%s\n' "$BW" > "${LIMIT_BW_DIR}/${PROTO}_${U}"
  rm -f "$CFG_TMP" "$DB_TMP"
  echo "Akun $PROTO/$U berhasil dibuat tanpa restart Xray. Expired: $E"; printf '%s\n' "$LINKS"
  notify_event create "$U" "$E" "$C" '[]' "$LINKS"
  ;;
 delete)
  api_enabled || { echo "Xray API belum aktif. Jalankan sekali: xray-manager $PROTO api-enable." >&2; exit 1; }
  list_records; read -rp "Username yang dihapus: " U; valid_user "$U" || exit 1
  DATA=$(get_record "$U") || { echo "Akun tidak ditemukan."; exit 1; }; read -r _ _ E C ST <<< "$DATA"
  CFG_TMP=$(mktemp); DB_TMP=$(mktemp); candidate_remove "$U" "$CFG_TMP"; write_db_delete "$U" "$DB_TMP"; validate_candidate "$CFG_TMP"
  runtime_remove_user "$U"
  backup_state
  if ! commit_config_db "$CFG_TMP" "$DB_TMP"; then
    runtime_add_user "$U" "$C" >/dev/null 2>&1 || true; echo "Gagal menyimpan perubahan; akun runtime dipulihkan sebisa mungkin." >&2; rm -f "$CFG_TMP" "$DB_TMP"; exit 1
  fi
  rm -f "$LIMIT_IP_DIR/${PROTO}_${U}" "$LIMIT_BW_DIR/${PROTO}_${U}" "$CFG_TMP" "$DB_TMP"
  clear_bw_usage "$U"
  echo "Akun $PROTO/$U dihapus tanpa restart Xray."; notify_event delete "$U" "$E" "$C"
  ;;
 renew)
  list_records; read -rp "Username: " U; valid_user "$U" || exit 1
  DATA=$(get_record "$U") || { echo "Akun tidak ditemukan."; exit 1; }; read -r _ _ E C ST <<< "$DATA"
  read -rp "Tambah hari: " D; valid_days "$D" || { echo "Jumlah hari tidak valid."; exit 1; }
  NOW=$(date +%s); EXP=$(date -d "$E" +%s 2>/dev/null || echo 0); (( EXP < NOW )) && EXP=$NOW
  NE=$(date -d "@$((EXP + D*86400))" +%Y-%m-%d); DB_TMP=$(mktemp)
  if [[ "$ST" == locked ]]; then
    CFG_TMP=$(mktemp); candidate_add "$U" "$C" "$CFG_TMP"; validate_candidate "$CFG_TMP"
    api_enabled || { rm -f "$CFG_TMP"; echo "Xray API belum aktif." >&2; exit 1; }
    runtime_add_user "$U" "$C"
    write_db_replace "$U" "$NE" "$C" unlocked "$DB_TMP"
    backup_state
    if ! commit_config_db "$CFG_TMP" "$DB_TMP"; then runtime_remove_user "$U" >/dev/null 2>&1 || true; rm -f "$CFG_TMP" "$DB_TMP"; exit 1; fi
    rm -f "$CFG_TMP"
  else
    write_db_replace "$U" "$NE" "$C" "$ST" "$DB_TMP"; backup_state; atomic_install "$DB_TMP" "$DB_FILE" 0600 root:root
  fi
  rm -f "$DB_TMP"
  LINKS=$(build_links "$U" "$C")
  echo "Masa aktif $PROTO/$U diperbarui sampai $NE. Tidak ada restart Xray."; notify_event renew "$U" "$NE" "$C" '[]' "$LINKS"
  ;;
 modify)
  api_enabled || { echo "Xray API belum aktif. Jalankan sekali: xray-manager $PROTO api-enable." >&2; exit 1; }
  list_records; read -rp "Username: " U; DATA=$(get_record "$U") || { echo "Akun tidak ditemukan."; exit 1; }; read -r _ _ E OLD ST <<< "$DATA"
  read -rsp "Credential baru: " C; echo
  if [[ "$PROTO" == trojan ]]; then [[ "$C" =~ ^[A-Za-z0-9._-]{8,128}$ ]] || exit 1; else valid_uuid "$C" || { echo "UUID tidak valid."; exit 1; }; fi
  CFG_TMP=$(mktemp); DB_TMP=$(mktemp); candidate_add "$U" "$C" "$CFG_TMP"; validate_candidate "$CFG_TMP"; write_db_replace "$U" "$E" "$C" "$ST" "$DB_TMP"
  runtime_remove_user "$U" || { rm -f "$CFG_TMP" "$DB_TMP"; exit 1; }; runtime_add_user "$U" "$C" || { runtime_remove_user "$U" >/dev/null 2>&1 || true; runtime_add_user "$U" "$OLD" >/dev/null 2>&1 || true; rm -f "$CFG_TMP" "$DB_TMP"; exit 1; }
  backup_state
  if ! commit_config_db "$CFG_TMP" "$DB_TMP"; then runtime_remove_user "$U" >/dev/null 2>&1 || true; runtime_add_user "$U" "$OLD" >/dev/null 2>&1 || true; rm -f "$CFG_TMP" "$DB_TMP"; exit 1; fi
  rm -f "$CFG_TMP" "$DB_TMP"
  LINKS=$(build_links "$U" "$C"); echo "Credential diperbarui tanpa restart Xray."; printf '%s\n' "$LINKS"; notify_event modify "$U" "$E" "$C" '[]' "$LINKS"
  ;;
 lock|unlock)
  api_enabled || { echo "Xray API belum aktif. Jalankan sekali: xray-manager $PROTO api-enable." >&2; exit 1; }
  list_records; read -rp "Username: " U; DATA=$(get_record "$U") || { echo "Akun tidak ditemukan."; exit 1; }; read -r _ _ E C ST <<< "$DATA"
  CFG_TMP=$(mktemp); DB_TMP=$(mktemp)
  if [[ "$ACTION" == lock ]]; then candidate_remove "$U" "$CFG_TMP"; NEWST=locked; runtime_remove_user "$U"
  else candidate_add "$U" "$C" "$CFG_TMP"; NEWST=unlocked; runtime_add_user "$U" "$C"; fi
  validate_candidate "$CFG_TMP"; write_db_replace "$U" "$E" "$C" "$NEWST" "$DB_TMP"; backup_state
  if ! commit_config_db "$CFG_TMP" "$DB_TMP"; then
    if [[ "$ACTION" == lock ]]; then runtime_add_user "$U" "$C" >/dev/null 2>&1 || true; else runtime_remove_user "$U" >/dev/null 2>&1 || true; fi
    rm -f "$CFG_TMP" "$DB_TMP"; exit 1
  fi
  rm -f "$CFG_TMP" "$DB_TMP"
  echo "Akun $U $NEWST tanpa restart Xray."; notify_event "$ACTION" "$U" "$E" "$C"
  ;;
 limit-ip|limit-bw)
  read -rp "Username: " U; get_record "$U" >/dev/null || { echo "Akun tidak ditemukan."; exit 1; }
  read -rp "Nilai (0=unlimited): " V; valid_number "$V" || { echo "Nilai tidak valid."; exit 1; }
  if [[ "$ACTION" == limit-ip ]]; then
    (( V == 0 )) || { echo "Limit IP per akun belum didukung secara andal oleh Xray Core. Nilai non-zero ditolak agar tidak memberi kesan limit aktif." >&2; exit 2; }
    printf '0\n' > "${LIMIT_IP_DIR}/${PROTO}_${U}"
    echo "Limit IP diset unlimited. Enforcement per-IP belum didukung."
  else
    if (( V > 0 )) && ! stats_enabled; then echo "StatsService belum aktif. Jalankan: xray-manager $PROTO api-enable." >&2; exit 1; fi
    printf '%s\n' "$V" > "${LIMIT_BW_DIR}/${PROTO}_${U}"
    if (( V > 0 )); then systemctl enable --now cassanova-bandwidth.timer >/dev/null 2>&1 || echo "Peringatan: timer bandwidth belum aktif; periksa unit cassanova-bandwidth.timer." >&2; fi
    echo "Limit bandwidth $V GB disimpan. Pemeriksaan berjalan sekitar setiap 60 detik; sedikit overshoot mungkin terjadi."
  fi ;;
 limit-reset)
  read -rp "Username: " U; get_record "$U" >/dev/null || { echo "Akun tidak ditemukan."; exit 1; }
  stats_enabled || { echo "StatsService belum aktif. Jalankan xray-manager $PROTO api-enable." >&2; exit 1; }
  "$XRAY_BIN" api statsquery "--server=$API_ADDR" "-pattern=user>>>${U}>>>traffic>>>" -reset=true >/dev/null 2>&1 || { echo "Gagal mereset counter Xray." >&2; exit 1; }
  install -d -m 0700 /var/lib/cassanova
  STATE_FILE=/var/lib/cassanova/bandwidth-xray.json; STATE_TMP=$(mktemp)
  if [[ -s "$STATE_FILE" ]]; then jq --arg key "$PROTO:$U" 'del(.[$key])' "$STATE_FILE" > "$STATE_TMP"; else printf '{}\n' > "$STATE_TMP"; fi
  atomic_install "$STATE_TMP" "$STATE_FILE" 0600 root:root; rm -f "$STATE_TMP"
  echo "Pemakaian bandwidth $PROTO/$U direset ke 0 GB." ;;

 *) echo "Usage: xray-manager {vless|vmess|trojan} {create|custom|delete|renew|modify|check-config|list|cek-login|lock|unlock|limit-ip|limit-bw|limit-reset|recovery|expire|api-enable}"; exit 2 ;;
esac
