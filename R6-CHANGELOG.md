# SC Cassanova Tunneling V2 — R6
# R6 — Hysteria2 graceful reload

- `hy2-manager` now requests `SIGHUP` for a changed, pre-validated sing-box configuration rather than doing a routine `systemctl restart`.
- Unchanged runtime configuration still causes no reload.
- On a failed signal operation, previous DB/config files are restored. If sing-box becomes inactive after reload, rollback is applied and a best-effort service restart is attempted as an emergency recovery path.
- The Hysteria2 standalone installer message now describes the reload behavior.

This is not a claim of zero packet/session disruption. A config reload can affect connections depending on sing-box version and the type of change. Validate on a staging VPS.
