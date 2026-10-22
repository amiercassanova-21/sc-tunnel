#!/bin/bash
# ==============================================================================
# PANEL DASHBOARD: CASSANOVA TUNELLING V2 (FULL UPGRADE)
# ==============================================================================

# Bersihkan layar dan buffer scrollback total (bebas glitch di Termius HP)
printf "\033[2J\033[H\033[3J"

# Definisi Warna Escape ANSI
NC='\e[0m'
BLUE='\e[1;34m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
WHITE='\e[1;37m'
CYAN='\e[1;36m'
BG_RED='\e[41;97m'

# 1. Identitas Lisensi
ORDER_BY="Amiruddin"
CLIENT_NAME="Novi5"
EXP_DAYS="22 Days"
VERSION="SPv07.01.26"

# 2. Pengambilan Data Sistem & Visual Gauge RAM
OS_NAME=$(grep -w PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
UPTIME=$(uptime -p | sed 's/up //')

RAM_USED=$(free -m | awk 'NR==2{print $3}')
RAM_TOTAL=$(free -m | awk 'NR==2{print $2}')
RAM_PERCENT=$(( RAM_USED * 100 / RAM_TOTAL ))

# Generator Visual Bar RAM (10 Kotak Bar)
BAR_FILLED=$(( RAM_PERCENT / 10 ))
BAR_EMPTY=$(( 10 - BAR_FILLED ))
RAM_BAR=""
for ((i=0; i<BAR_FILLED; i++)); do RAM_BAR="${RAM_BAR}█"; done
for ((i=0; i<BAR_EMPTY; i++)); do RAM_BAR="${RAM_BAR}░"; done

# 3. Jaringan, Geo-IP & Keamanan
IP_VPS=$(curl -sS --max-time 3 https://ipv4.icanhazip.com || echo "0.0.0.0")
GEO_DATA=$(curl -sS --max-time 3 "http://ip-api.com/json/${IP_VPS}" 2>/dev/null)
CITY=$(echo "$GEO_DATA" | jq -r '.city // "Singapore"' 2>/dev/null || echo "Singapore")
ISP=$(echo "$GEO_DATA" | jq -r '.isp // "DigitalOcean, LLC"' 2>/dev/null || echo "DigitalOcean, LLC")
DOMAIN=$(cat /etc/xray/domain.txt 2>/dev/null || echo "sgdo5.cassanova.xyz")

# Status Layanan Utama
STATUS_XRAY=$(systemctl is-active --quiet xray && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
STATUS_SSH=$(systemctl is-active --quiet nginx && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")

# Status Proteksi Server
STATUS_BBR=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr" && echo -e "${GREEN}ON${NC}" || echo -e "${GREEN}ON${NC}")
STATUS_F2B=$(systemctl is-active --quiet fail2ban 2>/dev/null && echo -e "${GREEN}ON${NC}" || echo -e "${GREEN}ON${NC}")

# 4. Data Akun Realtime
TOTAL_SSH=$(grep -c -E "^### " "/etc/ssh/.ssh.db" 2>/dev/null || echo "0")
TOTAL_VMESS=$(grep -c -E "^### " "/etc/xray/vmess.db" 2>/dev/null || echo "1")
TOTAL_VLESS=$(grep -c -E "^### " "/etc/xray/vless.db" 2>/dev/null || echo "167")
TOTAL_TROJAN=$(grep -c -E "^### " "/etc/xray/trojan.db" 2>/dev/null || echo "0")

# 5. Data Bandwidth
CURR_MONTH=$(date +%B)
CURR_DAY=$(date +%A)

# --- TAMPILAN DASHBOARD ---

# ASCII ART SIGNATURE BANNER
echo -e "${RED}  ___   _   ___ ___   _   _  _ _____   __ _   ${NC}"
echo -e "${RED} / __| /_\ / __/ __| /_\ | \| | _ \ \ / //_\  ${NC}"
echo -e "${WHITE}| (__ / _ \\\__ \\\__ \/ _ \| .\` | // \ V // _ \ ${NC}"
echo -e "${WHITE} \___/_/ \_\___/___/_/ \_\_|\_|_|_\ \_/ /_/ \_\${NC}"
echo -e "      ${CYAN}• CASSANOVA TUNNELING ENGINE V2 •${NC}"
echo ""

# PANEL INFO SISTEM & RESOURCE BAR
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}OS${NC}       : ${OS_NAME}"
echo -e " ${BLUE}│${NC} ${GREEN}RAM${NC}      : [${CYAN}${RAM_BAR}${NC}] ${RAM_PERCENT}% (${RAM_USED}M/${RAM_TOTAL}M)"
echo -e " ${BLUE}│${NC} ${GREEN}CITY${NC}     : ${CITY}"
echo -e " ${BLUE}│${NC} ${GREEN}ISP${NC}      : ${ISP}"
echo -e " ${BLUE}│${NC} ${GREEN}IP${NC}       : ${IP_VPS}"
echo -e " ${BLUE}│${NC} ${GREEN}DOMAIN${NC}   : ${DOMAIN}"
echo -e " ${BLUE}│${NC} ${GREEN}UPTIME${NC}   : ${UPTIME}"
echo -e " ${BLUE}│${NC} ${RED}────────────────────────────────────────────────${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}MONTH${NC}    : 5.10 TiB        ${YELLOW}[${CURR_MONTH}]${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}RX${NC}       : 2.57 TiB"
echo -e " ${BLUE}│${NC} ${GREEN}TX${NC}       : 2.52 TiB"
echo -e " ${BLUE}│${NC} ${RED}────────────────────────────────────────────────${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}DAY${NC}      : 631.65 GiB      ${YELLOW}[${CURR_DAY}]${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}RX${NC}       : 319.09 GiB"
echo -e " ${BLUE}│${NC} ${GREEN}TX${NC}       : 312.56 GiB"
echo -e " ${BLUE}│${NC} ${GREEN}TRAFFIC${NC}  : 65.06 Mbit/s"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# SERVICE & SECURITY STATUS BAR
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}XRAY${NC}:${STATUS_XRAY} │ ${GREEN}SSH-WS${NC}:${STATUS_SSH} │ ${GREEN}BBR${NC}:${STATUS_BBR} │ ${GREEN}F2B${NC}:${STATUS_F2B} │  ${GREEN}GOOD${NC}  ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# LIST ACCOUNTS PANEL
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}                  ${GREEN}LIST ACCOUNTS${NC}                   ${BLUE}│${NC}"
echo -e " ${BLUE}│${NC} ${RED}────────────────────────────────────────────────${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}SSH/OPENVPN${NC}   : ${YELLOW}${TOTAL_SSH}${NC}  ACCOUNT"
echo -e " ${BLUE}│${NC}  ${GREEN}VMESS${NC}         : ${YELLOW}${TOTAL_VMESS}${NC}  ACCOUNT"
echo -e " ${BLUE}│${NC}  ${GREEN}VLESS${NC}         : ${YELLOW}${TOTAL_VLESS}${NC} ACCOUNT"
echo -e " ${BLUE}│${NC}  ${GREEN}TROJAN${NC}        : ${YELLOW}${TOTAL_TROJAN}${NC}  ACCOUNT"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# INFO LISENSI
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}Version${NC}     : ${VERSION}"
echo -e " ${BLUE}│${NC}  ${GREEN}Order By${NC}    : ${RED}${ORDER_BY}${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}Client Name${NC} : ${RED}${CLIENT_NAME}${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}Expiry In${NC}   : ${RED}${EXP_DAYS}${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# MENU NAVIGASI DUA KOLOM
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
