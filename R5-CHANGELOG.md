# R5 — Xray Bandwidth Enforcement & API Repair

## Implemented
- Corrected Xray API topology: API service now has a loopback-only `dokodemo-door` inbound (`127.0.0.1:10085`), the API freedom outbound, and a routing rule. The earlier R3/R4 configuration only declared a non-standard `api.listen` property and did not define the complete Xray API inbound/outbound/routing path. Existing installations are migrated by `xray-manager <protocol> api-enable`.
- Enabled `HandlerService` and `StatsService`, plus level-0 user uplink/downlink counters.
- Added `cassanova-bandwidth` sampler and a systemd timer running approximately every 60 seconds.
- Accumulates per-user traffic in `/var/lib/cassanova/bandwidth-xray.json` with mode 0600.
- When a VLESS/VMess/Trojan GB quota is reached, validates a candidate config, backs up the current config, removes the user from runtime via HandlerService, removes that user from the persisted Xray config, and marks the database record locked. No Xray restart is requested for the enforcement operation.
- Added Telegram event `bandwidth_limit`.
- Added `Reset Pemakaian BW` to the VLESS, VMess, and Trojan menus.
- Rejects non-zero Xray per-account IP limits rather than storing a misleading value.
- Enforces globally unique usernames across VLESS/VMess/Trojan for new accounts because Xray StatsService keys counters by client email. Legacy duplicate usernames are skipped by the enforcer to avoid cross-protocol mis-accounting.
- Backup/restore now includes bandwidth usage state, the enforcer binary, and systemd timer/service units.

## Explicit limitations
- The Xray bandwidth check is periodic, not instantaneous. Usage can overshoot the configured quota between timer runs.
- The feature applies only to VLESS, VMess, and Trojan managed by this Xray instance.
- Per-account IP limits are not implemented.
- Hysteria2/sing-box and SSH per-user IP/bandwidth enforcement are not implemented.
- Renewing an account does not automatically reset its quota; use `Reset Pemakaian BW` when starting a new quota period.

## Safety
- StatsService API remains bound to loopback only.
- The one-time `api-enable` migration validates the candidate Xray config before installing it and requires one Xray restart to activate/fix the API topology on older installations.
- Normal account create/renew/delete/lock/unlock and quota enforcement use runtime API operations; they do not restart Xray.
