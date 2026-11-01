#!/usr/bin/env bash
# Certbot deploy hook: validate and atomically refresh Cassanova's certificate copies.
set -Eeuo pipefail
umask 077

DOMAIN=$(tr -d '[:space:]' < /etc/xray/domain.txt 2>/dev/null || true)
LINEAGE=${RENEWED_LINEAGE:-}
[[ -n "$DOMAIN" && -n "$LINEAGE" && -s "$LINEAGE/fullchain.pem" && -s "$LINEAGE/privkey.pem" ]] || exit 0
# A renewal for another Certbot domain must not replace the active panel certificate.
openssl x509 -in "$LINEAGE/fullchain.pem" -noout -checkhost "$DOMAIN" >/dev/null 2>&1 || exit 0
openssl x509 -in "$LINEAGE/fullchain.pem" -noout -checkend 0 >/dev/null 2>&1 || { echo 'Renewed certificate has expired.' >&2; exit 1; }

WORK=$(mktemp -d /var/tmp/cassanova-cert-renew.XXXXXX)
MUTATION_STARTED=0
ROLLBACK_DONE=0
cleanup() {
  local exit_status=$?
  trap - EXIT
  # Restore the previous certificate set if an unexpected command failure
  # happens after the first live file has been replaced.
  if (( exit_status != 0 && MUTATION_STARTED && !ROLLBACK_DONE )); then
    restore_old
  fi
  rm -f /etc/xray/.xray.crt.renew /etc/xray/.xray.key.renew /etc/sing-box/certs/.fullchain.pem.renew /etc/sing-box/certs/.privkey.pem.renew
  rm -rf "$WORK"
}
trap cleanup EXIT
verify_chain() {
  local bundle="$1" leaf="$WORK/leaf.pem" chain="$WORK/chain.pem"
  awk 'BEGIN{n=0} /-----BEGIN CERTIFICATE-----/{n++} n==1{print} /-----END CERTIFICATE-----/ && n==1{exit}' "$bundle" > "$leaf"
  awk 'BEGIN{n=0} /-----BEGIN CERTIFICATE-----/{n++} n>=2{print}' "$bundle" > "$chain"
  [[ -s "$leaf" ]] || return 1
  if [[ -s "$chain" ]]; then
    openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt -untrusted "$chain" "$leaf" >/dev/null 2>&1
  else
    openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt "$leaf" >/dev/null 2>&1
  fi
}
verify_chain "$LINEAGE/fullchain.pem" || { echo 'Renewed certificate chain is not trusted by the system CA store.' >&2; exit 1; }
CERT_PUB=$(openssl x509 -in "$LINEAGE/fullchain.pem" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')
KEY_PUB=$(openssl pkey -in "$LINEAGE/privkey.pem" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')
[[ -n "$CERT_PUB" && "$CERT_PUB" == "$KEY_PUB" ]] || { echo 'Certificate/private key mismatch.' >&2; exit 1; }

XRAY_WAS_ACTIVE=0; SBOX_WAS_ACTIVE=0; NGINX_WAS_ACTIVE=0
systemctl is-active --quiet xray && XRAY_WAS_ACTIVE=1 || true
systemctl is-active --quiet sing-box && SBOX_WAS_ACTIVE=1 || true
systemctl is-active --quiet nginx && NGINX_WAS_ACTIVE=1 || true

# Save exactly which files existed so rollback also removes newly introduced files.
for item in /etc/xray/xray.crt /etc/xray/xray.key /etc/sing-box/certs/fullchain.pem /etc/sing-box/certs/privkey.pem; do
  if [[ -e "$item" ]]; then cp -a "$item" "$WORK/$(printf '%s' "$item" | sed 's#^/##; s#/#_#g')"; fi
done
restore_file() {
  local path="$1" mode="$2" group="$3" backup="$WORK/$(printf '%s' "$path" | sed 's#^/##; s#/#_#g')"
  if [[ -e "$backup" ]]; then install -o root -g "$group" -m "$mode" "$backup" "$path"
  else rm -f "$path"; fi
}
restore_old() {
  restore_file /etc/xray/xray.crt 0644 root
  restore_file /etc/xray/xray.key 0600 root
  if [[ -d /etc/sing-box/certs ]]; then
    getent group sing-box >/dev/null 2>&1 || groupadd --system sing-box
    restore_file /etc/sing-box/certs/fullchain.pem 0640 sing-box
    restore_file /etc/sing-box/certs/privkey.pem 0640 sing-box
  fi
  if (( XRAY_WAS_ACTIVE )); then systemctl restart xray >/dev/null 2>&1 || true; fi
  if (( SBOX_WAS_ACTIVE )); then
    systemctl kill --signal=HUP --kill-whom=main sing-box >/dev/null 2>&1 || systemctl restart sing-box >/dev/null 2>&1 || true
  fi
  if (( NGINX_WAS_ACTIVE )); then systemctl reload nginx >/dev/null 2>&1 || systemctl restart nginx >/dev/null 2>&1 || true; fi
  ROLLBACK_DONE=1
}

install -o root -g root -m 0644 "$LINEAGE/fullchain.pem" /etc/xray/.xray.crt.renew
install -o root -g root -m 0600 "$LINEAGE/privkey.pem" /etc/xray/.xray.key.renew
MUTATION_STARTED=1
mv -f /etc/xray/.xray.crt.renew /etc/xray/xray.crt
mv -f /etc/xray/.xray.key.renew /etc/xray/xray.key
if [[ -d /etc/sing-box/certs ]]; then
  getent group sing-box >/dev/null 2>&1 || groupadd --system sing-box
  install -d -o root -g sing-box -m 0750 /etc/sing-box/certs
  install -o root -g sing-box -m 0640 "$LINEAGE/fullchain.pem" /etc/sing-box/certs/.fullchain.pem.renew
  install -o root -g sing-box -m 0640 "$LINEAGE/privkey.pem" /etc/sing-box/certs/.privkey.pem.renew
  mv -f /etc/sing-box/certs/.fullchain.pem.renew /etc/sing-box/certs/fullchain.pem
  mv -f /etc/sing-box/certs/.privkey.pem.renew /etc/sing-box/certs/privkey.pem
fi

if command -v xray >/dev/null 2>&1 && [[ -s /usr/local/etc/xray/config.json ]] && ! xray run -test -config /usr/local/etc/xray/config.json >/dev/null; then
  restore_old; echo 'Xray config validation failed after certificate update.' >&2; exit 1
fi
if command -v nginx >/dev/null 2>&1 && ! nginx -t >/dev/null; then
  restore_old; echo 'Nginx config validation failed after certificate update.' >&2; exit 1
fi
if command -v sing-box >/dev/null 2>&1 && [[ -s /etc/sing-box/config.json ]] && ! sing-box check -c /etc/sing-box/config.json >/dev/null; then
  restore_old; echo 'sing-box config validation failed after certificate update.' >&2; exit 1
fi

if (( XRAY_WAS_ACTIVE )) && { ! systemctl restart xray || ! systemctl is-active --quiet xray; }; then
  restore_old; echo 'Xray failed after certificate renewal.' >&2; exit 1
fi
if (( SBOX_WAS_ACTIVE )); then
  if ! systemctl kill --signal=HUP --kill-whom=main sing-box || ! systemctl is-active --quiet sing-box; then
    if ! systemctl restart sing-box || ! systemctl is-active --quiet sing-box; then
      restore_old; echo 'sing-box failed after certificate renewal.' >&2; exit 1
    fi
  fi
fi
if (( NGINX_WAS_ACTIVE )) && ! systemctl reload nginx; then
  restore_old; echo 'Nginx failed to reload after certificate renewal.' >&2; exit 1
fi
logger -t cassanova-cert-renew "Updated TLS certificate copies for ${DOMAIN}"
