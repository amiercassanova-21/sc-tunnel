#!/bin/bash
trap 'echo ""; exec /usr/bin/menu' SIGINT
printf "\033[2J\033[H\033[3J"
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; CYAN='\e[1;36m'; MAGENTA='\e[1;35m'
clear
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "                    ${MAGENTA}FEATURES${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}1.)${NC}  Check Bandwidth        ${GREEN}12.)${NC} Xray Outbounds"
echo -e "  ${GREEN}2.)${NC}  Set Auto Reboot        ${GREEN}13.)${NC} Rules Routing"
echo -e "  ${GREEN}3.)${NC}  Reboot VPS             ${GREEN}14.)${NC} Check Config Routing"
echo -e "  ${GREEN}4.)${NC}  Speed VPS              ${GREEN}15.)${NC} Restart Core Services"
echo -e "  ${GREEN}5.)${NC}  Restart Dropbear       ${GREEN}16.)${NC} Security BBR & SYN"
echo -e "  ${GREEN}6.)${NC}  Check All Service      ${GREEN}17.)${NC} Change Domain VPS"
echo -e "  ${GREEN}7.)${NC}  Setup BOT Telegram     ${GREEN}18.)${NC} Change Brand Name"
echo -e "  ${GREEN}8.)${NC}  Backup Config VPS      ${GREEN}19.)${NC} Clean Expired Now"
echo -e "  ${GREEN}9.)${NC}  Restore Config VPS     ${GREEN}20.)${NC} Enable Auto-Clean Timer"
echo -e "  ${GREEN}10.)${NC} Manages Domain & SNI   ${GREEN}21.)${NC} Information System"
echo -e "  ${GREEN}11.)${NC} Check WARP Status        ${GREEN}22.)${NC} Update Script"
echo -e "  ${GREEN}23.)${NC} Service & Port Manager"
echo -e "  ${RED}x.)${NC}  Back to Menu"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
read -rp " Pilih [1-23 atau x] : " OPT_F
case $OPT_F in
    1) clear; vnstat; read -n1 -srp "Enter..." ;;
    2)
       clear; echo -e "  1.) Jam 00:00\n  2.) Jam 03:00\n  3.) Matikan"
       read -rp " Pilih: " T
       CURRENT_CRON=$(crontab -l 2>/dev/null || true)
       CLEAN_CRON=$(printf '%s\n' "$CURRENT_CRON" | grep -vF '# CASSANOVA_AUTO_REBOOT' || true)
       case "$T" in
         1) { printf '%s\n' "$CLEAN_CRON"; echo '0 0 * * * /sbin/reboot # CASSANOVA_AUTO_REBOOT'; } | sed '/^$/d' | crontab -; echo -e "${GREEN}Auto reboot Cassanova aktif jam 00:00${NC}" ;;
         2) { printf '%s\n' "$CLEAN_CRON"; echo '0 3 * * * /sbin/reboot # CASSANOVA_AUTO_REBOOT'; } | sed '/^$/d' | crontab -; echo -e "${GREEN}Auto reboot Cassanova aktif jam 03:00${NC}" ;;
         3) printf '%s\n' "$CLEAN_CRON" | sed '/^$/d' | crontab -; echo -e "${RED}Auto reboot Cassanova dimatikan; cron lain tetap dipertahankan.${NC}" ;;
         *) echo 'Pilihan tidak valid.' ;;
       esac
       sleep 1 ;;
    3) read -rp " Reboot sekarang? [y/n]: " Y; [[ "$Y" == "y" ]] && reboot ;;
    4) clear
       if ! command -v speedtest-cli >/dev/null 2>&1; then
           echo 'Memasang speedtest-cli dari repository OS...'
           apt-get update && apt-get install -y speedtest-cli || { echo 'Instalasi speedtest-cli gagal.'; read -n1 -srp "Enter..."; exit 0; }
       fi
       speedtest-cli || echo 'Speed test gagal; periksa koneksi VPS.'
       read -n1 -srp "Enter..." ;;
    5) cassanova-service restart cassanova-dropbear; sleep 1 ;;
    6) cassanova-service status; read -n1 -srp "Enter..." ;;
    7) m-bot ;;
    8) /usr/bin/cassanova-backup; read -n1 -srp "Enter..." ;;
    9) /usr/bin/cassanova-restore; read -n1 -srp "Enter..." ;;
    10)
       DOMAIN=$(tr -d '[:space:]' < /etc/xray/domain.txt 2>/dev/null || true)
       read -rp " Custom SNI (Enter = gunakan domain utama ${DOMAIN}): " S
       S=${S,,}; [[ -n "$S" ]] || S=$DOMAIN
       if [[ ! "$S" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$ ]]; then
           echo -e "${RED}Format SNI tidak valid. Domain utama tidak diubah.${NC}"
       elif ! openssl x509 -in /etc/xray/xray.crt -noout -checkhost "$S" >/dev/null 2>&1; then
           echo -e "${RED}SNI tidak tercakup sertifikat TLS saat ini. Terbitkan sertifikat yang cocok atau gunakan domain utama.${NC}"
       else
           printf '%s\n' "$S" > /etc/xray/sni.txt
           chmod 0644 /etc/xray/sni.txt
           echo -e "${GREEN}SNI tersimpan: $S. Domain utama tetap: $DOMAIN${NC}"
       fi
       sleep 2 ;;
    11) curl -fsS --max-time 10 https://www.cloudflare.com/cdn-cgi/trace | grep '^warp=' || echo 'Status WARP tidak dapat dideteksi.'; read -n1 -srp "Enter..." ;;
    12) jq '.outbounds' /usr/local/etc/xray/config.json; read -n1 -srp "Enter..." ;;
    13) jq '.routing.rules // []' /usr/local/etc/xray/config.json; read -n1 -srp "Enter..." ;;
    14) cassanova-service validate; read -n1 -srp "Enter..." ;;
    15) cassanova-service restart-all; sleep 1 ;;
    16)
       install -d -m 0755 /etc/sysctl.d
       AVAILABLE_CC=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)
       if grep -qw bbr <<< "$AVAILABLE_CC"; then
           cat > /etc/sysctl.d/99-cassanova.conf <<'SYSCTL'
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_syncookies=1
SYSCTL
       else
           cat > /etc/sysctl.d/99-cassanova.conf <<'SYSCTL'
net.ipv4.tcp_syncookies=1
SYSCTL
       fi
       if sysctl --system >/dev/null 2>&1 && [[ "$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)" == 1 ]]; then
           CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)
           if [[ "$CURRENT_CC" == bbr ]]; then
               echo -e "${GREEN}SYN Cookies aktif dan BBR aktif. Pengaturan disimpan permanen.${NC}"
           else
               echo -e "${YELLOW}SYN Cookies aktif. Kernel tidak mendukung/mengaktifkan BBR (saat ini: $CURRENT_CC). Pengaturan aman tetap disimpan.${NC}"
           fi
       else
           echo -e "${RED}Kernel/VPS menolak pengaturan SYN Cookies. Periksa /etc/sysctl.d/99-cassanova.conf.${NC}"
       fi
       sleep 2 ;;
    17) /usr/bin/cassanova-domain || echo -e "${RED}Domain tidak diubah. Periksa pesan error di atas.${NC}"; read -n1 -srp "Enter..." ;;
    18)
       read -rp " Brand Baru (maks. 32 karakter; huruf/angka/spasi/._+-): " B
       BRAND_PATTERN='^[A-Za-z0-9][-A-Za-z0-9 ._+]{0,31}$'
       if [[ "$B" =~ $BRAND_PATTERN ]]; then
           printf '%s\n' "$B" > /etc/xray/brand.txt; chmod 0644 /etc/xray/brand.txt
           echo -e "${GREEN}Brand tersimpan.${NC}"
       else
           echo -e "${RED}Format brand tidak valid atau terlalu panjang.${NC}"
       fi
       sleep 1 ;;
    19) /usr/bin/cassanova-expire; read -n1 -srp "Enter..." ;;
    20) systemctl enable --now cassanova-expire.timer && echo -e "${GREEN}Systemd auto-expiry aktif. Jadwal:${NC}" && systemctl list-timers cassanova-expire.timer --no-pager || echo -e "${RED}Timer gagal diaktifkan. Periksa unit cassanova-expire.timer.${NC}"; read -n1 -srp "Enter..." ;;
    21) free -m; df -h /; uptime; read -n1 -srp "Enter..." ;;
    22) /usr/bin/update-sc ;;
    23) cassanova-service ui ;;
    x|X) menu ;;
    *) m-feature ;;
esac