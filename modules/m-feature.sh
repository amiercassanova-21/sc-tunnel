cat << 'EOF' > /root/patch-updater.sh
#!/bin/bash
NC='\e[0m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'

echo -e "${YELLOW}[1/3] Mengubah Versi Menu ke v.1.0.0 cstun...${NC}"
sed -i 's/VERSION=".*"/VERSION="v.1.0.0 cstun"/g' /usr/bin/menu

echo -e "${YELLOW}[2/3] Membangun Modul Update (Sinkronisasi GitHub)...${NC}"
cat << 'UP_EOF' > /usr/bin/update-sc
#!/bin/bash
NC='\e[0m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'
clear
echo -e "${YELLOW}Mengunduh versi terbaru dari GitHub Cassanova...${NC}"
REPO="https://raw.githubusercontent.com/amiercassanova-21/sc-tunnel/main"

# Unduh ke temporary file untuk mencegah kerusakan jika link gagal
wget -qO /tmp/menu "${REPO}/menu.sh"
if [ $? -eq 0 ]; then
    mv /tmp/menu /usr/bin/menu
    wget -qO /usr/bin/m-vless "${REPO}/modules/m-vless.sh"
    wget -qO /usr/bin/m-vmess "${REPO}/modules/m-vmess.sh"
    wget -qO /usr/bin/m-trojan "${REPO}/modules/m-trojan.sh"
    wget -qO /usr/bin/m-ssh "${REPO}/modules/m-ssh.sh"
    wget -qO /usr/bin/m-feature "${REPO}/modules/m-feature.sh"
    wget -qO /usr/bin/m-bot "${REPO}/modules/m-bot.sh"
    chmod +x /usr/bin/menu /usr/bin/m-* /usr/bin/update-sc
    echo -e "${GREEN}Berhasil! Script telah diperbarui ke versi GitHub terbaru.${NC}"
else
    echo -e "${RED}Gagal mengunduh. Pastikan link GitHub valid.${NC}"
fi
sleep 2
menu
UP_EOF
chmod +x /usr/bin/update-sc

echo -e "${YELLOW}[3/3] Menambahkan Tombol Update di m-feature...${NC}"
cat << 'FEAT_EOF' > /usr/bin/m-feature
#!/bin/bash
trap 'echo ""; /usr/bin/menu; exit 0' SIGINT
printf "\033[2J\033[H\033[3J"
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; CYAN='\e[1;36m'; MAGENTA='\e[1;35m'
clear
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "                    ${MAGENTA}FEATURES${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}1.)${NC}  Check Bandwidth        ${GREEN}12.)${NC} Outbounds Routing"
echo -e "  ${GREEN}2.)${NC}  Set Auto Reboot        ${GREEN}13.)${NC} Rules Routing"
echo -e "  ${GREEN}3.)${NC}  Reboot VPS             ${GREEN}14.)${NC} Check Config Routing"
echo -e "  ${GREEN}4.)${NC}  Speed VPS              ${GREEN}15.)${NC} Restart All Service"
echo -e "  ${GREEN}5.)${NC}  Restart Dropbear       ${GREEN}16.)${NC} Security BBR & SYN"
echo -e "  ${GREEN}6.)${NC}  Check All Service      ${GREEN}17.)${NC} Change Domain VPS"
echo -e "  ${GREEN}7.)${NC}  Setup BOT Telegram     ${GREEN}18.)${NC} Change Brand Name"
echo -e "  ${GREEN}8.)${NC}  Backup Config VPS      ${GREEN}19.)${NC} Clean Expired Now"
echo -e "  ${GREEN}9.)${NC}  Restore Config VPS     ${GREEN}20.)${NC} Set Auto-Clean Cron"
echo -e "  ${GREEN}10.)${NC} Manages Domain & SNI   ${GREEN}21.)${NC} Information System"
echo -e "  ${GREEN}11.)${NC} WARP Cloudflare        ${GREEN}22.)${NC} Update Script"
echo -e "  ${RED}x.)${NC}  Back to Menu"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
read -rp " Pilih [1-22 atau x] : " OPT_F
trap 'echo ""; /usr/bin/m-feature; exit 0' SIGINT
case $OPT_F in
    1) clear; vnstat; read -n1 -srp "Enter..." ;;
    2) 
       clear; echo -e "  1.) Jam 00:00\n  2.) Jam 03:00\n  3.) 12 Jam Sekali\n  4.) Matikan"
       read -rp " Pilih: " T
       if [[ "$T" == "1" ]]; then (crontab -l 2>/dev/null | grep -v "/sbin/reboot"; echo "0 0 * * * /sbin/reboot") | crontab -; echo -e "${GREEN}Aktif Jam 00:00${NC}"
       elif [[ "$T" == "2" ]]; then (crontab -l 2>/dev/null | grep -v "/sbin/reboot"; echo "0 3 * * * /sbin/reboot") | crontab -; echo -e "${GREEN}Aktif Jam 03:00${NC}"
       elif [[ "$T" == "4" ]]; then (crontab -l 2>/dev/null | grep -v "/sbin/reboot") | crontab -; echo -e "${RED}Dimatikan${NC}"; fi
       sleep 1 ;;
    3) read -rp " Reboot sekarang? [y/n]: " Y; [[ "$Y" == "y" ]] && reboot ;;
    4) clear; curl -sL https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -; read -n1 -srp "Enter..." ;;
    5) systemctl restart dropbear; echo -e "${GREEN}Dropbear Restarted!${NC}"; sleep 1 ;;
    6) 
       clear; for s in xray nginx ws-ssh dropbear fail2ban vnstat; do
       systemctl is-active --quiet "$s" && echo -e " $s : ${GREEN}RUNNING${NC}" || echo -e " $s : ${RED}STOPPED${NC}"
       done; read -n1 -srp "Enter..." ;;
    7) m-bot ;;
    8) tar -czf /root/Backup-VPS-$(date +%Y%m%d).tar.gz /etc/xray /etc/ssh /etc/nginx/conf.d 2>/dev/null; echo -e "${GREEN}Tersimpan di /root/${NC}"; sleep 1 ;;
    9) 
       read -rp " Nama file backup (/root/...): " F
       [[ -f "$F" ]] && tar -xzf "$F" -C / && systemctl restart xray nginx && echo -e "${GREEN}Direstore!${NC}" || echo -e "${RED}Gagal${NC}"; sleep 1 ;;
    10) 
       read -rp " Domain Utama (Enter=Tetap): " D; [[ -n "$D" ]] && echo "$D" > /etc/xray/domain.txt
       read -rp " Custom Bug SNI (Enter=Sama): " S; [[ -n "$S" ]] && echo "$S" > /etc/xray/sni.txt || cp /etc/xray/domain.txt /etc/xray/sni.txt
       echo -e "${GREEN}Tersimpan!${NC}"; sleep 1 ;;
    11) curl -sS https://www.cloudflare.com/cdn-cgi/trace | grep "warp="; read -n1 -srp "Enter..." ;;
    12|13) jq '.outbounds' /usr/local/etc/xray/config.json; read -n1 -srp "Enter..." ;;
    14) xray run -test -config /usr/local/etc/xray/config.json; read -n1 -srp "Enter..." ;;
    15) systemctl restart xray nginx ws-ssh dropbear fail2ban; echo -e "${GREEN}Semua direstart!${NC}"; sleep 1 ;;
    16) sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null; sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null; echo -e "${GREEN}Keamanan Aktif!${NC}"; sleep 1 ;;
    17) 
       read -rp " Domain Baru: " ND; [[ -z "$ND" ]] && exit 0
       echo "$ND" > /etc/xray/domain.txt; echo "$ND" > /etc/xray/sni.txt
       systemctl stop nginx; certbot certonly --standalone --agree-tos --register-unsafely-without-email -d "$ND" --non-interactive 2>/dev/null
       cp "/etc/letsencrypt/live/${ND}/fullchain.pem" /etc/xray/xray.crt 2>/dev/null
       cp "/etc/letsencrypt/live/${ND}/privkey.pem" /etc/xray/xray.key 2>/dev/null
       systemctl restart nginx xray; echo -e "${GREEN}Domain diubah!${NC}"; sleep 1 ;;
    18) read -rp " Brand Baru: " B; [[ -n "$B" ]] && echo "$B" > /etc/xray/brand.txt; echo -e "${GREEN}Tersimpan!${NC}"; sleep 1 ;;
    19) /usr/bin/auto-exp 2>/dev/null; echo -e "${GREEN}Dibersihkan!${NC}"; sleep 1 ;;
    20) (crontab -l 2>/dev/null | grep -v "auto-exp"; echo "0 0 * * * /usr/bin/auto-exp") | crontab -; echo -e "${GREEN}Cron aktif!${NC}"; sleep 1 ;;
    21) free -m; df -h /; uptime; read -n1 -srp "Enter..." ;;
    22) update-sc ;;
    x|X) menu ;;
    *) m-feature ;;
esac
FEAT_EOF
chmod +x /usr/bin/m-feature

echo -e "${GREEN}Selesai! Versi sekarang: v.1.0.0 cstun.${NC}"
EOF

bash /root/patch-updater.sh
rm -f /root/patch-updater.sh
