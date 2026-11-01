#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

while IFS= read -r -d '' file; do
  bash -n "$file"
done < <(find . -type f -name '*.sh' -print0)

python3 - <<'PY'
import pathlib, py_compile, tempfile
root = pathlib.Path('.')
with tempfile.TemporaryDirectory(prefix='cassanova-pycheck-') as cache:
    for path in root.rglob('*.py'):
        py_compile.compile(str(path), cfile=str(pathlib.Path(cache) / (path.name + '.pyc')), doraise=True)
PY

# Guardrails for known destructive regressions.
! grep -Eq 'rm -f /etc/nginx/sites-enabled/\*|rm -f /etc/nginx/conf.d/\*' setup.sh
! grep -Eq '> /etc/nginx/nginx\.conf|> /root/\.bashrc' setup.sh
! grep -q 'HTTP/1.1 101 Switching Protocols' setup.sh
! grep -q 'autokill-xray' setup.sh

grep -q 'cassanova-xray.conf' setup.sh
grep -q 'xray run -test' setup.sh
grep -q 'sing-box check' setup.sh
grep -q 'CASSANOVA TUNNELING V2' setup.sh
grep -q '^#!/usr/bin/env bash' menu.sh

# R2 service manager must be shipped by both fresh setup and updater.
bash -n modules/cassanova-service.sh
grep -q 'modules/cassanova-service.sh:/usr/bin/cassanova-service' setup.sh
grep -q 'modules/cassanova-service.sh|/usr/bin/cassanova-service|0755' update.sh
grep -q 'validate_xray' modules/cassanova-service.sh
grep -q 'validate_singbox' modules/cassanova-service.sh
grep -q 'validate_nginx' modules/cassanova-service.sh

printf 'Static checks passed. These checks do not replace VM/service/protocol integration tests.\n'

# R3: Xray account lifecycle must use loopback HandlerService API and notify admins.
grep -q '"StatsService"' setup.sh
grep -q 'statsUserUplink' setup.sh
grep -q '$XRAY_BIN.*api adu' modules/xray-manager.sh
grep -q '$XRAY_BIN.*api rmu' modules/xray-manager.sh
grep -q '127.0.0.1:10085' modules/xray-manager.sh
grep -q 'notify_event create' modules/xray-manager.sh
grep -q 'notify_event renew' modules/xray-manager.sh
grep -q 'notify_event delete' modules/xray-manager.sh
grep -q 'notify_event recovery' modules/xray-manager.sh
grep -q 'cassanova-notify.py' setup.sh
grep -q 'cassanova-notify.py' update.sh
grep -q 'Recovery Account' modules/m-vless.sh
grep -q 'api-enable' modules/m-vmess.sh
grep -q 'cassanova-expire.timer' setup.sh
grep -q 'cassanova-bandwidth.timer' setup.sh
grep -q 'modules/cassanova-bandwidth.py:/usr/bin/cassanova-bandwidth' setup.sh
grep -q 'modules/cassanova-bandwidth.py|/usr/bin/cassanova-bandwidth|0755' update.sh
! grep -q 'restart_xray' modules/xray-manager.sh

printf 'R3 static checks passed. Live Xray HandlerService behaviour still requires a real VPS integration test.\n'

# R4: SSH/Hysteria2 lifecycle notification and safe expiry integration.
grep -q 'notify_event create' modules/m-ssh.sh
grep -q 'notify_event renew' modules/m-ssh.sh
grep -q 'notify_event delete' modules/m-ssh.sh
grep -q 'notify_event recovery' modules/m-ssh.sh
grep -q 'notify_event create' modules/hy2-manager.sh
grep -q 'notify_event renew' modules/hy2-manager.sh
grep -q 'notify_event delete' modules/hy2-manager.sh
grep -q 'notify_event recovery' modules/hy2-manager.sh
grep -q 'cmp -s "$tmpcfg" "$CONFIG"' modules/hy2-manager.sh
grep -q 'cassanova-ssh-expire' modules/cassanova-expire.sh
grep -q 'modules/cassanova-ssh-expire.sh:/usr/bin/cassanova-ssh-expire' setup.sh
grep -q 'modules/cassanova-ssh-expire.sh|/usr/bin/cassanova-ssh-expire|0755' update.sh
printf 'R4 SSH/Hysteria2 integration static checks passed. Live sing-box/SSH integration still requires VPS testing.\n'

# R5: Xray bandwidth quota is enforced from StatsService; IP quota is explicitly unsupported.
grep -q 'StatsService' modules/xray-manager.sh
grep -q 'api-in' modules/xray-manager.sh
grep -q 'dokodemo-door' modules/xray-manager.sh
grep -q 'cassanova-bandwidth' modules/xray-manager.sh
grep -q 'limit-reset' modules/xray-manager.sh
grep -q 'Limit IP per akun belum didukung' modules/xray-manager.sh
grep -q 'cassanova-bandwidth.timer' setup.sh
grep -q 'bandwidth_limit' modules/cassanova-notify.py
python3 tests/test-bandwidth.py
printf 'R5 bandwidth unit tests passed. Live Xray StatsService enforcement still requires VPS integration testing.\n'

grep -q 'fourth.*expired' modules/m-ssh.sh

# R6: Hysteria2 account changes must use SIGHUP reload, not routine restart.
grep -q 'systemctl kill --signal=HUP --kill-whom=main' modules/hy2-manager.sh
grep -q 'Konfigurasi dimuat ulang dengan SIGHUP' modules/hy2-manager.sh
printf 'R6 Hysteria2 graceful-reload static checks passed. Live SIGHUP behaviour requires VPS integration testing.\n'
