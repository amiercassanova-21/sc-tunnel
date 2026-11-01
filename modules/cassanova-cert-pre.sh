#!/usr/bin/env bash
# Certbot pre-hook for the standalone authenticator: stop Nginx only when it was active.
set -Eeuo pipefail
umask 077
MARKER=/run/cassanova-certbot-nginx-was-active
if systemctl is-active --quiet nginx; then
  install -d -m 0755 /run
  : > "$MARKER"
  chmod 0600 "$MARKER"
  systemctl stop nginx
fi
