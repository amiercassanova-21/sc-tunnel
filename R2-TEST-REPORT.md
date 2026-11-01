# SC Cassanova Tunneling V2 — R2 Test Report

Version: `2.2.0-r2-dev`
Scope: service operations and guarded reverse-proxy/service validation.

## Implemented

- `modules/cassanova-service.sh` provides status, config validation, TCP/UDP listener display, TLS checks, allowlisted service restarts, Nginx reload, and an interactive menu.
- Xray, sing-box, and Nginx are validated before their restart/reload operations.
- `restart-all` validates Xray, sing-box, and Nginx first. It excludes OpenSSH from the restart list to avoid disconnecting the operator.
- Main menu option 10 and FEATURES option 23 open the service manager.
- FEATURES shortcuts for service status, config validation, Dropbear restart, and restart-all use the new manager.
- Fresh installer and GitHub updater manifests both install/update the new manager.

## Tests run in this build environment

- `bash tests/static-check.sh` — PASS.
- `bash -n` on setup, updater, menu, service manager, and feature menu — PASS.
- `python3 -m py_compile bot-tele.py` — PASS.
- ZIP archive listing and SHA256 verification — to be performed after packaging.

## Not tested / limitations

- No live Ubuntu 22.04/24.04 or Debian 12/13 VM was available for installation tests.
- No real systemd restart/reload, Nginx configuration integration, Xray runtime, or sing-box runtime test was performed.
- Listener inspection uses local `ss` output and cannot confirm provider-side firewall/security-group rules or external reachability.
- TLS check validates local expiry, hostname, key pair, and chain against the OS CA bundle. It does not issue or renew certificates.
- R2 does not rewrite Nginx virtual hosts, Xray transports, domain settings, or firewall rules.
- A valid syntax/configuration test does not prove a VLESS/VMess/Trojan/Hysteria2/SSH client can connect.

## Deployment warning

This is a development snapshot, not a production release. Test on a disposable VPS and take a verified backup before installing. Do not merge into the public `main` branch until VM integration and end-to-end protocol tests pass.
