#!/usr/bin/env bash
set -Eeuo pipefail

CONF_DIR=/etc/bot
CONF_FILE="$CONF_DIR/bot.conf"
SERVICE=bot-tele

need_root() {
    if (( EUID != 0 )); then echo 'Jalankan menu ini sebagai root.' >&2; exit 1; fi
}

read_config() {
    TOKEN=''; ADMIN=''
    if [[ -r "$CONF_FILE" ]]; then
        while IFS='=' read -r key value; do
            case "$key" in TOKEN) TOKEN=$value ;; ADMIN) ADMIN=$value ;; esac
        done < "$CONF_FILE"
    fi
}

show_status() {
    printf '\nStatus layanan: '
    systemctl is-active "$SERVICE" 2>/dev/null || true
    if [[ -f "$CONF_FILE" ]]; then
        echo 'Konfigurasi bot: tersedia (token disembunyikan)'
        read_config
        [[ -n "$ADMIN" ]] && echo "Admin ID: $ADMIN" || echo 'Admin ID: belum diatur'
    else
        echo 'Konfigurasi bot: belum dibuat'
    fi
}

setup_bot() {
    local token admin tmp
    read -rp 'Bot Token dari @BotFather: ' token
    read -rp 'Admin Chat ID (boleh beberapa, pisahkan koma): ' admin
    if [[ ! "$token" =~ ^[0-9]{5,}:[A-Za-z0-9_-]{20,}$ ]]; then
        echo 'Format token tidak valid. Tidak ada perubahan.'; return 1
    fi
    if [[ ! "$admin" =~ ^-?[0-9]+(,-?[0-9]+)*$ ]]; then
        echo 'Admin ID harus berupa angka; pisahkan beberapa ID dengan koma.'; return 1
    fi
    # Verify token with Telegram before saving it.
    if ! curl -fsS --connect-timeout 8 --max-time 15 "https://api.telegram.org/bot${token}/getMe" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get("ok") else 1)'; then
        echo 'Telegram menolak token atau koneksi gagal. Konfigurasi lama tetap dipertahankan.'; return 1
    fi
    install -d -m 0700 "$CONF_DIR"
    tmp=$(mktemp "$CONF_DIR/.bot.conf.XXXXXX")
    chmod 0600 "$tmp"
    printf 'TOKEN=%s\nADMIN=%s\n' "$token" "$admin" > "$tmp"
    install -m 0600 "$tmp" "$CONF_FILE"
    rm -f "$tmp"
    systemctl restart "$SERVICE"
    echo 'Konfigurasi disimpan dengan permission 600 dan layanan direstart.'
}

need_root
while true; do
    clear
    echo '════════════════════════════════════════════'
    echo '          CASSANOVA TELEGRAM BOT'
    echo '════════════════════════════════════════════'
    show_status
    echo
    echo '1) Setup / Ganti Token dan Admin ID'
    echo '2) Restart Bot'
    echo '3) Stop Bot'
    echo '4) Test Notifikasi ke Admin'
    echo 'x) Kembali'
    read -rp 'Pilih: ' choice
    case "$choice" in
        1) setup_bot; read -rp 'Tekan Enter untuk lanjut...' _ ;;
        2) systemctl restart "$SERVICE" && echo 'Bot direstart.'; sleep 1 ;;
        3) systemctl stop "$SERVICE" && echo 'Bot dihentikan.'; sleep 1 ;;
        4)
            read_config
            if [[ -n "$TOKEN" && -n "$ADMIN" ]]; then
                IFS=, read -ra ids <<< "$ADMIN"
                for id in "${ids[@]}"; do
                    curl -fsS --connect-timeout 8 --max-time 15 -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" --data-urlencode "chat_id=$id" --data-urlencode 'text=Tes notifikasi Cassanova berhasil.' >/dev/null && echo "Terkirim ke $id" || echo "Gagal ke $id"
                done
            else echo 'Token/Admin belum diatur.'; fi
            read -rp 'Tekan Enter untuk lanjut...' _ ;;
        x|X) break ;;
        *) echo 'Pilihan tidak valid.'; sleep 1 ;;
    esac
done
