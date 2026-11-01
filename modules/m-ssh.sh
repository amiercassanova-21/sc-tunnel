#!/usr/bin/env bash
# SC Cassanova Tunneling - SSH account manager
set -Eeuo pipefail
umask 077

DB_FILE="/etc/ssh/.ssh.db"
NOTIFIER="/usr/local/bin/cassanova-notify.py"
LOCK_FILE="/run/lock/sc-tunnel-ssh.lock"
NC='\033[0m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; CYAN='\033[1;36m'; BLUE='\033[1;34m'

fail() { printf "${RED}ERROR:${NC} %s\n" "$*" >&2; }
ok() { printf "${GREEN}%s${NC}\n" "$*"; }
info() { printf "${YELLOW}%s${NC}\n" "$*"; }

if (( EUID != 0 )); then fail 'Jalankan menu SSH sebagai root.'; exit 1; fi
for cmd in useradd userdel chage passwd chpasswd flock awk date getent jq python3; do
  command -v "$cmd" >/dev/null 2>&1 || { fail "Perintah wajib tidak ditemukan: $cmd"; exit 1; }
done
install -d -m 0700 /etc/ssh
[[ -e "$DB_FILE" ]] || install -m 0600 /dev/null "$DB_FILE"
chmod 0600 "$DB_FILE"
exec 9>"$LOCK_FILE"
flock -x 9

valid_user() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; }
valid_days() { [[ "$1" =~ ^[1-9][0-9]{0,3}$ ]] && (( $1 <= 3650 )); }

# Normalize old records (### user YYYY-MM-DD [legacy-password] [status])
# Passwords from legacy files are deliberately discarded: never keep plaintext credentials.
migrate_db() {
  local tmp line user expiry status
  tmp=$(mktemp)
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^###\  ]] || continue
    read -r _ user expiry fourth fifth <<< "$line"
    valid_user "$user" || continue
    [[ "$expiry" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || continue
    # Legacy format had password in column 4 and optional status in column 5.
    # New format stores status in column 4 and never stores a password.
    status=unlocked
    if [[ "$fourth" == locked || "$fifth" == locked ]]; then status=locked; fi
    if [[ "$fourth" == expired || "$fifth" == expired ]]; then status=expired; fi
    printf '### %s %s %s\n' "$user" "$expiry" "$status" >> "$tmp"
  done < "$DB_FILE"
  install -m 0600 "$tmp" "$DB_FILE"
  rm -f "$tmp"
}
migrate_db

find_record() { awk -v u="$1" '$1=="###" && $2==u {print $0; exit}' "$DB_FILE"; }
record_set() {
  local user="$1" expiry="$2" status="$3" tmp
  tmp=$(mktemp)
  awk -v u="$user" '$1=="###" && $2==u {next} {print}' "$DB_FILE" > "$tmp"
  printf '### %s %s %s\n' "$user" "$expiry" "$status" >> "$tmp"
  install -m 0600 "$tmp" "$DB_FILE"; rm -f "$tmp"
}
record_remove() {
  local user="$1" tmp
  tmp=$(mktemp)
  awk -v u="$user" '!($1=="###" && $2==u)' "$DB_FILE" > "$tmp"
  install -m 0600 "$tmp" "$DB_FILE"; rm -f "$tmp"
}
notify_event() {
  local event="$1" user="${2:-}" expiry="${3:-}" credential="${4:-}" details="${5:-[]}"
  local domain ip context
  [[ -f "$NOTIFIER" ]] || { info 'Telegram notifier belum terpasang; notifikasi dilewati.'; return 0; }
  domain=$(tr -d '[:space:]' < /etc/xray/domain.txt 2>/dev/null || true)
  [[ -n "$domain" ]] || domain=$(hostname -f 2>/dev/null || hostname)
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  context="SSH port 22 | Domain: ${domain:-tidak diketahui} | IP: ${ip:-tidak diketahui} | Mode: OpenSSH"
  jq -cn --arg event "$event" --arg protocol SSH --arg username "$user" \
    --arg expiry "$expiry" --arg credential "$credential" --arg context "$context" \
    --argjson details "$details" \
    '{event:$event,protocol:$protocol,username:$username,expiry:$expiry,credential:$credential,context:$context,details:$details}' \
    | python3 "$NOTIFIER" || info 'Gagal mengirim notifikasi Telegram; operasi akun tetap berhasil.'
}
choose_user() {
  local input
  read -rp 'Username atau nomor: ' input
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    awk '$1=="###" {n++; if(n==ARGV[1]) print $2}' "$input" "$DB_FILE" 2>/dev/null
  else printf '%s' "$input"; fi
}
list_users() {
  printf '\n%-4s %-18s %-14s %-12s %-10s\n' 'NO' 'USERNAME' 'EXPIRED' 'ACCOUNT' 'STATUS'
  local n=0 user expiry status account
  while read -r _ user expiry status; do
    [[ -n "${user:-}" ]] || continue
    n=$((n+1)); account='MISSING'
    if getent passwd "$user" >/dev/null; then
      account=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
      [[ "$account" == L || "$account" == LK ]] && account='LOCKED'
      [[ "$account" == P ]] && account='ACTIVE'
    fi
    printf '%-4s %-18s %-14s %-12s %-10s\n' "$n" "$user" "$expiry" "$account" "$status"
  done < <(grep '^### ' "$DB_FILE" || true)
  printf '\n'
}
show_details() {
  local user="$1" expiry="$2" ip domain
  ip=$(curl -4fsS --connect-timeout 2 --max-time 4 https://api.ipify.org 2>/dev/null || printf 'Tidak diketahui')
  domain=$(cat /etc/xray/domain.txt 2>/dev/null || printf 'Belum diatur')
  printf '\n${CYAN}Akun SSH dibuat${NC}\nUsername : %s\nPassword : (gunakan password yang baru Anda masukkan)\nIP       : %s\nDomain   : %s\nPort SSH : 22\nExpired  : %s\n\n' "$user" "$ip" "$domain" "$expiry"
}

while true; do
  clear 2>/dev/null || true
  printf "${BLUE}════════════ SC CASSANOVA | SSH MANAGER ════════════${NC}\n"
  printf ' 1. Buat akun SSH          6. Ubah password\n'
  printf ' 2. Buat akun trial 1 hari 7. Kunci akun\n'
  printf ' 3. Hapus akun             8. Buka kunci akun\n'
  printf ' 4. Perpanjang akun        9. Daftar akun\n'
  printf ' 5. Cek akun               10. Login aktif\n'
  printf '11. Recovery / sinkronisasi akun\n'
  printf ' 0. Kembali\n'
  read -rp 'Pilih menu: ' choice
  case "$choice" in
    1|2)
      if [[ "$choice" == 2 ]]; then
        user="trial$(date +%s | tail -c 6)"; days=1
        while getent passwd "$user" >/dev/null; do user="trial${RANDOM}"; done
        password=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')
      else
        read -rp 'Username: ' user
        valid_user "$user" || { fail 'Username tidak valid (huruf kecil, angka, _ atau -; maksimal 32 karakter).'; read -rp 'Enter untuk lanjut...'; continue; }
        read -rsp 'Password (minimal 8 karakter): ' password; printf '\n'
        [[ ${#password} -ge 8 && "$password" != *:* && "$password" != *$'\n'* ]] || { fail 'Password minimal 8 karakter dan tidak boleh mengandung titik dua.'; read -rp 'Enter untuk lanjut...'; continue; }
        read -rp 'Masa aktif (hari, 1-3650): ' days
        valid_days "$days" || { fail 'Jumlah hari tidak valid.'; read -rp 'Enter untuk lanjut...'; continue; }
      fi
      if getent passwd "$user" >/dev/null || [[ -n "$(find_record "$user")" ]]; then fail 'Username sudah digunakan.'; read -rp 'Enter...'; continue; fi
      expiry=$(date -d "+${days} days" +%F)
      if ! useradd -M -s /usr/sbin/nologin -e "$expiry" "$user"; then fail 'Gagal membuat akun sistem.'; read -rp 'Enter...'; continue; fi
      if ! printf '%s:%s\n' "$user" "$password" | chpasswd; then userdel "$user"; fail 'Gagal menetapkan password.'; read -rp 'Enter...'; continue; fi
      record_set "$user" "$expiry" unlocked
      printf '\n'; ok 'Akun berhasil dibuat.'; printf 'Username: %s\nPassword: %s\nExpired : %s\n' "$user" "$password" "$expiry"
      notify_event create "$user" "$expiry" "$password"
      ;;
    3)
      list_users; read -rp 'Username yang akan dihapus: ' user
      if ! valid_user "$user" || [[ -z "$(find_record "$user")" ]]; then fail 'Akun tidak ditemukan di database SC.'
      else
        expiry=$(awk '{print $3}' <<< "$(find_record "$user")")
        if userdel "$user" 2>/dev/null; then record_remove "$user"; ok 'Akun dihapus.'; notify_event delete "$user" "$expiry"; else fail 'Gagal menghapus akun Linux; metadata tidak diubah.'; fi
      fi
      ;;
    4)
      list_users; read -rp 'Username: ' user; rec=$(find_record "$user")
      if [[ -z "$rec" ]] || ! getent passwd "$user" >/dev/null; then fail 'Akun tidak ditemukan.'; else
        read -rp 'Tambahan hari (1-3650): ' days
        if valid_days "$days"; then
          old_exp=$(awk '{print $3}' <<< "$rec"); now=$(date +%s); old_ts=$(date -d "$old_exp" +%s 2>/dev/null || echo 0)
          (( old_ts < now )) && base=$now || base=$old_ts
          expiry=$(date -d "@$((base + days*86400))" +%F)
          old_status=$(awk '{print $4}' <<< "$rec")
          if chage -E "$expiry" "$user"; then
            if [[ "$old_status" == expired ]]; then passwd -u "$user" >/dev/null 2>&1 || true; old_status=unlocked; fi
            record_set "$user" "$expiry" "$old_status"; ok "Masa aktif diperbarui sampai $expiry."; notify_event renew "$user" "$expiry"
          else fail 'Gagal memperbarui expiry Linux.'; fi
        else fail 'Jumlah hari tidak valid.'; fi
      fi
      ;;
    5)
      list_users; read -rp 'Username untuk diperiksa: ' user; rec=$(find_record "$user")
      if [[ -z "$rec" ]]; then fail 'Tidak tercatat di database SC.'; else
        expiry=$(awk '{print $3}' <<< "$rec"); chage -l "$user" 2>/dev/null || true
        printf 'Status metadata: %s\n' "$(awk '{print $4}' <<< "$rec")"
        printf 'Status akun: '; passwd -S "$user" 2>/dev/null || true
        printf 'Tanggal kedaluwarsa metadata: %s\n' "$expiry"
      fi
      ;;
    6)
      read -rp 'Username: ' user
      if [[ -z "$(find_record "$user")" ]]; then fail 'Akun tidak ditemukan.'; else
        read -rsp 'Password baru (minimal 8 karakter): ' password; printf '\n'
        if [[ ${#password} -ge 8 && "$password" != *:* ]]; then if printf '%s:%s\n' "$user" "$password" | chpasswd; then ok 'Password berhasil diubah.'; rec=$(find_record "$user"); notify_event modify "$user" "$(awk '{print $3}' <<< "$rec")" "$password"; else fail 'Gagal mengubah password.'; fi; else fail 'Password tidak valid.'; fi
      fi
      ;;
    7|8)
      read -rp 'Username: ' user; rec=$(find_record "$user")
      if [[ -z "$rec" ]] || ! getent passwd "$user" >/dev/null; then fail 'Akun tidak ditemukan.'; else
        expiry=$(awk '{print $3}' <<< "$rec")
        if [[ "$choice" == 7 ]]; then if passwd -l "$user" >/dev/null; then record_set "$user" "$expiry" locked; ok 'Akun dikunci.'; notify_event lock "$user" "$expiry"; else fail 'Gagal mengunci akun.'; fi
        else if passwd -u "$user" >/dev/null; then record_set "$user" "$expiry" unlocked; ok 'Akun dibuka.'; notify_event unlock "$user" "$expiry"; else fail 'Gagal membuka kunci akun.'; fi; fi
      fi
      ;;
    9) list_users ;;
    10)
      printf '\nLogin SSH aktif:\n'
      if command -v who >/dev/null; then who; else info 'Perintah who tidak tersedia.'; fi
      printf '\nProses SSH per pengguna:\n'
      ps -eo user,pid,args | awk '/sshd: [^ ]+@/ && !/awk/ {print}' || true
      ;;
    11)
      printf '\nRecovery SSH hanya menyinkronkan metadata ke akun Linux yang MASIH ADA.\n'
      printf 'Password lama tidak disimpan, jadi akun yang hilang tidak dapat dibuat ulang otomatis.\n'
      read -rp 'Lanjutkan recovery? (ketik YA): ' confirm
      if [[ "$confirm" == YA ]]; then
        details_tmp=$(mktemp); recovered=0; missing=0; failed=0
        while read -r marker ru rexp rstatus; do
          [[ "$marker" == '###' && -n "$ru" ]] || continue
          if getent passwd "$ru" >/dev/null; then
            if chage -E "$rexp" "$ru"; then
              if [[ "$rstatus" == locked || "$rstatus" == expired ]]; then passwd -l "$ru" >/dev/null 2>&1 || { failed=$((failed+1)); continue; }
              else passwd -u "$ru" >/dev/null 2>&1 || true; fi
              recovered=$((recovered+1))
              jq -cn --arg username "$ru" --arg expiry "$rexp" --arg status "$rstatus" '{username:$username,expiry:$expiry,status:$status}' >> "$details_tmp"
            else failed=$((failed+1)); fi
          else missing=$((missing+1)); fi
        done < <(grep '^### ' "$DB_FILE" || true)
        details=$(jq -s '.' "$details_tmp"); rm -f "$details_tmp"
        printf 'Recovery selesai. Sinkron: %s | Hilang: %s | Gagal: %s\n' "$recovered" "$missing" "$failed"
        notify_event recovery '' '' '' "$details"
      else info 'Recovery dibatalkan.'; fi
      ;;
    0) exit 0 ;;
    *) fail 'Pilihan tidak dikenal.' ;;
  esac
  printf '\n'; read -rp 'Tekan Enter untuk kembali ke menu...'
done
