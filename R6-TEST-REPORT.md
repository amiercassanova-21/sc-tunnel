# SC Cassanova Tunneling V2 — R6 Full Audit Test Report

## Audit scope
Audit performed against the local source tree for branch target `r6-testing`. The workspace is a source snapshot, not a live VPS or an authenticated Git clone. Changes in this report have not been pushed to GitHub or installed on Bot-01/Testgemini-01.

## Defects found and corrected
1. **Menu/Features Bash syntax:** two label/brand regex expressions contained unquoted whitespace in `[[ ... =~ ... ]]`, causing `bash -n` to fail and preventing those scripts from loading. Reworked the validation into a regex variable and verified syntax.
2. **Hysteria2 date schema:** the previous `YYYY-MM-DD` regex accepted impossible dates such as `2026-02-31`. The manager, fresh setup, and standalone installer now round-trip dates through `strptime/mktime/strftime` and reject invalid calendar dates.
3. **Restore service ownership:** safe archive extraction used `--no-same-owner`, but sing-box config/key files require group `sing-box`. Restore now reapplies known ownership/modes to `/etc/sing-box` JSON files, certificate files and the Hysteria2 database directories.
4. **Domain change safety:** an early error after stopping Nginx could leave it stopped; errors after a file mutation could leave mixed domain/certificate state. The domain utility now has an EXIT safety net and rollback for partially applied changes. It validates DNS more strictly and treats the current domain as a no-op.
5. **Standalone Hysteria2 install:** added a protected pre-install snapshot of the existing sing-box config, Hysteria2 DB, related scripts/systemd files, apt repo/key and root crontab before package/database changes.
6. **SSH renewal state:** metadata is no longer marked `unlocked` if `passwd -u` fails when renewing an expired account.
7. **Dead SSH selector:** removed an unused helper whose numeric selector passed an incorrect awk argument.
8. **Service-manager safety:** renamed the mass-restart action to core-service restart and added an explicit `RESTART` confirmation before it can interrupt active connections.
9. **Certbot deploy rollback:** a shell/IO failure partway through replacing the certificate files now triggers a rollback trap, not only explicit validation failures.
10. **Backup cron capture:** fixed creation of the root staging directory so Cassanova-managed cron lines are actually included in full backups.
11. **Installer crontab handling:** obsolete HY2 cron removal now edits the crontab only when one was successfully read; it does not pipe an empty list into `crontab -` on a missing/unreadable crontab.

## Validation actually run
- `bash -n` for every shell script in the source tree: **passed**.
- Python compile for all 5 `.py` files: **passed**.
- `tests/test-ssh-expire.sh`: **passed** (expiry enforcement/idempotency).
- `tests/test-notifier.py`: **passed** (offline structured notification formatting/allowlist cases).
- `tests/test-bandwidth.py`: **passed** (bandwidth parser cases).
- `tests/test-hy2-config.sh`: **passed** (calendar schema, status/duplicate rejection, Hysteria2 merge preserves Shadowsocks inbound, route, DNS, existing outbound and unrelated root config).
- `tests/static-check.sh`: **passed**, including the above regression tests.
- Final rerun after the last fixes: all shell syntax checks, 5-file Python compile, SSH expiry, notifier, bandwidth, Hysteria2 schema/merge and static regression suite: **passed**.

## Functional coverage / status
| Component | Implemented coverage | Status / boundary |
|---|---|---|
| VLESS / VMess / Trojan | Account create, delete, renew, modify, lock/unlock, recovery, expiry; Xray HandlerService | Code/static validated. Requires live HandlerService and client tests. API activation may require one initial Xray restart. |
| SSH | OpenSSH users, renew, lock/unlock, list, active login, recovery for existing Linux accounts, expiry | Offline expiry test passed. Does not recreate users or restore passwords on a new VPS. |
| Hysteria2 | Create/custom, list, modify, lock/unlock, renew, delete, expiry, recovery; isolated DB and config merge | DB/merge tests passed. sing-box `check`, HUP reload, UDP reachability, and client behavior need staging. |
| Telegram bot | Private-chat admin allowlist, singleton lock, update offset, status/list/restart/cleanup actions | Python compile and notifier tests passed. Telegram API polling and admin delivery need live token tests. |
| Bandwidth quota | Xray StatsService traffic accounting for VLESS/VMess/Trojan | Parser tests passed. Live StatsService/API and quota overshoot behavior need VPS testing; poll interval is about 60 sec. |
| Backup / restore | Protected app backup, checksum, archive path allowlist, pre-restore snapshot and service-state rollback | Static checks only. Cross-VPS restore must be tested. Linux account DB, OS/network state and package DB are intentionally excluded. |
| Domain/TLS | DNS validation, Let's Encrypt HTTP-01, matching key/cert, Xray/Nginx/sing-box config validation, rollback | Code/syntax checks only. Requires reachable TCP/80, direct A record to VPS IPv4, no unsupported AAAA during the check. TLS renew hooks need live Certbot test. |
| Service manager | Status, config validation, ports, TLS check, allowlisted restart/reload | Code/static validated; commands need staging run. Provider firewall is not observable from the VPS. |

## Features not implemented / intentionally limited
- OpenVPN is not implemented.
- The custom SSH-over-WebSocket implementation is disabled; standard SSH remains available.
- WARP item checks the Cloudflare trace endpoint only; it does not install or configure WARP.
- Per-IP account limits are not implemented.
- Bandwidth limits are currently supported only for Xray VLESS/VMess/Trojan, not SSH or Hysteria2.
- Hysteria2 requires CA-valid TLS and UDP/443 open at both VPS and provider firewall layers.
- Backup does not include `/etc/passwd`, `/etc/shadow`, group databases, network configuration, or system package database. Linux SSH accounts must be migrated separately.

## Required before production
1. Apply the package only on the **Testgemini-01** staging VPS after making an independent backup. Do not rerun the complete `setup.sh` on the existing staging server.
2. Verify existing Xray/VLESS accounts, Nginx TCP/443, and Shadowsocks remain active before and after installing the updated HY2 manager.
3. Run `sing-box check -c /etc/sing-box/config.json`, test `hy2-manager create/renew/lock/unlock/delete/recover`, and observe a real client during SIGHUP reload.
4. Test restore to a disposable VPS and confirm sing-box can read `/etc/sing-box/*.json` and `/etc/sing-box/certs/*.pem`.
5. Test Certbot renewal hooks and domain-change rollback with a test certificate/domain before production use.
6. Check systemd timers, logs, TCP/UDP ports, firewall/provider rules and real client connectivity.

**Conclusion:** the offline audit found and fixed several real defects, and all local static/offline tests pass. This does not mean every runtime feature is fully proven. Live staging/integration tests remain mandatory before production deployment.
