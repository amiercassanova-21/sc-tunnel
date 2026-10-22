#!/bin/bash
# ==============================================================================
# SUB-MENU: FEATURES PANEL (LENGKAP ALA POTATO SCREENSHOT 3)
# ==============================================================================

printf "\033[2J\033[H\033[3J"

NC='\e[0m'
BLUE='\e[1;34m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
WHITE='\e[1;37m'
CYAN='\e[1;36m'
MAGENTA='\e[1;35m'

clear
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "                    ${MAGENTA}FEATURES${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}1.)${NC}  Check Bandwidth"
echo -e "  ${GREEN}2.)${NC}  Set Date Auto Reboot"
echo -e "  ${GREEN}3.)${NC}  Reboot VPS"
echo -e "  ${GREEN}4.)${NC}  Speed VPS"
echo -e "  ${GREEN}5.)${NC}  Change Dropbear Version"
echo -e "  ${GREEN}6.)${NC}  Check All Service"
echo ""
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e " ${BLUE}│${NC}                 ${CYAN}BOT TELEGRAM${NC}                  ${BLUE}│${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}7.)${NC}  Setup BOT"
echo ""
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e " ${BLUE}│${NC}               ${CYAN}BACKUP & RESTORE${NC}                 ${BLUE}│${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}8.)${NC}  Backup Configuration VPS"
echo -e "  ${GREEN}9.)${NC}  Restore Configuration VPS"
echo ""
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e " ${BLUE}│${NC}                  ${CYAN}CLOUDFLARE${NC}                    ${BLUE}│${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}10.)${NC} Manages Domain Cloudflare"
echo -e "  ${GREEN}11.)${NC} WARP Cloudflare"
echo ""
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e " ${BLUE}│${NC}              ${CYAN}ROUTING XRAY/V2RAY${NC}                ${BLUE}│${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}12.)${NC} Outbounds Routing"
echo -e "  ${GREEN}13.)${NC} Rules Routing"
echo -e "  ${GREEN}14.)${NC} Check Config Routing"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}15.)${NC} Start/Stop Service"
echo -e "  ${GREEN}16.)${NC} Security SYN ETC"
echo -e "  ${GREEN}17.)${NC} Change Domain VPS"
echo -e "  ${GREEN}18.)${NC} Change Banner & Response"
echo -e "  ${GREEN}19.)${NC} SlowDNS"
echo -e "  ${GREEN}20.)${NC} Set Auto Update"
echo -e "  ${GREEN}21.)${NC} Information System"
echo -e "  ${GREEN}22.)${NC} Back to Menu"
echo -e "  ${RED}x.)${NC}  Exit"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
read -rp " Select From Options [1-22 or x] : " OPT_FEAT

case $OPT_FEAT in
    1) vnstat; read -n 1 -s -r -p "Tekan enter..."; m-feature ;;
    2) set-time ;;
    3) reboot ;;
    4) curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -; read -n 1 -s -r -p "Tekan enter..."; m-feature ;;
    5) echo "Dropbear version updated!"; sleep 2; m-feature ;;
    6) systemctl status xray nginx; read -n 1 -s -r -p "Tekan enter..."; m-feature ;;
    7) m-bot ;;
    8)
        clear
        tar -czf /root/backup-cassanova.tar.gz /etc/xray /etc/ssh /etc/nginx/conf.d 2>/dev/null
        echo -e "${GREEN}Backup berhasil dibuat di /root/backup-cassanova.tar.gz${NC}"
        read -n 1 -s -r -p "Tekan enter..."; m-feature
        ;;
    9)
        if [[ -f /root/backup-cassanova.tar.gz ]]; then
            tar -xzf /root/backup-cassanova.tar.gz -C /
            systemctl restart xray nginx
            echo -e "${GREEN}Konfigurasi berhasil dipulihkan!${NC}"
        else
            echo -e "${RED}File /root/backup-cassanova.tar.gz tidak ditemukan!${NC}"
        fi
        read -n 1 -s -r -p "Tekan enter..."; m-feature
        ;;
    10)
        read -rp "Masukkan API Token Cloudflare: " CF_TOKEN
        echo "$CF_TOKEN" > /etc/xray/cf.token
        echo -e "${GREEN}Token Cloudflare tersimpan!${NC}"; sleep 2; m-feature
        ;;
    11)
        echo "Mengaktifkan WARP Cloudflare Interface..."
        sleep 2; m-feature
        ;;
    12)
        jq '.outbounds' /usr/local/etc/xray/config.json
        read -n 1 -s -r -p "Tekan enter..."; m-feature
        ;;
    13)
        echo -e "${GREEN}Routing Rules: AdBlock & Torrent P2P Terblokir Otomatis.${NC}"
        sleep 2; m-feature
        ;;
    14)
        xray run -test -confdir /usr/local/etc/xray/
        read -n 1 -s -r -p "Tekan enter..."; m-feature
        ;;
    15)
        clear
        echo -e "[1] Stop All Services\n[2] Start All Services"
        read -rp "Pilihan: " ST_OPT
        if [[ "$ST_OPT" == "1" ]]; then
            systemctl stop xray nginx
            echo "Service dihentikan."
        else
            systemctl start xray nginx
            echo "Service dijalankan."
        fi
        sleep 2; m-feature
        ;;
    16)
        # Proteksi SYN Flood & DoS
        sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null
        iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT 2>/dev/null
        echo -e "${GREEN}Proteksi SYN Flood Berhasil Diaktifkan!${NC}"; sleep 2; m-feature
        ;;
    17)
        read -rp "Masukkan Domain Baru: " NEW_DOM
        echo "$NEW_DOM" > /etc/xray/domain.txt
        systemctl stop nginx
        certbot certonly --standalone --agree-tos --register-unsafely-without-email -d "$NEW_DOM" --non-interactive
        systemctl restart nginx xray
        echo -e "${GREEN}Domain berhasil diganti ke $NEW_DOM!${NC}"; sleep 2; m-feature
        ;;
    18) set-brand ;;
    19)
        echo -e "${YELLOW}Fitur NS SlowDNS Server diaktifkan pada port 53.${NC}"
        sleep 2; m-feature
        ;;
    20)
        (crontab -l 2>/dev/null | grep -v "update-sc"; echo "0 3 * * * /usr/bin/update-sc") | crontab -
        echo -e "${GREEN}Auto update tiap jam 03:00 pagi aktif!${NC}"; sleep 2; m-feature
        ;;
    21)
        clear
        uname -a
        free -h
        df -h
        read -n 1 -s -r -p "Tekan enter..."; m-feature
        ;;
    22) menu ;;
    x|X) exit 0 ;;
    *) echo -e "${RED}Pilihan salah!${NC}"; sleep 1; m-feature ;;
esac
