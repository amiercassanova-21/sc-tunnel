# R1 — Installer & Core System Hardening

## Perubahan

- `menu.sh` sekarang merupakan executable runtime langsung, bukan generator heredoc.
- Installer membuat snapshot pra-instalasi di `/var/backups/cassanova/` sebelum perubahan konfigurasi.
- Installer tidak lagi menimpa `/etc/nginx/nginx.conf`, menghapus `sites-enabled`, atau menghapus `conf.d` milik administrator.
- Reverse proxy Cassanova dipasang sebagai `/etc/nginx/conf.d/cassanova-xray.conf`.
- Installer tidak lagi menimpa seluruh `/root/.bashrc`; hanya menambahkan blok bertanda dan idempotent.
- Dropbear menggunakan unit tersendiri `cassanova-dropbear.service`, bukan menimpa unit paket `dropbear.service`.
- SSH-over-WebSocket custom dinonaktifkan karena implementasi lama bukan implementasi WebSocket yang valid.
- Xray auto-kill dan auto-expiry lama dinonaktifkan karena penulisan ulang database tidak aman. Crontab administrator tidak disentuh.
- Konfigurasi Xray, Nginx, dan sing-box divalidasi sebelum service direstart.
- Service inti diperiksa satu per satu; installer tidak menampilkan sukses jika salah satu service gagal aktif.
- Geolokasi HTTP eksternal yang dipanggil setiap menu dibuka dihapus.
- Ditambahkan static checks dan GitHub Actions untuk Ubuntu 22.04/24.04.

## Batasan yang disengaja

- SSH-over-WebSocket belum tersedia. SSH biasa melalui OpenSSH/Dropbear tetap tersedia.
- Enforcement limit IP/bandwidth Xray belum dinyatakan aktif.
- Auto-expiry Xray dinonaktifkan sampai format database dan transaksi akun diperbaiki pada tahap Xray Manager.
- Sertifikat self-signed bukan sertifikat CA tepercaya. Hysteria2 memerlukan domain dan sertifikat valid agar klien tidak gagal verifikasi TLS.

## Verifikasi lokal

Jalankan:

```bash
bash tests/static-check.sh
```

Pemeriksaan statis tidak membuktikan service berjalan atau protokol berhasil tersambung. Belum ada uji VM/VPS nyata pada Ubuntu 22.04/24.04 dan Debian 12/13.
