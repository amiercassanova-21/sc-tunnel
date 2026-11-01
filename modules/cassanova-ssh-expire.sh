#!/usr/bin/env bash
# Daily SSH expiry enforcement; does not restart or reload sshd.
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }
DB=${CASSANOVA_SSH_DB:-/etc/ssh/.ssh.db}
LOCK=${CASSANOVA_SSH_LOCK:-/run/lock/sc-tunnel-ssh.lock}
NOTIFIER=${CASSANOVA_NOTIFIER:-/usr/local/bin/cassanova-notify.py}
[[ -s "$DB" ]] || exit 0
for cmd in flock awk date install mktemp passwd chage jq python3; do command -v "$cmd" >/dev/null 2>&1 || { echo "Missing dependency: $cmd" >&2; exit 1; }; done
LOCK_DIR=$(dirname "$LOCK")
if [[ ! -d "$LOCK_DIR" ]]; then
  install -d -m 0700 "$LOCK_DIR"
fi
exec 9>"$LOCK"; flock -x 9
TODAY=$(date +%F)
TMP=$(mktemp)
DETAILS_TMP=$(mktemp)
trap 'rm -f "$TMP" "$DETAILS_TMP"' EXIT
changed=0
failures=0
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^###\  ]]; then
    read -r marker user expiry status _ <<< "$line"
    if [[ "$expiry" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      if [[ "$expiry" < "$TODAY" && "$status" != expired ]]; then
        if passwd -l "$user" >/dev/null 2>&1 && chage -E "$expiry" "$user" >/dev/null 2>&1; then
          printf '### %s %s expired\n' "$user" "$expiry" >> "$TMP"
          jq -cn --arg username "$user" --arg expiry "$expiry" --arg status expired '{username:$username,expiry:$expiry,status:$status}' >> "$DETAILS_TMP"
          changed=$((changed+1))
        else
          echo "Gagal mengunci/menetapkan expiry Linux untuk akun $user; metadata tetap dipertahankan." >&2
          printf '%s\n' "$line" >> "$TMP"
          failures=$((failures+1))
        fi
      elif [[ ! "$expiry" < "$TODAY" && "$status" != expired ]]; then
        # Keep a non-expired SSH account valid through the displayed expiry date.
        linux_expiry=$(date -d "${expiry} + 1 day" +%F) || { echo "Tanggal expiry tidak valid: $user" >&2; failures=$((failures+1)); printf '%s\n' "$line" >> "$TMP"; continue; }
        if ! chage -E "$linux_expiry" "$user" >/dev/null 2>&1; then
          echo "Gagal menyelaraskan expiry Linux untuk akun $user." >&2
          failures=$((failures+1))
        fi
        printf '%s\n' "$line" >> "$TMP"
      else
        printf '%s\n' "$line" >> "$TMP"
      fi
    else
      printf '%s\n' "$line" >> "$TMP"
    fi
  else
    printf '%s\n' "$line" >> "$TMP"
  fi
done < "$DB"
if (( changed )); then
  install -o root -g root -m 0600 "$TMP" "$DB"
  if [[ -f "$NOTIFIER" ]]; then
    DETAILS=$(jq -s '.' "$DETAILS_TMP")
    jq -cn --arg event expired --arg protocol SSH --arg context 'OpenSSH: akun expired dikunci; sshd tidak direstart.' --argjson details "$DETAILS" \
      '{event:$event,protocol:$protocol,context:$context,details:$details}' | python3 "$NOTIFIER" \
      || echo 'SSH expiry enforced, but Telegram notification failed.' >&2
  fi
fi
if (( failures )); then echo 'Sebagian akun tidak berhasil disinkronkan; metadata yang gagal dipertahankan untuk percobaan berikutnya.' >&2; fi
printf 'SSH expiry enforcement complete: %s account(s) newly expired; %s error(s).\n' "$changed" "$failures"
(( failures == 0 )) || exit 1
