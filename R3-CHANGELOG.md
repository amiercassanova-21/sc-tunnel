# R3 — Xray Live Account Management & Telegram Notifications

## Main changes
- Account create/delete/modify/lock/unlock and recovery now use Xray HandlerService API instead of restarting the Xray systemd service.
- New installations enable HandlerService on loopback `127.0.0.1:10085`. No public API port is opened.
- Existing installations can activate API once from each protocol menu (`Aktifkan API`). This performs one initial Xray restart only to load the API listener. Subsequent account changes do not restart Xray.
- Renewal updates expiry metadata without restarting Xray. Expiry enforcement requires the scheduled expiry job to be installed and verified; this R3 does not claim that the legacy auto-expiry path is production-ready.
- Added a Telegram notification helper. Create, renew, delete, modify, lock, unlock, and recovery events send account details to the configured ADMIN IDs.
- Recovery rebuilds protocol clients from the protocol database and reconciles running inbounds through the API.

## Important security notes
- The API listens only on loopback. Do not expose TCP/10085 publicly.
- Telegram notifications include credentials and connection links. Configure only trusted ADMIN chat IDs and protect `/etc/bot/bot.conf` with mode 0600.
- The API activation step needs one initial restart on an existing server. This is not performed on every account operation.
- Existing active tunnels should remain connected during routine API account operations; new authentication attempts see the updated account state.

## Validation status
- Static Bash/Python checks and mocked API workflow tests are required before packaging.
- A live Xray binary/systemd integration test is not available in this build environment. Treat this as a development build pending VPS validation.
