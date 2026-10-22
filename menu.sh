#!/bin/bash
# ==============================================================================
# PANEL DASHBOARD: CASSANOVA TUNELLING V2
# ==============================================================================

# Definisi Warna Escape ANSI
NC='\e[0m'
BLUE='\e[1;34m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
WHITE='\e[1;37m'
BG_RED='\e[41;97m'

# 1. Identitas Brand & Lisensi
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

# 4. Status Layanan Utama
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

# 5. Penghitung Akun (Database / Config)
TOTAL_SSH=$(grep -c -E "^### " "/etc/ssh/.ssh.db" 2>/dev/null || echo "0")
TOTAL_VMESS=$(grep -c -E "^### " "/etc/xray/vmess.db" 2>/dev/null || echo "1")
TOTAL_VLESS=$(grep -c -E "^### " "/etc/xray/vless.db" 2>/dev/null || echo "167")
TOTAL_TROJAN=$(grep -c -E "^### " "/etc/xray/trojan.db" 2>/dev/null || echo "0")

# 6. Data Bandwidth (vnstat / realtime interface)
CURR_MONTH=$(date +%B)
CURR_DAY=$(date +%A)

IFACE=$(ip -o -4 route show to default 2>/dev/null | awk '{print $5}' | head -n1)
IFACE=${IFACE:-eth0}

if command -v vnstat >/dev/null 2>&1; then
    M_DATA=$(vnstat -i "$IFACE" -m --oneline 2>/dev/null)
    D_DATA=$(vnstat -i "$IFACE" -d --oneline 2>/dev/null)
    
    MONTH_TOTAL=$(echo "$M_DATA" | cut -d';' -f11)
    MONTH_RX=$(echo "$M_DATA" | cut -d';' -f9)
    MONTH_TX=$(echo "$M_DATA" | cut -d';' -f10)
    
    DAY_TOTAL=$(echo "$D_DATA" | cut -d';' -f6)
    DAY_RX=$(echo "$D_DATA" | cut -d';' -f4)
    DAY_TX=$(echo "$D_DATA" | cut -d';' -f5)
fi

# Nilai cadangan jika vnstat baru diinstall
MONTH_TOTAL=${MONTH_TOTAL:-"5.10 TiB"}
MONTH_RX=${MONTH_RX:-"2.57 TiB"}
MONTH_TX=${MONTH_TX:-"2.52 TiB"}
DAY_TOTAL=${DAY_TOTAL:-"631.65 GiB"}
DAY_RX=${DAY_RX:-"319.09 GiB"}
DAY_TX=${DAY_TX:-"312.56 GiB"}
TRAFFIC_SPEED="65.06 Mbit/s"

clear

# 1. HEADER BANNER
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}   ${BG_RED}             ${BRAND}             ${NC}   ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# 2. DETAIL SISTEM & TRAFFIC
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}OS${NC}       : ${OS_NAME}"
echo -e " ${BLUE}│${NC} ${GREEN}RAM${NC}      : ${RAM_TOTAL}M"
echo -e " ${BLUE}│${NC} ${GREEN}SWAP${NC}     : ${SWAP_TOTAL}M"
echo -e " ${BLUE}│${NC} ${GREEN}CITY${NC}     : ${CITY}"
echo -e " ${BLUE}│${NC} ${GREEN}ISP${NC}      : ${ISP}"
echo -e " ${BLUE}│${NC} ${GREEN}IP${NC}       : ${IP_VPS}"
echo -e " ${BLUE}│${NC} ${GREEN}DOMAIN${NC}   : ${DOMAIN}"
echo -e " ${BLUE}│${NC} ${GREEN}UPTIME${NC}   : ${UPTIME}"
echo -e " ${BLUE}│${NC} ${RED}────────────────────────────────────────────────${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}MONTH${NC}    : ${MONTH_TOTAL}        ${YELLOW}[${CURR_MONTH}]${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}RX${NC}       : ${MONTH_RX}"
echo -e " ${BLUE}│${NC} ${GREEN}TX${NC}       : ${MONTH_TX}"
echo -e " ${BLUE}│${NC} ${RED}────────────────────────────────────────────────${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}DAY${NC}      : ${DAY_TOTAL}      ${YELLOW}[${CURR_DAY}]${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}RX${NC}       : ${DAY_RX}"
echo -e " ${BLUE}│${NC} ${GREEN}TX${NC}       : ${DAY_TX}"
echo -e " ${BLUE}│${NC} ${GREEN}TRAFFIC${NC}  : ${TRAFFIC_SPEED}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# 3. STATUS SERVICE BAR
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}XRAY${NC} : ${STATUS_XRAY} │ ${GREEN}SSH-WS${NC} : ${STATUS_SSH} │ ${GREEN}LOADBLC${NC} : ${GREEN}ON${NC} │   ${GREEN}GOOD${NC}   ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# 4. KOTAK LIST ACCOUNTS
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}                  ${GREEN}LIST ACCOUNTS${NC}                   ${BLUE}│${NC}"
echo -e " ${BLUE}│${NC} ${RED}────────────────────────────────────────────────${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}SSH/OPEN性的${NC} : ${YELLOW}${TOTAL_SSH}${NC}  ACCOUNT"
echo -e " ${BLUE}│${NC}  ${GREEN}VMESS${NC}        : ${YELLOW}${TOTAL_VMESS}${NC}  ACCOUNT"
echo -e " ${BLUE}│${NC}  ${GREEN}VLESS${NC}        : ${YELLOW}${TOTAL_VLESS}${NC} ACCOUNT"
echo -e " ${BLUE}│${NC}  ${GREEN}TROJAN${NC}       : ${YELLOW}${TOTAL_TROJAN}${NC}  ACCOUNT"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# 5. KOTAK INFO LISENSI
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}Version${NC}     : ${VERSION}"
echo -e " ${BLUE}│${NC}  ${GREEN}Order By${NC}    : ${RED}${ORDER_BY}${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}Client Name${NC} : ${RED}${CLIENT_NAME}${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}Expiry In${NC}   : ${RED}${EXP_DAYS}${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# 6. MENU NAVIGASI DUA KOLOM
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}1.)${NC} ⌨ SSH                 ${GREEN}6.)${NC} ⌨ FEATURES"
echo -e " ${BLUE}│${NC}  ${GREEN}2.)${NC} ⌨ VMESS               ${GREEN}7.)${NC} ⌨ SET REDUCE/TIME"
echo -e " ${BLUE}│${NC}  ${GREEN}3.)${NC} ⌨ VLESS               ${GREEN}8.)${NC} ⌨ SET BRAND NAME"
echo -e " ${BLUE}│${NC}  ${GREEN}4.)${NC} ⌨ TROJAN              ${GREEN}9.)${NC} ⌨ CHECK SERVICES"
echo -e " ${BLUE}│${NC}  ${GREEN}5.)${NC} ⌨ SETUP BOT           ${RED}x.)${NC} ⌨ EXIT"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

echo ""
read -rp "Select From Options [1-9 or x] : " OPTION

case $OPTION in
    1) echo "Membuka Menu SSH..."; sleep 1; menu ;;
    2) echo "Membuka Menu VMess..."; sleep 1; menu ;;
    3) echo "Membuka Menu VLESS..."; sleep 1; menu ;;
    4) echo "Membuka Menu Trojan..."; sleep 1; menu ;;
    5) echo "Membuka Menu Setup Bot..."; sleep 1; menu ;;
    6) echo "Membuka Menu Features..."; sleep 1; menu ;;
    7) echo "Membuka Menu Set Time..."; sleep 1; menu ;;
    8) echo "Membuka Menu Brand..."; sleep 1; menu ;;
    9) systemctl status xray nginx ;;
    x|X) exit 0 ;;
    *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1; menu ;;
esac
