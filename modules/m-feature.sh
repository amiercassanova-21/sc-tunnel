#!/bin/bash
printf "\033[2J\033[H\033[3J"
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; BG_RED='\e[41;97m'
clear
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}   ${BG_RED}                SETTINGS & FEATURES           ${NC}   ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo -e "  ${GREEN}1.)${NC} Check Bandwidth (vnstat)"
echo -e "  ${GREEN}2.)${NC} Speedtest VPS"
echo -e "  ${GREEN}3.)${NC} Restart All Services"
echo -e "  ${GREEN}4.)${NC} Check Service Status"
echo -e "  ${GREEN}5.)${NC} Reboot VPS"
echo -e "  ${RED}x.)${NC} Kembali ke Menu Utama"
echo ""
read -rp "Select Options [1-5 or x] : " OPT
case $OPT in
    1) vnstat; read -n 1 -s -r -p "Tekan enter..."; m-feature ;;
    2) curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -; read -n 1 -s -r -p "Tekan enter..."; m-feature ;;
    3) systemctl restart xray nginx; echo -e "${GREEN}Services Berhasil Di-restart!${NC}"; sleep 1; m-feature ;;
    4) systemctl status xray nginx; read -n 1 -s -r -p "Tekan enter..."; m-feature ;;
    5) reboot ;;
    x|X) menu ;;
    *) m-feature ;;
esac
