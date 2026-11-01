# SC Cassanova Tunneling V2

Installer panel tunneling untuk **Ubuntu 22.04+** dan **Debian 12+** (rilis mayor berikutnya ikut didukung setelah dependensi kompatibel). OS lain dan versi lebih lama ditolak oleh installer.

## Persyaratan
- VPS fresh dengan akses root dan koneksi internet.
- Domain mengarah ke IP VPS jika ingin TLS publik Let's Encrypt.
- Port publik 80/443 (dan port tambahan yang memang diaktifkan) harus tersedia.

## Instalasi
```bash
apt-get update
apt-get install -y curl ca-certificates
bash <(curl -fsSL https://raw.githubusercontent.com/amiercassanova-21/sc-tunnel/r6-testing/setup.sh)
```

## Menu dan update
- Menu utama: `menu`
- Update panel: `update-sc` (mengunduh semua file ke staging, memvalidasi sintaks, membuat backup pra-update, lalu menerapkan perubahan; jika service bot yang sebelumnya aktif gagal restart, file dikembalikan).
- Versi terpasang dicatat di `/usr/local/share/cassanova/VERSION`. Backup pra-update disimpan di `/var/backups/cassanova/update/`.

## Xray Manager
VLESS, VMess, dan Trojan menggunakan manager bersama `/usr/bin/xray-manager`. Perubahan konfigurasi ditulis ke file sementara, diuji dengan `xray run -test`, dibackup, lalu diterapkan. Database akun berada di `/etc/xray/{vless,vmess,trojan}.db`.

## Catatan penting
- R5: limit bandwidth per akun VLESS/VMess/Trojan menggunakan Xray StatsService dan pemeriksaan systemd sekitar setiap 60 detik. Akun dikunci saat kuota tercapai; penggunaan dapat sedikit melewati batas di antara interval pemeriksaan. Limit IP per akun belum didukung dan input non-zero ditolak. Limit bandwidth untuk Hysteria2 dan SSH juga belum didukung.
- Gunakan domain yang benar untuk TLS. Instalasi berbasis IP atau kegagalan penerbitan Let's Encrypt menghasilkan sertifikat self-signed; sertifikat ini bukan CA-valid dan tidak cocok untuk koneksi klien yang memverifikasi TLS.
- Installer membuat snapshot pra-instalasi di `/var/backups/cassanova/pre-install-*/`.
- Installer hanya menambahkan konfigurasi reverse proxy milik panel di `/etc/nginx/conf.d/cassanova-xray.conf`; tidak menimpa `nginx.conf` dan tidak menghapus situs lain.
- Installer menambahkan blok menu bertanda ke `/root/.bashrc`; isi `.bashrc` lain dipertahankan.
- SSH-over-WebSocket custom dan Xray auto-kill/auto-expiry lama sengaja dinonaktifkan karena implementasi sebelumnya tidak aman. SSH standar tetap disediakan.
- Jalankan pada VPS baru/non-produksi terlebih dahulu. Backup tidak menggantikan pengujian restore.

## SSH Manager

The SSH account manager is implemented in `modules/m-ssh.sh` and is installed by
`setup.sh` as `/usr/bin/m-ssh`. It supports account creation, one-day trial,
expiry extension, deletion, password changes, lock/unlock, account listing,
account inspection, and active-login inspection.

SSH account metadata is stored in `/etc/ssh/.ssh.db` with mode `0600`. New
records do not store passwords in plaintext. On first run, legacy records are
normalized and any legacy plaintext password field is discarded. Account
operations are serialized with `flock`.

The manager creates non-interactive accounts using `/usr/sbin/nologin`; verify
that the server's `sshd_config` permits the forwarding mode you intend to
provide. This module does not install or reconfigure OpenSSH, Dropbear,
WebSocket proxies, firewall rules, or TLS listeners. It does not claim to
implement per-user IP or bandwidth limits.

## Telegram Bot Manager (revisi keamanan)

- Konfigurasi bot disimpan di `/etc/bot/bot.conf` dengan permission `0600` dan direktori `0700`.
- `ADMIN` wajib diisi dengan satu atau beberapa Telegram chat ID numerik (pisahkan dengan koma). Jika kosong/tidak valid, bot tidak memproses perintah apa pun.
- Bot hanya menyediakan aksi yang diizinkan: status, daftar akun, restart service yang sudah ditentukan, dan pembersihan akun expired.
- Eksekusi perintah sistem menggunakan daftar argumen `subprocess`, bukan `shell=True`.
- Token tidak ditampilkan pada menu status dan tidak dicatat ke log.

Setelah update, buka menu utama → Setup Bot Telegram → atur token dan Admin Chat ID. Pastikan bot hanya berjalan satu instance untuk token yang sama.


## Hysteria2 (tambahan)

Hysteria2 berjalan melalui **sing-box** sebagai service terpisah dari Xray. Listener menggunakan UDP/443; ini dapat berjalan bersamaan dengan Nginx TCP/443, tetapi firewall VPS dan firewall provider wajib mengizinkan UDP/443.

- Menu: `menu` → `5) HYSTERIA2`
- CLI: `hy2-manager create|custom|list|delete|renew|modify|lock|unlock|recover|check`
- Database: `/etc/sing-box/users.json` (root-only, permission 600)
- Konfigurasi: `/etc/sing-box/config.json`
- Service: `sing-box`
- Sertifikat harus CA-valid dan cocok dengan domain. Sertifikat self-signed tidak diterima oleh manager.
- Manager menggunakan sertifikat Let's Encrypt di `/etc/letsencrypt/live/<domain>/` bila tersedia, atau fallback ke `/etc/xray/xray.crt` dan `.key` setelah verifikasi CA.
- Akun kedaluwarsa diproses setiap hari oleh `cassanova-expire.timer` (systemd).

**Penting:** Jika installer hanya membuat sertifikat self-signed (misalnya domain belum mengarah ke IP VPS atau port 80 tidak dapat dijangkau), Hysteria2 belum dapat membuat akun. Perbaiki DNS dan terbitkan sertifikat TLS tepercaya terlebih dahulu.


### Memasang Hysteria2 pada VPS yang sudah terpasang

Jika VPS sudah menjalankan SC Cassanova versi sebelumnya, setelah seluruh file repository diperbarui jalankan sebagai root: `bash install-hysteria2.sh` (atau `install-hysteria2` bila file sudah dipasang ke `/usr/bin`). Script ini memasang sing-box, menyiapkan permission, menginstal manager, memperbarui menu dan integrasi daftar/status Telegram Bot. Script tidak menjalankan ulang seluruh installer VPS.


## Backup & Restore VPS Induk

Menu `FEATURES` menyediakan:
- `8) Backup Config VPS`: membuat satu arsip terbaru di `/root/Backup penting/Restore Vps induk/Cassanova_bot_untuk_restore_vps_induk.tar.gz` dan checksum `.sha256`. Backup lama dengan nama yang sama diganti secara atomik.
- `9) Restore Config VPS`: memverifikasi checksum, memeriksa isi arsip terhadap daftar path yang diizinkan, meminta konfirmasi eksplisit, membuat snapshot target sebelum restore, lalu memvalidasi Xray/sing-box sebelum restart layanan.

Arsip berisi konfigurasi panel, database akun, sertifikat TLS/private key, konfigurasi bot, unit service panel, dan script panel. Arsip bersifat SANGAT RAHASIA karena dapat memuat token bot, password akun, dan private key. Simpan dengan permission terbatas; jangan unggah ke repository publik.

Restore ditujukan untuk VPS baru Ubuntu 22.04+ atau Debian 12+. Arsip ini bukan image sistem penuh: `/etc/passwd`, `/etc/shadow`, group sistem, machine-id, konfigurasi jaringan, dan database paket tidak dipulihkan. Akun login Linux/SSH perlu dibuat ulang atau dimigrasikan terpisah. Sesudah restore, periksa domain/IP, firewall TCP dan UDP, port yang tersedia, konfigurasi Nginx/SSH, lalu status service.


## Update Manager & GitHub Synchronization

`update-sc` mengambil file runtime dan dokumentasi dari branch `main` repository GitHub. Semua file diunduh terlebih dahulu, lalu divalidasi (Bash/Python/VERSION). Sebelum pemasangan, updater membuat arsip pra-update beserta SHA256 di `/var/backups/cassanova/update/`. Pemasangan dilakukan melalui file sementara pada filesystem tujuan. Jika pemasangan gagal atau service `bot-tele` yang sebelumnya aktif gagal hidup kembali, updater mengembalikan file versi sebelumnya.

Updater tidak menghapus atau menimpa database akun, token bot, sertifikat TLS, atau konfigurasi layanan. `setup.sh` terbaru disimpan sebagai `/usr/local/share/cassanova/setup.sh` agar tidak mengganti installer yang sedang berjalan. `README.md` dan `RESTORE-GUIDE.md` disimpan di `/usr/local/share/cassanova/`.

See `CHANGELOG.md` for the current development changes.

## R4 — SSH, Hysteria2 & Telegram Lifecycle Integration

The daily `cassanova-expire` systemd timer now runs expiry enforcement for Xray, Hysteria2, and SSH. Xray account changes use HandlerService through a loopback dokodemo-door inbound and do not restart Xray after one-time API activation. The API configuration is validated with the Xray config tester. SSH expiry locks expired accounts without restarting sshd. Hysteria2 config changes may require a sing-box restart; metadata-only changes skip it when the effective config is identical.

Telegram notifications are delivered only to numeric IDs configured in `/etc/bot/bot.conf` (`ADMIN`). Notifications can contain credentials and links. Protect the bot config and Telegram admin accounts. SSH account passwords are not stored in the database, so SSH recovery cannot reconstruct missing Linux accounts or disclose old passwords.

## R1 — Installer & Core System Hardening

Perubahan R1 dijelaskan di `R1-CHANGELOG.md`. Menu utama sekarang merupakan script runtime, bukan generator. Sebelum menggunakan setup, jalankan pemeriksaan statis lokal:

```bash
bash tests/static-check.sh
```

GitHub Actions menjalankan pemeriksaan sintaks Bash/Python pada Ubuntu 22.04 dan 24.04. Pemeriksaan ini belum sama dengan pengujian instalasi pada VM. Debian 12/13, startup service, TLS, serta koneksi protokol masih harus diuji sebelum rilis produksi.


## R2 — Service & Reverse Proxy Manager

The `cassanova-service` command provides guarded service operations:

- `cassanova-service status` — service and configuration status.
- `cassanova-service validate` — validate Xray, sing-box, and Nginx configurations without restarting services.
- `cassanova-service ports` — display listening TCP/UDP sockets (`ss -lntup`). This cannot inspect provider-side firewall rules.
- `cassanova-service tls-check` — check certificate expiry, hostname, private-key match, and whether the leaf certificate chains to the system CA bundle.
- `cassanova-service restart SERVICE` — restart an allowlisted service; Xray, sing-box, and Nginx are validated first.
- `cassanova-service reload-nginx` — reload only after `nginx -t` succeeds and only if Nginx is already active.
- `cassanova-service restart-all` — validate all three configuration engines first, then restart installed core services. SSH is deliberately excluded from restart-all to avoid interrupting the administrator's management session.
- `cassanova-service ui` — interactive service menu. The main menu option 10 and FEATURES option 23 open this manager.

R2 does not automatically rewrite Nginx virtual hosts, change domains, issue certificates, open firewall ports, or modify Xray/sing-box transport definitions. Those actions need a separate transactional workflow and real VPS testing. A successful syntax/configuration check does not prove client connectivity.


## Xray live account changes (R3)

R3 uses the Xray `HandlerService` API for VLESS, VMess, and Trojan account operations. The API is bound to `127.0.0.1:10085` only. Fresh installs include it in the Xray config. On an existing R2 installation, activate it once from the relevant protocol menu using **14. Aktifkan API** (or `xray-manager vless api-enable`, replacing `vless` with `vmess`/`trojan`). This one-time activation requires an Xray restart; routine create, renew, delete, modify, lock, unlock, and recovery operations do not restart Xray.

Telegram lifecycle notifications are sent to the numeric IDs configured in `/etc/bot/bot.conf` under `ADMIN`. Notifications include credentials and links for administrator convenience. Keep that configuration root-only and use only trusted admin chats.


## R5 — Xray Per-User Bandwidth Enforcement

R5 adds Xray `StatsService` (with the required loopback API inbound, API outbound, and routing rule) and per-user traffic counters for VLESS, VMess, and Trojan. Xray StatsService indexes traffic by client email globally, so Xray usernames must be unique across VLESS, VMess, and Trojan. The manager now rejects new cross-protocol duplicates; legacy duplicates are skipped by the enforcer until renamed/reconciled. The `cassanova-bandwidth.timer` samples counters approximately every 60 seconds, accumulates usage in `/var/lib/cassanova/bandwidth-xray.json`, and removes/locks an account through HandlerService when its configured GB quota is reached. Use each protocol menu's **Edit Limit BW** to set a quota and **Reset Pemakaian BW** to reset its usage period. A one-time Xray restart may be required when enabling StatsService on an existing installation; ordinary account CRUD and quota polling do not restart Xray.

Quota enforcement is periodic, not instantaneous: traffic can exceed the configured threshold by the amount transferred between polls. Xray per-account concurrent-IP limits are not provided by this implementation; non-zero IP limit requests are rejected instead of silently storing a fake limit. Hysteria2/sing-box and SSH bandwidth/IP enforcement remain unsupported in this release. Do not advertise those limits as active.

The StatsService and enforcement logic have unit/static tests only in this package. Actual Xray CLI output, traffic accounting, quota lockout, and recovery must be validated on a disposable Ubuntu 22.04+/Debian 12+ VPS before production use.
