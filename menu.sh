#!/bin/bash
# ==============================================================================
# SCRIPT MENU CASSANOVA TUNELLING V2
# ==============================================================================

# Definisi Warna ANSI
BIWhite='\033[1;97m'
BIBlue='\033[1;94m'
BIGreen='\033[1;92m'
BIYellow='\033[1;93m'
BIRed='\033[1;91m'
NC='\033[0m'
BG_RED='\033[41;97m'

# 1. Identitas Brand & Pemilik
BRAND_NAME="CASSANOVA TUNELLING V2"
ORDER_BY="Amiruddin"
CLIENT_NAME="Cassanova-User"
EXP_DAYS="30 Days"

# 2. Mengambil Informasi Sistem
OS_NAME=$(grep -w PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
RAM_TOTAL=$(free -m | awk 'NR==2{print $2}')
SWAP_TOTAL=$(free -m | awk 'NR==3{print $2}')
UPTIME=$(uptime -p | sed 's/up //')

# 3. Mengambil Informasi Jaringan & ISP
IP_VPS=$(curl -sS --max-time 3 https://ipv4.icanhazip.com || echo "0.0.0.0")
GEO_DATA=$(curl -sS --max-time 3 "http://ip-api.com/json/${IP_VPS}" 2>/dev/null)
CITY=$(echo "$GEO_DATA" | jq -r '.city // "Unknown"' 2>/dev/null || echo "Singapore")
ISP=$(echo "$GEO_DATA" | jq -r '.isp // "Unknown"' 2>/dev/null || echo "DigitalOcean, LLC")
DOMAIN=$(cat /etc/xray/domain.txt 2>/dev/null || echo "sgdo5.cassanova.xyz")

# 4. Status Service Realtime
if systemctl is-active --quiet xray; then
    STATUS_XRAY="${BIGreen}ON${NC}"
else
    STATUS_XRAY="${BIRed}OFF${NC}"
fi

if systemctl is-active --quiet nginx; then
    STATUS_SSH="${BIGreen}ON${NC}"
else
    STATUS_SSH="${BIRed}OFF${NC}"
fi

clear
# ---------------- HEADER BOX ----------------
echo -e "${BIBlue}┌────────────────────────────────────────────────────────┐${NC}"
echo -e "${BIBlue}│${NC}${BG_RED}              ${BRAND_NAME}${NC}   ${BIBlue}│${NC}"
echo -e "${BIBlue}└────────────────────────────────────────────────────────┘${NC}"

# ---------------- INFO SISTEM ----------------
echo -e "${BIBlue}┌────────────────────────────────────────────────────────┐${NC}"
printf "${BIBlue}│${NC}${BIGreen}%-10s${NC} : \%-38s${BIBlue}│${NC}\n" "OS" "${OS_NAME}"
printf "${BIBlue}│${NC}${BIGreen}%-10s${NC} : \%-38s${BIBlue}│${NC}\n" "RAM" "${RAM_TOTAL}M"
printf "${BIBlue}│${NC}${BIGreen}%-10s${NC} : \%-38s${BIBlue}│${NC}\n" "SWAP" "${SWAP_TOTAL}M"
printf "${BIBlue}│${NC}${BIGreen}%-10s${NC} : \%-38s${BIBlue}│${NC}\n" "CITY" "${CITY}"
printf "${BIBlue}│${NC}${BIGreen}%-10s${NC} : \%-38s${BIBlue}│${NC}\n" "ISP" "${ISP}"
printf "${BIBlue}│${NC}${BIGreen}%-10s${NC} : \%-38s${BIBlue}│${NC}\n" "IP" "${IP_VPS}"
printf "${BIBlue}│${NC}${BIGreen}%-10s${NC} : \%-38s${BIBlue}│${NC}\n" "DOMAIN" "${DOMAIN}"
printf "${BIBlue}│${NC}${BIGreen}%-10s${NC} : \%-38s${BIBlue}│${NC}\n" "UPTIME" "${UPTIME}"
echo -e "${BIBlue}│${NC}  ${BIRed}────────────────────────────────────────────────────${NC}  ${BIBlue}│${NC}"
printf "${BIBlue}│${NC}  ${BIGreen}\%-10s${NC} : %-15s ${BIYellow}[\%-10s]${NC}        ${BIBlue}│${NC}\n" "MONTH" "5.10 TiB" "October"
printf "${BIBlue}│${NC}  ${BIGreen}\%-10s${NC} : %-38s ${BIBlue}│${NC}\n" "RX" "2.57 TiB"
printf "${BIBlue}│${NC}  ${BIGreen}\%-10s${NC} : %-38s ${BIBlue}│${NC}\n" "TX" "2.52 TiB"
echo -e "${BIBlue}│${NC}  ${BIRed}────────────────────────────────────────────────────${NC}  ${BIBlue}│${NC}"
printf "${BIBlue}│${NC}  ${BIGreen}\%-10s${NC} : %-15s ${BIYellow}[\%-10s]${NC}        ${BIBlue}│${NC}\n" "DAY" "631.65 GiB" "Thursday"
printf "${BIBlue}│${NC}  ${BIGreen}\%-10s${NC} : %-38s ${BIBlue}│${NC}\n" "RX" "319.09 GiB"
printf "${BIBlue}│${NC}  ${BIGreen}\%-10s${NC} : %-38s ${BIBlue}│${NC}\n" "TX" "312.56 GiB"
printf "${BIBlue}│${NC}  ${BIGreen}\%-10s${NC} : %-38s ${BIBlue}│${NC}\n" "TRAFFIC" "65.06 Mbit/s"
echo -e "${BIBlue}└────────────────────────────────────────────────────────┘${NC}"

# ---------------- STATUS SERVICE ----------------
echo -e "${BIBlue}┌────────────────────────────────────────────────────────┐${NC}"
printf "${BIBlue}│${NC} ${BIGreen}XRAY${NC} : ${STATUS_XRAY} │${BIGreen}SSH-WS${NC} : ${STATUS_SSH} │ ${BIGreen}LOADBLC${NC} : ${BIGreen}ON${NC} │   ${BIGreen}GOOD${NC}   ${BIBlue}│${NC}\n"
echo -e "${BIBlue}└────────────────────────────────────────────────────────┘${NC}"

# ---------------- INFO LISENSI ----------------
echo -e "${BIBlue}┌────────────────────────────────────────────────────────┐${NC}"
printf "${BIBlue}│${NC}  ${BIGreen}\%-12s${NC} : %-36s ${BIBlue}│${NC}\n" "Version" "V2.0.0"
printf "${BIBlue}│${NC}  ${BIGreen}\%-12s${NC} : ${BIRed}\%-36s${NC} ${BIBlue}│${NC}\n" "Order By" "${ORDER_BY}"
printf "${BIBlue}│${NC}  ${BIGreen}\%-12s${NC} : ${BIRed}\%-36s${NC} ${BIBlue}│${NC}\n" "Client Name" "${CLIENT_NAME}"
printf "${BIBlue}│${NC}  ${BIGreen}\%-12s${NC} : ${BIRed}\%-36s${NC} ${BIBlue}│${NC}\n" "Expiry In" "${EXP_DAYS}"
echo -e "${BIBlue}└────────────────────────────────────────────────────────┘${NC}"

# ---------------- MENU NAVIGASI ----------------
echo -e "${BIBlue}┌────────────────────────────────────────────────────────┐${NC}"
printf "${BIBlue}│${NC}  ${BIGreen}1.)${NC} ⌨ %-17s   ${BIGreen}6.)${NC} ⌨ %-18s ${BIBlue}│${NC}\n" "SSH" "FEATURES"
printf "${BIBlue}│${NC}  ${BIGreen}2.)${NC} ⌨ %-17s   ${BIGreen}7.)${NC} ⌨ %-18s ${BIBlue}│${NC}\n" "VMESS" "SET REDUCE/TIME"
printf "${BIBlue}│${NC}  ${BIGreen}3.)${NC} ⌨ %-17s   ${BIGreen}8.)${NC} ⌨ %-18s ${BIBlue}│${NC}\n" "VLESS" "SET BRAND NAME"
printf "${BIBlue}│${NC}  ${BIGreen}4.)${NC} ⌨ %-17s   ${BIGreen}9.)${NC} ⌨ %-18s ${BIBlue}│${NC}\n" "TROJAN" "CHECK SERVICES"
printf "${BIBlue}│${NC}  ${BIGreen}5.)${NC} ⌨ %-17s   ${BIRed}x.)${NC} ⌨ %-18s ${BIBlue}│${NC}\n" "SETUP BOT" "EXIT"
echo -e "${BIBlue}└────────────────────────────────────────────────────────┘${NC}"

echo ""
read -rp "Select From Options [1-9 or x] : " OPT
