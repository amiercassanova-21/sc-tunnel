# R1 implementation and verification report

Date: 2026-11-01
Source baseline: `SC_Cassanova_Tunneling_V2_Update_Manager.zip`

## Implemented in this development snapshot

1. Replaced the `menu.sh` heredoc generator with an executable runtime script.
2. Changed Nginx integration to a Cassanova-owned drop-in. The installer no longer rewrites `/etc/nginx/nginx.conf` or removes other sites/configuration files.
3. Preserved `/root/.bashrc` and appended only a marked, idempotent menu-launch block.
4. Added a pre-install archive under `/var/backups/cassanova/pre-install-*` for existing panel and selected system configuration paths.
5. Added strict `nginx -t`, `xray run -test`, and `sing-box check` before restarting core services.
6. Checked each core service after restart; installation exits with diagnostics when a service fails.
7. Gave Cassanova Dropbear its own `cassanova-dropbear.service` unit rather than replacing the package's `dropbear.service`.
8. Removed the invalid custom SSH WebSocket proxy from setup. SSH-over-WebSocket is not offered until a standards-compliant implementation is integrated and tested.
9. Removed installation of the legacy Xray auto-kill/auto-expiry cron scripts. Those scripts can corrupt account records; Xray expiry enforcement remains pending the account-service redesign.
10. Removed the menu's plaintext HTTP geolocation request and fixed the option prompt to include option 10.
11. Added `tests/static-check.sh` and GitHub Actions static validation for Ubuntu 22.04 and 24.04.

## Verification performed in this workspace

- `bash -n` on all shell scripts: PASS.
- Python bytecode compilation for project Python files: PASS.
- `tests/static-check.sh`: PASS.
- Guard checks for the known destructive Nginx and `.bashrc` rewrites: PASS.
- Guard checks for the invalid SSH WebSocket handshake and Xray auto-kill installer path: PASS.

## Not tested / release blockers

- No actual Ubuntu 22.04/24.04 or Debian 12/13 VM installation was run.
- No Xray or sing-box binary was invoked in this workspace against the generated configs.
- No live Nginx, systemd, Certbot, UDP firewall, Telegram API, or client protocol test was run.
- Existing Xray account manager, Hysteria2 manager, SSH account manager, Telegram bot, backup/restore and updater still require separate integration/security audits.
- This R1 snapshot is a development build, not a production release. Install only on a disposable test VPS after reviewing the scripts and taking an independent VPS snapshot.

## Important functional reductions

- SSH-over-WebSocket is intentionally unavailable in this build.
- Xray IP-limit auto-kill and legacy Xray auto-expiry cron jobs are intentionally unavailable until a safe transactional account engine is implemented.
- Limit-IP and bandwidth metadata must not be represented as enforced controls.
