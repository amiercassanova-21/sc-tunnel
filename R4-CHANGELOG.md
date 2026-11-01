# R4 — SSH, Hysteria2 & Telegram Lifecycle Integration

## SSH
- Telegram notifications for create, renew, delete, password change, lock, unlock, and recovery/synchronization.
- Added daily expiry enforcement. Expired accounts are locked without restarting sshd.
- Recovery only reconciles existing Linux users. Passwords are not stored in the SSH metadata database and cannot be recovered.

## Hysteria2
- Telegram notifications for create, renew, delete, modify, lock, unlock, expiry, and recovery.
- Added recovery/rebuild from `/etc/sing-box/users.json`.
- Improved apply/rollback handling. Metadata-only changes skip sing-box restart if the generated runtime configuration is unchanged.
- User/credential/status changes still require sing-box restart and can interrupt existing Hysteria2 sessions.

## Cross-component
- Daily expiry orchestration now covers Xray, Hysteria2, and SSH.
- Notification helper formats recovery/expiry summaries and escapes HTML values.
- Installer and updater manifests include the SSH expiry helper.
