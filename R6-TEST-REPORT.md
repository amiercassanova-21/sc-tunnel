# SC Cassanova Tunneling V2 — R6 Test Report
# R6 Test Report

## Static checks performed
- Bash syntax validation across all `.sh` files.
- Python bytecode compilation across all `.py` files.
- Existing R1-R5 static/unit checks.
- R6 guard checks for SIGHUP reload path and unchanged-config no-op path.

## Not performed
- No sing-box daemon is installed in this build environment; no live SIGHUP reload was performed.
- No active Hysteria2 client session was used to observe continuity.
- No Ubuntu/Debian VPS installation or rollback test was performed.

## Operational caution
SIGHUP is supported by sing-box, but do not interpret this as a guarantee that every existing connection remains uninterrupted after every configuration update. The manager validates the candidate config before applying it and retains rollback copies. Emergency service recovery can still restart sing-box if it becomes inactive.
