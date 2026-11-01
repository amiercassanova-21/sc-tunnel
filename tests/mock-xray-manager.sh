#!/usr/bin/env bash
# Isolated mock integration test: account lifecycle must not invoke systemctl restart.
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/etc/xray" "$TMP/run/lock" "$TMP/backups" "$TMP/limits/ip" "$TMP/limits/bw"
cat > "$TMP/bin/xray" <<'XRAY'
#!/usr/bin/env bash
case "$1" in
  run) exit 0 ;;
  api)
    case "$2" in
      adu) echo 'Added 1 user(s) in total.' ;;
      rmu) echo 'Removed 1 user(s) in total.' ;;
      *) exit 2 ;;
    esac
    ;;
  *) exit 2 ;;
esac
XRAY
cat > "$TMP/bin/ss" <<'SS'
#!/usr/bin/env bash
printf 'LISTEN 0 128 127.0.0.1:10085 0.0.0.0:*\n'
SS
cat > "$TMP/bin/systemctl" <<EOF2
#!/usr/bin/env bash
echo "\$*" >> "$TMP/systemctl.log"
exit 0
EOF2
chmod +x "$TMP/bin/"*

# Relocate hard-coded production paths into the disposable test directory.
sed \
  -e "s|DB_FILE=\"/etc/xray/\${PROTO}.db\"|DB_FILE=\"$TMP/etc/xray/\${PROTO}.db\"|" \
  -e "s|CONFIG=\"/usr/local/etc/xray/config.json\"|CONFIG=\"$TMP/etc/xray/config.json\"|" \
  -e "s|LOCK_FILE=\"/run/lock/cassanova-xray-manager.lock\"|LOCK_FILE=\"$TMP/run/lock/manager.lock\"|" \
  -e "s|LIMIT_IP_DIR=\"/etc/xray/limit/ip\"|LIMIT_IP_DIR=\"$TMP/limits/ip\"|" \
  -e "s|LIMIT_BW_DIR=\"/etc/xray/limit/bw\"|LIMIT_BW_DIR=\"$TMP/limits/bw\"|" \
  -e "s|BACKUP_DIR=\"/var/backups/cassanova/xray\"|BACKUP_DIR=\"$TMP/backups\"|" \
  -e "s|NOTIFIER=\"/usr/local/bin/cassanova-notify.py\"|NOTIFIER=\"$TMP/no-notifier.py\"|" \
  -e "s|/etc/xray/domain.txt|$TMP/etc/xray/domain.txt|g" \
  -e "s|/etc/xray/sni.txt|$TMP/etc/xray/sni.txt|g" \
  "$ROOT_DIR/modules/xray-manager.sh" > "$TMP/xray-manager"
chmod +x "$TMP/xray-manager"
cat > "$TMP/etc/xray/config.json" <<'JSON'
{"api":{"tag":"api","listen":"127.0.0.1:10085","services":["HandlerService"]},"inbounds":[{"tag":"vless-test","protocol":"vless","settings":{"clients":[]}}],"outbounds":[{"protocol":"freedom","tag":"direct"}]}
JSON
: > "$TMP/etc/xray/vless.db"
echo 'test.example.com' > "$TMP/etc/xray/domain.txt"
echo 'test.example.com' > "$TMP/etc/xray/sni.txt"
export PATH="$TMP/bin:$PATH"

printf 'r3user\n3\n2\n0\n' | "$TMP/xray-manager" vless create >/dev/null
 grep -q '^### r3user ' "$TMP/etc/xray/vless.db"
 jq -e '.inbounds[0].settings.clients | any(.email=="r3user")' "$TMP/etc/xray/config.json" >/dev/null
printf 'r3user\n2\n' | "$TMP/xray-manager" vless renew >/dev/null
printf '' | "$TMP/xray-manager" vless recovery >/dev/null
printf 'r3user\n' | "$TMP/xray-manager" vless delete >/dev/null
! grep -q '^### r3user ' "$TMP/etc/xray/vless.db"
jq -e '.inbounds[0].settings.clients | length==0' "$TMP/etc/xray/config.json" >/dev/null
[[ ! -s "$TMP/systemctl.log" ]] || { echo 'Unexpected systemctl call during account CRUD/recovery.' >&2; cat "$TMP/systemctl.log" >&2; exit 1; }
echo 'Mock Xray lifecycle test passed: create/renew/recovery/delete completed without systemctl restart.'
