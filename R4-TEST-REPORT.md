# SC Cassanova Tunneling V2 — R4 Test Report

Version: `2.4.0-r4-dev`
Scope: SSH and Hysteria2 account lifecycle notifications, recovery, and expiry integration.

## Implemented

- SSH manager sends Telegram notifications for create, renew, delete, password change, lock, unlock, and recovery/synchronization.
- SSH recovery reconciles expiry and lock state for Linux users that still exist. It reports missing users rather than recreating them without a password/hash source.
- SSH expiry helper locks newly expired accounts without restarting `sshd`; the daily expiry orchestrator now calls it.
- Hysteria2 manager sends Telegram notifications for create, renew, delete, modify, lock, unlock, expiry, and recovery, including current credential/link information where available.
- Hysteria2 recovery rebuilds sing-box configuration from `/etc/sing-box/users.json`.
- Hysteria2 apply operation now rolls back database/config files on install or service activation failure. If the generated effective config is identical, it skips sing-box restart.
- Daily expiry orchestration runs Xray, Hysteria2, and SSH jobs independently and reports failures at the end.

## Tests executed in this build environment

- `bash -n` for all shell scripts — PASS.
- Python compilation for all Python files — PASS.
- `bash tests/static-check.sh` — PASS (expected after running the test suite).
- `python3 tests/test-notifier.py` — PASS using mocked Telegram HTTP responses for Xray, SSH recovery, and Hysteria2; no real Telegram message was sent.
- `bash tests/test-ssh-expire.sh` — PASS for newly-expired account locking and repeat-run idempotency using a mocked `passwd` command.
- `bash tests/mock-xray-manager.sh` — PASS for the existing mocked Xray create/renew/recovery/delete lifecycle; no Xray service restart was invoked.
- ZIP integrity and SHA256 — verified during packaging.

## Not tested / limitations

- No live Ubuntu 22.04/24.04 or Debian 12/13 VPS was available.
- No real OpenSSH user lifecycle was run against a disposable Linux account in a VPS.
- No real sing-box process was used to validate the generated Hysteria2 config or observe session impact.
- Hysteria2 account/credential/status changes still require a sing-box restart when the effective config changes. This may interrupt active Hysteria2 sessions. A metadata-only renewal that leaves runtime config identical skips restart.
- SSH passwords are not stored in the account database. Recovery can only reconcile existing system users; missing users must be recreated with a newly assigned password.
- Telegram delivery was tested with a mock HTTP response, not a real bot token/chat.
- Existing R3 Xray runtime/API limitations remain: API activation on an existing installation requires one initial Xray restart; limit IP/bandwidth enforcement is not implemented.

## Deployment recommendation

Treat this as a development build. Install/test on a disposable VPS first. Before enabling Telegram credential notifications, confirm the `ADMIN` IDs in `/etc/bot/bot.conf` are trusted and keep that file mode `0600`.
