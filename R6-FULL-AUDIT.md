# SC Cassanova Tunneling V2 — R6 Full Audit

Tanggal audit: 1 November 2026  
Target branch: `r6-testing`  
Versi: `2.6.0-r6-dev`

## Ruang lingkup

Audit dilakukan pada source tree R6 yang tersedia di workspace, bukan pada server aktif. Pemeriksaan mencakup installer, updater, menu, Xray manager, SSH manager, Hysteria2/sing-box manager, Telegram bot, backup/restore, sertifikat/domain, systemd units, dokumentasi, dan test suite.

## Temuan penting dan perbaikan

1. Memperbaiki kesalahan parsing Bash pada validasi nama/brand yang dapat membuat menu dan Features gagal dijalankan.
2. Memindahkan database Hysteria2 ke `/var/lib/cassanova/hysteria2/users.json`, memvalidasi migrasi database lama, mengarsipkan database legacy di luar `/etc/sing-box`, dan menjaga permission root-only.
3. Mengubah pembentukan konfigurasi HY2 agar hanya mengganti inbound `hysteria2-in`; inbound Shadowsocks, outbounds, DNS, route, serta pengaturan root yang lain tetap dipertahankan.
4. Memperketat validasi tanggal HY2 agar tanggal kalender mustahil ditolak, termasuk tanggal seperti `2026-02-31`.
5. Memperbaiki restore agar group `root:sing-box` dan mode file config/certificate dipulihkan setelah ekstraksi aman dengan `--no-same-owner`.
6. Menambahkan validasi DNS/TLS, no-op saat domain yang sama dimasukkan, dan rollback domain agar kegagalan tidak meninggalkan Nginx mati atau sertifikat/config campuran.
7. Menambahkan rollback otomatis pada Certbot deploy hook jika penggantian beberapa file sertifikat gagal di tengah proses.
8. Memperbaiki backup root crontab serta menjaga installer HY2 agar tidak menghapus crontab yang tidak berhasil dibaca.
9. Memperbaiki state SSH ketika proses unlock gagal saat renewal; metadata tidak lagi mengklaim akun sudah terbuka padahal `passwd -u` gagal.
10. Menambahkan konfirmasi `RESTART` sebelum restart massal service inti.
11. Memperjelas fitur yang memang belum diimplementasikan agar tidak ditampilkan sebagai fungsi yang sudah berjalan.

## Hasil tes lokal

| Pemeriksaan | Hasil |
|---|---|
| `bash -n` seluruh file shell | Lulus |
| Compile seluruh 5 file Python | Lulus |
| Tes SSH expiry/idempotency | Lulus |
| Tes format/allowlist notifikasi offline | Lulus |
| Tes parser penggunaan bandwidth | Lulus |
| Tes schema tanggal HY2 dan merge konfigurasi | Lulus |
| Regresi `tests/static-check.sh` | Lulus |

Tes lokal tidak membuktikan konektivitas atau perilaku service sebenarnya.

## Status fitur dan batasannya

- **VLESS/VMess/Trojan:** alur manajemen akun menggunakan Xray HandlerService; wajib uji pada Xray aktif. Aktivasi API pertama dapat memerlukan satu restart Xray.
- **SSH:** manajemen akun Linux, lock/renew/expiry tersedia; backup panel tidak menyimpan database password Linux atau membuat ulang akun Linux pada VPS baru.
- **Hysteria2:** manajemen akun dan database/config preservation sudah diuji secara offline; SIGHUP/reload aktual, UDP/443, dan koneksi klien wajib diuji pada staging.
- **Telegram bot:** allowlist admin/private chat, singleton lock dan format notifikasi diperiksa offline; polling dan pengiriman sungguhan memerlukan API Telegram.
- **Bandwidth:** hanya untuk VLESS/VMess/Trojan melalui Xray StatsService. Polling kira-kira 60 detik sehingga pemakaian dapat sedikit melewati ambang.
- **Backup/restore:** checksum, allowlist path, snapshot dan validasi konfigurasi ada; perpindahan lintas VPS belum diuji langsung.
- **Domain/TLS:** validasi dan rollback telah ditambahkan; penerbitan/renewal sertifikat harus diuji dengan domain staging dan TCP/80 yang dapat dijangkau.
- **Belum tersedia:** OpenVPN, SSH-over-WebSocket khusus, WARP install/config, limit IP per akun, limit bandwidth untuk SSH/Hysteria2.

## Wajib dilakukan sebelum produksi

1. Terapkan pada `Testgemini-01` saja setelah backup terpisah. Jangan jalankan ulang `setup.sh` penuh pada VPS staging yang sudah memiliki konfigurasi Xray/Nginx.
2. Pastikan Xray/VLESS, Nginx TCP/443 dan Shadowsocks tetap berfungsi setelah patch HY2.
3. Jalankan `sing-box check`, uji CRUD/renew/expiry/recover Hysteria2 dan amati koneksi nyata saat SIGHUP.
4. Uji Certbot renewal hook dan perubahan domain pada domain uji.
5. Uji restore pada VPS sementara, bukan satu-satunya VPS produksi.
6. Periksa `systemctl --failed`, log, timers, serta TCP/UDP firewall VPS dan provider.

## Status perubahan

Perbaikan dalam paket audit ini hanya berada pada source tree lokal. Belum dipush ke GitHub dan belum dipasang pada Bot-01 maupun Testgemini-01. Sampai seluruh tes staging selesai, paket tetap berstatus pengujian (`r6-testing`), bukan rilis produksi.
