#!/usr/bin/env bash
# Offline regression tests for the Hysteria2 DB schema and sing-box config merge.
set -Eeuo pipefail
command -v jq >/dev/null 2>&1 || { echo 'jq is required for Hysteria2 tests.' >&2; exit 2; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

validate_db() {
  jq -e '
    type == "array" and
    all(.[ ];
      type == "object" and
      (.username | type == "string" and test("^[A-Za-z0-9_.-]{1,32}$")) and
      (.password | type == "string" and test("^[A-Za-z0-9._~-]{12,128}$")) and
      (.expiry | type == "string") and
      (.expiry as $d | ($d | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")) and (try (($d | strptime("%Y-%m-%d") | mktime | strftime("%Y-%m-%d")) == $d) catch false)) and
      (.status == "active" or .status == "locked" or .status == "expired")
    ) and
    (. as $rows | ([ $rows[].username ] | unique | length) == ($rows | length))
  ' "$1" >/dev/null 2>&1
}

TODAY=$(date +%F)
cat > "$TMP/valid.json" <<JSON
[
 {"username":"active1","password":"0123456789abcdef0123","expiry":"$TODAY","status":"active"},
 {"username":"locked1","password":"0123456789abcdef0124","expiry":"2099-12-31","status":"locked"},
 {"username":"expired1","password":"0123456789abcdef0125","expiry":"2020-01-01","status":"expired"}
]
JSON
validate_db "$TMP/valid.json"
printf '[]\n' > "$TMP/empty.json"; validate_db "$TMP/empty.json"
cat > "$TMP/bad-date.json" <<'JSON'
[{"username":"baddate","password":"0123456789abcdef0123","expiry":"2026-02-31","status":"active"}]
JSON
if validate_db "$TMP/bad-date.json"; then echo 'Invalid calendar date was accepted.' >&2; exit 1; fi
cat > "$TMP/bad-status.json" <<'JSON'
[{"username":"badstatus","password":"0123456789abcdef0123","expiry":"2026-12-31","status":"paused"}]
JSON
if validate_db "$TMP/bad-status.json"; then echo 'Unknown status was accepted.' >&2; exit 1; fi
cat > "$TMP/duplicate.json" <<'JSON'
[{"username":"same","password":"0123456789abcdef0123","expiry":"2026-12-31","status":"active"},{"username":"same","password":"0123456789abcdef0124","expiry":"2026-12-31","status":"active"}]
JSON
if validate_db "$TMP/duplicate.json"; then echo 'Duplicate username was accepted.' >&2; exit 1; fi

cat > "$TMP/config.json" <<'JSON'
{
  "log":{"level":"info"},
  "dns":{"servers":[{"tag":"dns-local","address":"1.1.1.1"}]},
  "inbounds":[{"type":"shadowsocks","tag":"ss-in","listen":"::","listen_port":8080,"method":"2022-blake3-aes-128-gcm","password":"ss-pass"}],
  "outbounds":[{"type":"shadowsocks","tag":"proxy-out","server":"example.com","server_port":443,"method":"2022-blake3-aes-128-gcm","password":"ss-pass"}],
  "route":{"final":"proxy-out","rules":[{"protocol":"dns","outbound":"dns-out"}]},
  "experimental":{"cache_file":{"enabled":true}}
}
JSON
cat > "$TMP/users.json" <<JSON
[
 {"username":"active1","password":"0123456789abcdef0123","expiry":"$TODAY","status":"active"},
 {"username":"locked1","password":"0123456789abcdef0124","expiry":"2099-12-31","status":"locked"},
 {"username":"expired1","password":"0123456789abcdef0125","expiry":"2020-01-01","status":"expired"}
]
JSON

jq --arg cert '/etc/sing-box/certs/fullchain.pem' --arg key '/etc/sing-box/certs/privkey.pem' \
   --arg today "$TODAY" --slurpfile records "$TMP/users.json" '
    . as $root
    | ([ $records[0][] | select(.status == "active" and .expiry >= $today) | {name:.username,password:.password} ]) as $users
    | {type:"hysteria2",tag:"hysteria2-in",listen:"::",listen_port:443,
       users:$users,tls:{enabled:true,certificate_path:$cert,key_path:$key},
       masquerade:{type:"string",status_code:404,headers:{},content:"Not Found"}} as $hy2
    | $root
    | .inbounds = ((.inbounds // []) | map(select(.tag != "hysteria2-in")) + [$hy2])
    | .outbounds = ((.outbounds // []) | if any(.[]; .tag == "direct") then . else . + [{type:"direct",tag:"direct"}] end)
  ' "$TMP/config.json" > "$TMP/merged.json"

jq -e '
  .dns.servers[0].address == "1.1.1.1" and
  .route.final == "proxy-out" and
  .route.rules[0].outbound == "dns-out" and
  .experimental.cache_file.enabled == true and
  any(.inbounds[]; .tag == "ss-in" and .listen_port == 8080) and
  ([.inbounds[] | select(.tag == "hysteria2-in")] | length == 1) and
  ([.inbounds[] | select(.tag == "hysteria2-in") | .users[].name] == ["active1"]) and
  any(.outbounds[]; .tag == "proxy-out") and
  any(.outbounds[]; .tag == "direct")
' "$TMP/merged.json" >/dev/null

# Guard against accidental divergence between the manager and tested DB schema/config merge.
grep -Fq 'strptime("%Y-%m-%d")' "$ROOT/modules/hy2-manager.sh"
grep -Fq 'map(select(.tag != "hysteria2-in"))' "$ROOT/modules/hy2-manager.sh"
echo 'Hysteria2 DB schema and sing-box config merge tests passed.'
