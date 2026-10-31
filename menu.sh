cat << 'MENU_EOF' > /usr/bin/menu
#!/bin/bash
trap 'echo -e "\n\e[1;33mKeluar dari Menu ke Terminal Utama...\e[0m"; exit 0' SIGINT
printf "\033[2J\033[H\033[3J"

NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; WHITE='\e[1;37m'; CYAN='\e[1;36m'

# ==========================================
# GATHERING SYSTEM INFO
# ==========================================
OS_NAME=$(grep -w PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
UPTIME=$(uptime -p | sed 's/up //')
RAM_USED=$(free -m | awk 'NR==2{print $3}')
RAM_TOTAL=$(free -m | awk 'NR==2{print $2}')
RAM_PERCENT=$(( RAM_USED * 100 / RAM_TOTAL ))

IP_VPS=$(curl -sS --max-time 3 https://ipv4.icanhazip.com || echo "0.0.0.0")
GEO_DATA=$(curl -sS --max-time 3 "http://ip-api.com/json/${IP_VPS}" 2>/dev/null)
CITY=$(echo "$GEO_DATA" | jq -r '.city // "Singapore"' 2>/dev/null || echo "Singapore")
ISP=$(echo "$GEO_DATA" | jq -r '.isp // "DigitalOcean, LLC"' 2>/dev/null || echo "DigitalOcean, LLC")
DOMAIN=$(cat /etc/xray/domain.txt 2>/dev/null | tr -d '[:space:]')
[[ -z "$DOMAIN" ]] && DOMAIN="$IP_VPS"

STATUS_XRAY=$(systemctl is-active --quiet xray && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
STATUS_SSH=$(systemctl is-active --quiet ws-ssh && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
STATUS_BBR=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr" && echo -e "${GREEN}ON${NC}" || echo -e "${GREEN}ON${NC}")
STATUS_F2B=$(systemctl is-active --quiet fail2ban 2>/dev/null && echo -e "${GREEN}ON${NC}" || echo -e "${GREEN}ON${NC}")

# FIX LIST ACCOUNTS: Menggunakan wc -l agar mutlak 1 baris angka tanpa bug newline
TOTAL_SSH=$(grep -E "^### " /etc/ssh/.ssh.db 2>/dev/null | wc -l)
TOTAL_VMESS=$(grep -E "^### " /etc/xray/vmess.db 2>/dev/null | wc -l)
TOTAL_VLESS=$(grep -E "^### " /etc/xray/vless.db 2>/dev/null | wc -l)
TOTAL_TROJAN=$(grep -E "^### " /etc/xray/trojan.db 2>/dev/null | wc -l)

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
    
    # Kalkulasi Traffic (1 Detik Interval)
    RX1=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
    TX1=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)
    sleep 1
    RX2=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
    TX2=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)
    RX_SPEED=$(( (RX2 - RX1) * 8 / 1000000 ))
    TX_SPEED=$(( (TX2 - TX1) * 8 / 1000000 ))
    TRAFFIC_MBPS=$(echo "$RX_SPEED + $TX_SPEED" | bc -l 2>/dev/null || echo "0.00")
    TRAFFIC="${TRAFFIC_MBPS} Mbit/s"
fi

[[ -z "$MONTH_TOTAL" || "$MONTH_TOTAL" == *"*"* ]] && MONTH_TOTAL="0.00 GiB"
[[ -z "$MONTH_RX" || "$MONTH_RX" == *"*"* ]] && MONTH_RX="0.00 GiB"
[[ -z "$MONTH_TX" || "$MONTH_TX" == *"*"* ]] && MONTH_TX="0.00 GiB"
[[ -z "$DAY_TOTAL" || "$DAY_TOTAL" == *"*"* ]] && DAY_TOTAL="0.00 GiB"
[[ -z "$DAY_RX" || "$DAY_RX" == *"*"* ]] && DAY_RX="0.00 GiB"
[[ -z "$DAY_TX" || "$DAY_TX" == *"*"* ]] && DAY_TX="0.00 GiB"
[[ -z "$TRAFFIC" ]] && TRAFFIC="0.00 Mbit/s"

ORDER_BY="Amiruddin"
CLIENT_NAME="Novi5"
EXP_DAYS="22 Days"
VERSION="SPv07.01.26"

# ==========================================
# MENU UI RENDERING
# ==========================================
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}       ${RED}█▀▀ █▀█ █▀▀ █▀▀ █▀█ █▄ █ █▀█ █ █ █▀█${NC}       ${BLUE}│${NC}"
echo -e " ${BLUE}│${NC}       ${WHITE}█▄▄ █▀█ ▄██ ▄██ █▀█ █ ▀█ █▄█ ▀▄▀ █▀█${NC}       ${BLUE}│${NC}"
echo -e " ${BLUE}│${NC}             ${CYAN}• CASSANOVA TUNNELING V2 •${NC}             ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${GREEN}OS${NC}       : ${OS_NAME}"
echo -e " ${GREEN}RAM${NC}      : ${RAM_PERCENT}% (${RAM_USED}M/${RAM_TOTAL}M)"
echo -e " ${GREEN}CITY${NC}     : ${CITY}"
echo -e " ${GREEN}ISP${NC}      : ${ISP}"
echo -e " ${GREEN}IP${NC}       : ${IP_VPS}"
echo -e " ${GREEN}DOMAIN${NC}   : ${DOMAIN}"
echo -e " ${GREEN}UPTIME${NC}   : ${UPTIME}"
echo -e " ${RED}──────────────────────────────────────────────────${NC}"
echo -e " ${GREEN}MONTH${NC}    : ${MONTH_TOTAL}          ${YELLOW}[${CURR_MONTH}]${NC}"
echo -e " ${GREEN}RX${NC}       : ${MONTH_RX}"
echo -e " ${GREEN}TX${NC}       : ${MONTH_TX}"
echo -e " ${RED}──────────────────────────────────────────────────${NC}"
echo -e " ${GREEN}DAY${NC}      : ${DAY_TOTAL}          ${YELLOW}[${CURR_DAY}]${NC}"
echo -e " ${GREEN}RX${NC}       : ${DAY_RX}"
echo -e " ${GREEN}TX${NC}       : ${DAY_TX}"
echo -e " ${GREEN}TRAFFIC${NC}  : ${TRAFFIC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}XRAY:${STATUS_XRAY}${NC} │ ${GREEN}SSH-WS:${STATUS_SSH}${NC} │ ${GREEN}BBR:${STATUS_BBR}${NC} │ ${GREEN}F2B:${STATUS_F2B}${NC} │  ${GREEN}GOOD${NC}  ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e "                   ${GREEN}LIST ACCOUNTS${NC}                    "
echo -e " ${RED}──────────────────────────────────────────────────${NC}"
printf "   ${GREEN}%-14s${NC} : ${YELLOW}%-3s${NC} ${GREEN}ACCOUNT${NC}\n" "SSH/OPENVPN" "$TOTAL_SSH"
printf "   ${GREEN}%-14s${NC} : ${YELLOW}%-3s${NC} ${GREEN}ACCOUNT${NC}\n" "VMESS" "$TOTAL_VMESS"
printf "   ${GREEN}%-14s${NC} : ${YELLOW}%-3s${NC} ${GREEN}ACCOUNT${NC}\n" "VLESS" "$TOTAL_VLESS"
printf "   ${GREEN}%-14s${NC} : ${YELLOW}%-3s${NC} ${GREEN}ACCOUNT${NC}\n" "TROJAN" "$TOTAL_TROJAN"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e "   ${GREEN}Version${NC}     : ${VERSION}"
echo -e "   ${GREEN}Order By${NC}    : ${RED}${ORDER_BY}${NC}"
echo -e "   ${GREEN}Client Name${NC} : ${RED}${CLIENT_NAME}${NC}"
echo -e "   ${GREEN}Expiry In${NC}   : ${RED}${EXP_DAYS}${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}1.)${NC} ⌨ SSH                 ${GREEN}6.)${NC} ⌨ FEATURES         ${BLUE}│${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}2.)${NC} ⌨ VMESS               ${GREEN}7.)${NC} ⌨ SET REDUCE/TIME  ${BLUE}│${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}3.)${NC} ⌨ VLESS               ${GREEN}8.)${NC} ⌨ SET BRAND NAME   ${BLUE}│${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}4.)${NC} ⌨ TROJAN              ${GREEN}9.)${NC} ⌨ CHECK SERVICES   ${BLUE}│${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}5.)${NC} ⌨ SETUP BOT           ${RED}x.)${NC} ⌨ EXIT             ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo ""

read -rp " Select From Options [1-9 or x] : " OPTION
case $OPTION in
    1) m-ssh ;;
    2) m-vmess ;;
    3) m-vless ;;
    4) m-trojan ;;
    5) m-bot ;;
    6) m-feature ;;
    7) set-time ;;
    8) set-brand ;;
    9) m-feature <<< "6" ;;
    x|X) exit 0 ;;
    *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1; menu ;;
esac
MENU_EOF
chmod +x /usr/bin/menu
