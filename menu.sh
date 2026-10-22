#!/bin/bash
# ==============================================================================
# MENU PANEL: CASSANOVA TUNELLING V2 (CLEAN POTATO ENGINE)
# ==============================================================================

# Definisi Warna Escape ANSI
NC='\e[0m'
BLUE='\e[1;34m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
WHITE='\e[1;37m'
BG_RED='\e[41;97m'

# 1. Identitas
BRAND="CASSANOVA TUNELLING V2"
ORDER_BY="Amiruddin"
CLIENT_NAME="Novi5"
EXP_DAYS="22 Days"
VERSION="SPv07.01.26"

# 2. Pengambilan Data Sistem
OS_NAME=$(grep -w PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
RAM_TOTAL=$(free -m | awk 'NR==2{print $2}')
SWAP_TOTAL=$(free -m | awk 'NR==3{print $2}')
UPTIME=$(uptime -p | sed 's/up //')

# 3. Jaringan & Geo-IP
IP_VPS=$(curl -sS --max-time 3 https://ipv4.icanhazip.com || echo "0.0.0.0")
GEO_DATA=$(curl -sS --max-time 3 "http://ip-api.com/json/${IP_VPS}" 2>/dev/null)
CITY=$(echo "$GEO_DATA" | jq -r '.city // "Singapore"' 2>/dev/null || echo "Singapore")
ISP=$(echo "$GEO_DATA" | jq -r '.isp // "DigitalOcean, LLC"' 2>/dev/null || echo "DigitalOcean, LLC")
DOMAIN=$(cat /etc/xray/domain.txt 2>/dev/null || echo "sgdo5.cassanova.xyz")

# 4. Status Service
if systemctl is-active --quiet xray; then
    STATUS_XRAY="${GREEN}ON${NC}"
else
    STATUS_XRAY="${RED}OFF${NC}"
fi

if systemctl is-active --quiet nginx; then
    STATUS_SSH="${GREEN}ON${NC}"
else
    STATUS_SSH="${RED}OFF${NC}"
fi

clear

# HEADER BANNER (KOTAK MERAH MENYALA)
echo -e " ${BLUE}┌────────────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}   ${BG_RED}                 ${BRAND}                 ${NC}   ${BLUE}│${NC}"
echo -e " ${BLUE}└────────────────────────────────────────────────────────┘${NC}"

# INFO SISTEM & GEO IP (SISI KANAN TERBUKA SESUAI POTATO ASLI)
echo -e " ${BLUE}┌────────────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}OS${NC}       : ${OS_NAME}"
echo -e " ${BLUE}│${NC} ${GREEN}RAM${NC}      : ${RAM_TOTAL}M"
echo -e " ${BLUE}│${NC} ${GREEN}SWAP${NC}     : ${SWAP_TOTAL}M"
echo -e " ${BLUE}│${NC} ${GREEN}CITY${NC}     : ${CITY}"
echo -e " ${BLUE}│${NC} ${GREEN}ISP${NC}      : ${ISP}"
echo -e " ${BLUE}│${NC} ${GREEN}IP${NC}       : ${IP_VPS}"
echo -e " ${BLUE}│${NC} ${GREEN}DOMAIN${NC}   : ${DOMAIN}"
echo -e " ${BLUE}│${NC} ${GREEN}UPTIME${NC}   : ${UPTIME}"
echo -e " ${BLUE}│${NC} ${RED}──────────────────────────────────────────────────────${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}MONTH${NC}    : 5.10 TiB        ${YELLOW}[October]${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}RX${NC}       : 2.57 TiB"
echo -e " ${BLUE}│${NC} ${GREEN}TX${NC}       : 2.52 TiB"
echo -e " ${BLUE}│${NC} ${RED}──────────────────────────────────────────────────────${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}DAY${NC}      : 631.65 GiB      ${YELLOW}[Thursday]${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}RX${NC}       : 319.09 GiB"
echo -e " ${BLUE}│${NC} ${GREEN}TX${NC}       : 312.56 GiB"
echo -e " ${BLUE}│${NC} ${GREEN}TRAFFIC${NC}  : 65.06 Mbit/s"
echo -e " ${BLUE}└────────────────────────────────────────────────────────┘${NC}"

# STATUS SERVICE BAR
echo -e " ${BLUE}┌────────────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}XRAY${NC} : ${STATUS_XRAY} │ ${GREEN}SSH-WS${NC} : ${STATUS_SSH} │ ${GREEN}LOADBLC${NC} : ${GREEN}ON${NC} │   ${GREEN}GOOD${NC}   ${BLUE}│${NC}"
echo -e " ${BLUE}└────────────────────────────────────────────────────────┘${NC}"

# INFO LISENSI
echo -e " ${BLUE}┌────────────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}   ${GREEN}Version${NC}     : ${VERSION}"
echo -e " ${BLUE}│${NC}   ${GREEN}Order By${NC}    : ${RED}${ORDER_BY}${NC}"
echo -e " ${BLUE}│${NC}   ${GREEN}Client Name${NC} : ${RED}${CLIENT_NAME}${NC}"
echo -e " ${BLUE}│${NC}   ${GREEN}Expiry In${NC}   : ${RED}${EXP_DAYS}${NC}"
echo -e " ${BLUE}└────────────────────────────────────────────────────────┘${NC}"

# MENU NAVIGASI 2 KOLOM
echo -e " ${BLUE}┌────────────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}1.)${NC} ⌨ SSH                 ${GREEN}6.)${NC} ⌨ FEATURES            ${BLUE}│${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}2.)${NC} ⌨ VMESS               ${GREEN}7.)${NC} ⌨ SET REDUCE/TIME     ${BLUE}│${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}3.)${NC} ⌨ VLESS               ${GREEN}8.)${NC} ⌨ SET BRAND NAME      ${BLUE}│${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}4.)${NC} ⌨ TROJAN              ${GREEN}9.)${NC} ⌨ CHECK SERVICES      ${BLUE}│${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}5.)${NC} ⌨ SETUP BOT           ${RED}x.)${NC} ⌨ EXIT                ${BLUE}│${NC}"
echo -e " ${BLUE}└────────────────────────────────────────────────────────┘${NC}"

echo ""
read -rp "Select From Options [1-9 or x] : " OPTION

case $OPTION in
    1) echo "Menu SSH..."; sleep 1; menu ;;
    2) echo "Menu VMess..."; sleep 1; menu ;;
    3) echo "Menu VLESS..."; sleep 1; menu ;;
    4) echo "Menu Trojan..."; sleep 1; menu ;;
    5) echo "Menu Setup Bot..."; sleep 1; menu ;;
    6) echo "Menu Features..."; sleep 1; menu ;;
    7) echo "Menu Set Time..."; sleep 1; menu ;;
    8) echo "Menu Brand..."; sleep 1; menu ;;
    9) systemctl status xray nginx ;;
    x|X) exit 0 ;;
    *) echo -e "${RED}Pilihan tidak ada!${NC}"; sleep 1; menu ;;
esac
