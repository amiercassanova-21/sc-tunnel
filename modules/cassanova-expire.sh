#!/usr/bin/env bash
# Daily account expiry enforcement across Xray, Hysteria2 and SSH.
set -u
[[ $EUID -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }
failures=0
for proto in vless vmess trojan; do
  if [[ -x /usr/bin/xray-manager ]]; then
    /usr/bin/xray-manager "$proto" expire || { echo "Xray expiry failed: $proto" >&2; failures=$((failures+1)); }
  fi
done
if [[ -x /usr/bin/hy2-manager ]]; then
  /usr/bin/hy2-manager expire || { echo 'Hysteria2 expiry failed.' >&2; failures=$((failures+1)); }
fi
if [[ -x /usr/bin/cassanova-ssh-expire ]]; then
  /usr/bin/cassanova-ssh-expire || { echo 'SSH expiry failed.' >&2; failures=$((failures+1)); }
fi
(( failures == 0 )) || exit 1
