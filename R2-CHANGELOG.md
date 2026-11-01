# R2 — Service & Reverse Proxy Manager

## Changes
- Added `modules/cassanova-service.sh`, installed as `/usr/bin/cassanova-service`.
- Added status, config validation, listener inspection, TLS checks, allowlisted restarts, Nginx reload, and interactive UI.
- Xray, sing-box, and Nginx are validated before restart/reload.
- Restart-all validates all configurations before restarting installed core services. SSH is excluded from restart-all to avoid disconnecting the operator.
- Updated main menu and FEATURES shortcuts to use actual service names and guarded operations.
- Added module to setup and GitHub update manifests.

## Explicit limitations
- `ss` only reports local listeners; it cannot verify cloud-provider firewalls or external reachability.
- TLS check validates local certificate expiry, hostname, key match, and trust against the system CA bundle; it does not renew certificates.
- No real VPS/systemd/Nginx/Xray/sing-box integration test was run in this environment.
- Existing Nginx configuration and protocol paths are not automatically rewritten in R2.
