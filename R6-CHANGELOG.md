# SC Cassanova Tunneling V2 — R6
# R6 — Hysteria2 graceful reload

- `hy2-manager` now requests `SIGHUP` for a changed, pre-validated sing-box configuration rather than doing a routine `systemctl restart`.
- Unchanged runtime configuration still causes no reload.
- On a failed signal operation, previous DB/config files are restored. If sing-box becomes inactive after reload, rollback is applied and a best-effort service restart is attempted as an emergency recovery path.
- The Hysteria2 standalone installer message now describes the reload behavior.

This is not a claim of zero packet/session disruption. A config reload can affect connections depending on sing-box version and the type of change. Validate on a staging VPS.

## R6 Hysteria2 storage/configuration safety correction
- Moved the Hysteria2 account database out of `/etc/sing-box` to `/var/lib/cassanova/hysteria2/users.json`, with validated legacy migration and preservation backup.
- Hysteria2 config generation now merges only the `hysteria2-in` inbound and preserves existing sing-box inbounds, outbounds, DNS, routing, and other root settings.
- Updated menu, Telegram bot, installer, setup snapshot, full backup, restore allowlist, and documentation for the new database path.
- Standalone installer now fetches R6 testing-branch scripts.


## R6 full-audit corrections
- Fixed Bash parsing errors in label/brand validators that prevented the main menu and Features menu from loading.
- Hardened Hysteria2 DB validation to reject impossible calendar dates, while retaining support for active, locked and expired records.
- Fixed restore ownership mapping: sing-box JSON fragments and certificate files regain the `root:sing-box` group and safe modes after extraction with `--no-same-owner`.
- Added a protected pre-install snapshot to the standalone Hysteria2 installer, including the root crontab sidecar.
- Added automatic rollback protection to domain changes so early failures cannot leave Nginx stopped or partially changed TLS/config files behind.
- Domain changes now reject proxy/load-balanced A records and unsupported AAAA records before requesting a certificate; re-entering the current domain is a no-op.
- SSH renewals no longer label an expired account as unlocked when the underlying `passwd -u` operation fails.
- Added offline regression tests for Hysteria2 schema/calendar validation and sing-box config merge preservation.
- Fixed an installer edge case so an absent/unreadable root crontab is never overwritten with an empty crontab while removing the obsolete HY2 cron line.
- Added failure-trap rollback to the Certbot deploy hook so a partial certificate-copy failure restores the prior Xray/sing-box certificate set.
- Fixed full backup creation so the Cassanova-managed root crontab can be staged even when the root backup directory did not previously exist.
- Clarified the Features and service-manager labels: custom SNI and core-service restart are named accurately; mass restart now requires explicit confirmation because it can interrupt live connections.
