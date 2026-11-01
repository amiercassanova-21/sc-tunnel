# SC Cassanova Tunneling V2 — R3 Test Report

Version: `2.3.0-r3-dev`
Scope: Xray VLESS/VMess/Trojan live account changes and Telegram lifecycle notifications.

## Implemented

- Xray HandlerService API configuration is loopback-only at `127.0.0.1:10085`.
- Fresh installs include the API object in the generated Xray config.
- Existing R2 installations can enable the API once from the protocol menu. This initial activation restarts Xray once because the API listener must be loaded from the config.
- Routine create, delete, modify, lock, unlock, recovery, and expiry operations use the runtime API and do not call `systemctl restart xray`.
- Renew changes expiry metadata only; if the account is locked, renewal re-adds it through the API and marks it unlocked.
- Recovery treats the protocol database as the source of truth and synchronizes all inbounds of the selected protocol.
- Telegram notifications are sent to numeric IDs in `/etc/bot/bot.conf` (`ADMIN=`). Create, renew, delete, modify, lock, unlock, expiry, and recovery events are supported.
- Notification content includes account credentials and generated links where available. This is sensitive information and is sent only to configured admin IDs.
- A daily systemd timer runs expiry reconciliation through the API.

## Tests actually run in this build environment

- `bash -n` for all shell scripts — PASS.
- `python3 -m py_compile` for Python files — PASS.
- `bash tests/static-check.sh` — PASS.
- `bash tests/mock-xray-manager.sh` — PASS. This uses a mocked Xray CLI/API and verifies create, renew, recovery, and delete complete without invoking `systemctl`.
- `python3 tests/test-notifier.py` — PASS. Telegram requests are mocked; no real Telegram message was sent.
- Generated Xray setup JSON parsed with `jq` — PASS.
- ZIP structure and SHA256 verification — performed during packaging.

## Not tested / release limitations

- No live Ubuntu 22.04/24.04 or Debian 12/13 VPS was available.
- No real Xray binary was used to verify the exact CLI/API behaviour against the installed Xray release.
- No live Telegram bot token/admin chat was used.
- Existing sessions' behaviour during live API add/remove was not measured on a production tunnel. Routine account operations do not restart Xray, but deleting/locking an account may not forcibly terminate already-established sessions; it prevents subsequent authentication according to Xray HandlerService semantics.
- IP and bandwidth limit values remain metadata only; enforcement is not implemented.
- The systemd expiry timer is packaged and statically checked but has not been observed running on a real VPS.

## Deployment guidance

- Treat this as a development build, not a production release.
- On a fresh install, the API is enabled from first Xray startup.
- On an existing R2 server, perform the one-time API activation during a maintenance window: it requires one Xray restart. After that, account create/renew/delete/recovery operations will not restart Xray.
- Do not expose TCP/10085 publicly; it must remain bound to `127.0.0.1`.
- Telegram notifications include credentials. Only configure trusted admin chat IDs and keep `/etc/bot/bot.conf` mode `0600`.
