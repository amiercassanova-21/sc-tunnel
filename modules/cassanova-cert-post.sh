#!/usr/bin/env bash
# Certbot post-hook: restore Nginx only if the pre-hook stopped an active instance.
set -Eeuo pipefail
MARKER=/run/cassanova-certbot-nginx-was-active
if [[ -e "$MARKER" ]]; then
  # Keep the marker if starting Nginx fails so an operator can retry safely.
  systemctl start nginx
  rm -f "$MARKER"
fi
