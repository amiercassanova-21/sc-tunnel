# Panduan Backup & Restore SC Cassanova Tunneling V2

## Backup pada VPS sumber
1. Login sebagai `root`.
2. Jalankan `menu` → `FEATURES` → `8) Backup Config VPS`, atau jalankan `cassanova-backup`.
3. Arsip terbaru dibuat di:
   `/root/Backup penting/Restore Vps induk/Cassanova_bot_untuk_restore_vps_induk.tar.gz`
4. File `.sha256` dibuat berdampingan. Salin kedua file ke penyimpanan aman di luar VPS.

## Persiapan VPS tujuan
1. Siapkan VPS baru dengan Ubuntu 22.04+ atau Debian 12+.
2. Pastikan arsitektur dan paket sistem kompatibel; install SC Cassanova pada VPS tujuan terlebih dahulu agar binary inti (`xray`, `sing-box`) dan dependensi tersedia.
3. Transfer arsip dan file `.sha256` ke VPS tujuan.
4. Jalankan `cassanova-restore /path/ke/Cassanova_bot_untuk_restore_vps_induk.tar.gz`.
5. Baca peringatan, lalu ketik `RESTORE` untuk menyetujui.
6. Periksa `systemctl --failed`, `systemctl status xray sing-box nginx ws-ssh bot-tele`, domain, firewall TCP/UDP, dan log service.

## Yang dicadangkan
Konfigurasi Xray dan database VLESS/VMess/Trojan, konfigurasi sing-box dan database Hysteria2, konfigurasi bot, konfigurasi Nginx, sertifikat Let's Encrypt, konfigurasi SSH/Dropbear tertentu, unit service panel, script panel, serta crontab root.

## Batasan penting
- Ini backup konfigurasi aplikasi/panel, bukan image VPS atau backup seluruh OS.
- `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow`, konfigurasi jaringan, `machine-id`, dan database paket tidak dipulihkan.
- Akun login Linux yang dibuat untuk SSH tidak otomatis dibuat ulang. Migrasikan/rebuat akun tersebut secara terpisah.
- Periksa ulang domain dan IP tujuan, firewall provider, port yang bentrok, serta sertifikat TLS setelah migrasi.
- Arsip berisi credential akun, token Telegram, dan private key TLS. Jangan pernah commit atau upload ke repository publik.
- Restore membuat snapshot file target sebelum perubahan di `/var/backups/cassanova/pre-restore/`.
- R5 juga mencadangkan `/var/lib/cassanova/bandwidth-xray.json` bila tersedia, agar akumulasi pemakaian kuota VLESS/VMess/Trojan tidak kembali ke nol setelah migrasi.
- Unit `cassanova-bandwidth.service` dan `cassanova-bandwidth.timer` ikut dicadangkan. Timer hanya diaktifkan setelah restore bila konfigurasi StatsService dan API loopback tersedia.
