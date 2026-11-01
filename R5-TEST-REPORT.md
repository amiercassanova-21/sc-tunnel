# R5 Test Report

Date: 2026-11-01
Version: 2.5.0-r5-dev

## Passed in this development environment
- `bash -n` across all shell scripts.
- Python bytecode compilation across all Python files.
- Existing `tests/static-check.sh` suite.
- Bandwidth stats parser unit test using representative Xray `stat` blocks.
- JSON parse of the fresh-installer Xray configuration.
- `jq` checks for the loopback API inbound, API outbound, routing rule, HandlerService, StatsService, and level-0 traffic policy.
- `jq` migration simulation from the previous R4-style API declaration to the correct Xray API topology.
- `systemd-analyze verify` for the bandwidth service/timer unit syntax (service command substituted with `/bin/true` for local unit-file parsing).

## Not tested here
- The actual Xray binary is not installed in this environment. Therefore `xray run -test`, `xray api statsquery`, `xray api rmu`, and `xray api adu` were not exercised against a live Xray process.
- No live user traffic was generated; real per-user counters and quota lockout are not yet proven.
- No Telegram message was sent to a production bot.
- No installation or migration was performed on Ubuntu 22.04/24.04 or Debian 12/13 VMs.
- No real client reconnection test was performed after quota lockout or account recovery.

## Release status
DEVELOPMENT / NOT PRODUCTION-APPROVED. Run integration tests on a disposable VPS before deploying to a production host. In particular, verify the installed Xray version accepts the API inbound/routing schema and confirm the actual `statsquery` output format on that version.
