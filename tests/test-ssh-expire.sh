#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/run"
cat > "$TMP/bin/passwd" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" == -l && -n "$2" ]]
MOCK
cat > "$TMP/bin/chage" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" == -E && -n "$2" && -n "$3" ]] || exit 1
printf '%s %s %s\n' "$1" "$2" "$3" >> "$CASSANOVA_CHAGE_LOG"
MOCK
chmod +x "$TMP/bin/passwd" "$TMP/bin/chage"
cat > "$TMP/accounts.db" <<'DB'
### alice 2020-01-01 unlocked
### bob 2099-01-01 unlocked
### carol 2020-01-01 expired
DB
PATH="$TMP/bin:$PATH" CASSANOVA_SSH_DB="$TMP/accounts.db" CASSANOVA_SSH_LOCK="$TMP/run/lock" CASSANOVA_NOTIFIER="$TMP/no-notifier" CASSANOVA_CHAGE_LOG="$TMP/chage.log" \
  bash "$ROOT/modules/cassanova-ssh-expire.sh" > "$TMP/first.out"
grep -q '^### alice .* expired$' "$TMP/accounts.db"
grep -q '^### bob .* unlocked$' "$TMP/accounts.db"
grep -q '^### carol .* expired$' "$TMP/accounts.db"
grep -q -- '-E 2099-01-02 bob' "$TMP/chage.log"
PATH="$TMP/bin:$PATH" CASSANOVA_SSH_DB="$TMP/accounts.db" CASSANOVA_SSH_LOCK="$TMP/run/lock" CASSANOVA_NOTIFIER="$TMP/no-notifier" CASSANOVA_CHAGE_LOG="$TMP/chage.log" \
  bash "$ROOT/modules/cassanova-ssh-expire.sh" > "$TMP/second.out"
grep -q '0 account(s) newly expired' "$TMP/second.out"
echo 'SSH expiry unit test passed (new expiry enforcement and idempotency).'
