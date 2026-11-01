# Changelog

## 2.1.0-r1-dev — 2026-11-01
- Hardened installer with pre-install snapshot and strict service/config validation.
- Preserve administrator Nginx configuration and root shell startup configuration.
- Install Cassanova Nginx vhost as a dedicated drop-in.
- Use a panel-owned Dropbear systemd unit.
- Convert `menu.sh` from a generator into an executable runtime script.
- Disable the invalid raw-TCP-over-WebSocket SSH proxy.
- Disable the unsafe legacy Xray auto-kill/expiry scripts until account transaction logic is rebuilt.
- Add static validation script and GitHub Actions on Ubuntu 22.04/24.04.


## 2.2.0-r2-dev — Service & Reverse Proxy Operations
- Added a guarded service manager for Xray, sing-box, Nginx, Cassanova Dropbear, Fail2ban, vnStat, and the optional Telegram bot.
- Added preflight validation before Xray/sing-box/Nginx restarts and before the restart-all operation.
- Added TCP/UDP listener inspection and TLS certificate hostname, expiry, key-match, and local CA trust checks.
- Replaced stale menu service names and unsafe blind restart commands with the service manager.
- Nginx reload is only allowed after `nginx -t` succeeds. Existing administrator Nginx files are not edited by the service manager.
- This is an operational-management layer; it does not claim end-to-end protocol connectivity or provider-firewall verification.


## 2.3.0-r3-dev — Live Xray Account Manager & Telegram Alerts
- Added Xray HandlerService API on `127.0.0.1:10085` for VLESS, VMess, and Trojan account lifecycle operations.
- Create, delete, modify, lock, unlock, and recovery now update Xray at runtime without restarting the Xray service.
- Renew updates expiry metadata without restarting Xray; renewing a locked account reactivates it through the API.
- Added one-time API activation flow for existing R2 servers. Only this initial activation requires a restart to load the API listener.
- Added Telegram notifications to configured ADMIN IDs for create, renew, delete, modify, lock, unlock, expiry, and recovery, including account details and connection links where applicable.
- Added daily systemd expiry timer using the API; no routine Xray restart is required.
- Added mocked Xray lifecycle tests and offline notifier formatting/routing tests.


## 2.4.0-r4-dev — SSH, Hysteria2 & Telegram Lifecycle Integration
- Added Telegram lifecycle notifications for SSH create, renew, delete, password change, lock, unlock, and recovery/synchronization. SSH passwords are not persisted in the account database; therefore renew/recovery notices never invent or expose an old password.
- Added SSH expiry enforcement through a daily helper. Expired Linux tunnel accounts are locked without restarting sshd; renew can reactivate an account previously marked expired.
- Added Hysteria2 create, renew, delete, modify, lock, unlock, expiry, and recovery notifications with account credentials/links routed only to configured Telegram ADMIN IDs.
- Added Hysteria2 recovery to rebuild sing-box config from the protected account database.
- Improved sing-box update transaction and rollback. Metadata-only operations that produce an identical effective config (commonly renewal) skip sing-box restart; operations changing Hysteria2 users still restart sing-box because this manager currently has no live per-user runtime API.
- Expanded daily expiry orchestration to Xray, Hysteria2, and SSH.
- Added static checks and offline Telegram notifier tests for SSH recovery and Hysteria2 messages.


## 2.5.0-r5-dev — Per-user Xray bandwidth enforcement
- Added Xray StatsService and level-0 user traffic counters for VLESS, VMess, and Trojan.
- Added a systemd timer that accumulates per-user uplink/downlink bytes and locks users when their configured GB quota is reached.
- Added Telegram notification for bandwidth-triggered lockout.
- Added per-user bandwidth usage reset action to the three Xray protocol menus.
- Non-zero per-account IP limits are now rejected explicitly; they are not falsely presented as enforced.
- Hysteria2 and SSH quota enforcement remain unsupported and are documented as such.
- Live VPS integration tests are still required before production release.

## R6 — Hysteria2 graceful configuration reload (2.6.0-r6-dev)
- Hysteria2 account changes now validate the staged sing-box config and request a SIGHUP reload instead of routinely restarting sing-box.
- If the service becomes inactive after reload, the manager restores the previous database/config and attempts service recovery. This exceptional recovery path may use a full restart.
- No claim is made that active sessions are guaranteed to survive every configuration change; verify on a live VPS/client before production rollout.
